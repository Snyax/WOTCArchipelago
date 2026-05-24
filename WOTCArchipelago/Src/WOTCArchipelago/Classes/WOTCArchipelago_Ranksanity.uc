class WOTCArchipelago_Ranksanity extends Object config(WOTCArchipelago);

struct native RanksanityDataEntry
{
	var name		ID;
	var name		SoldierClass;
	var array<int>	Ranks;
};

var config array<RanksanityDataEntry> RanksanityData;

var config array<name> DisabledDataEntries;
var config array<name> FactionSoldierClasses;
var config array<name> SLGSoldierClasses;

var config bool bEnableRanksanity;
var config bool bDisableFactionSoldierClasses;
var config bool bDisableSLGSoldierClasses;

static function bool IsEnabled(name SoldierClass, optional out array<int> Ranks)
{
	local RanksanityDataEntry Entry;

	if (!default.bEnableRanksanity) return false;
	
	if (default.FactionSoldierClasses.Find(SoldierClass) != INDEX_NONE)
		if (default.bDisableFactionSoldierClasses) return false;

	if (default.SLGSoldierClasses.Find(SoldierClass) != INDEX_NONE)
		if (default.bDisableSLGSoldierClasses) return false;

	foreach default.RanksanityData(Entry)
	{
		if (SoldierClass != Entry.SoldierClass) continue;
		if (default.DisabledDataEntries.Find(Entry.ID) != INDEX_NONE) continue;

		Ranks = Entry.Ranks;
		return true;
	}

	return false;
}

static function array<name> GetEnabledSoldierClasses()
{
	local RanksanityDataEntry	Entry;
	local array<name>			EnabledSoldierClasses;

	foreach default.RanksanityData(Entry)
	{
		if (EnabledSoldierClasses.Find(Entry.SoldierClass) != INDEX_NONE) continue;
		if (!IsEnabled(Entry.SoldierClass)) continue;

		EnabledSoldierClasses.AddItem(Entry.SoldierClass);
	}

	return EnabledSoldierClasses;
}

static function int GetSoldierRankByKills(XComGameState_Unit SoldierState)
{
	local X2SoldierClassTemplate	SoldierClassTemplate;
	local int						NumKills;
	local int						ReachedRank;

	SoldierClassTemplate = SoldierState.GetSoldierClassTemplate();
	NumKills = SoldierState.GetTotalNumKills();
	for (ReachedRank = 0; ReachedRank < SoldierClassTemplate.GetMaxConfiguredRank(); ReachedRank++)
	{
		if (NumKills < class'X2ExperienceConfig'.static.GetRequiredKills(ReachedRank + 1)) break;
	}

	return ReachedRank;
}

static function SendMissingChecksByClass(XComGameState NewGameState, name SoldierClass, int Rank)
{
	local array<int>	Ranks;
	local name			RankSentCounterName;
	local int			Idx;

	if (!IsEnabled(SoldierClass, Ranks)) return;

	RankSentCounterName = class'X2Item_APCounterResources'.static.GetRankSentCounterName(SoldierClass);
	for (Idx = `APCTRREAD(RankSentCounterName, NewGameState); Idx < Ranks.Length; Idx++)
	{
		if (Ranks[Idx] > Rank) break;
		`APCLIENT.OnCheckReached(NewGameState, name(SoldierClass $ "Rank" $ Ranks[Idx]));
		`APCTRINC(RankSentCounterName, NewGameState);
	}
}

static function SendMissingChecks(XComGameState NewGameState, StateObjectReference SoldierRef)
{
	local XComGameState_BaseObject	StateObject;
	local XComGameState_Unit		SoldierState;

	if (!class'WOTCArchipelago_Utilities'.static.GetNewestStateObject(SoldierRef.ObjectID, StateObject, NewGameState)) return;

	SoldierState = XComGameState_Unit(StateObject);
	SendMissingChecksByClass(NewGameState, SoldierState.GetSoldierClassTemplateName(), GetSoldierRankByKills(SoldierState));
}

static function int GetReceivedRank(name SoldierClass, optional XComGameState NewGameState)
{
	local array<int>	Ranks;
	local name			RankReceivedCounterName;
	local int			RankReceivedCounter;

	if (!IsEnabled(SoldierClass, Ranks)) return 0;

	// Determine received rank from promotion items
	RankReceivedCounterName = class'X2Item_APCounterResources'.static.GetRankReceivedCounterName(SoldierClass);
	RankReceivedCounter = `APCTRREAD(RankReceivedCounterName, NewGameState);
	if (RankReceivedCounter == 0) return 0;

	return Ranks[Min(RankReceivedCounter, Ranks.Length) - 1];
}

static function GrantMissingPromotions(XComGameState NewGameState, StateObjectReference SoldierRef)
{
	local XComGameState_Unit	SoldierState;
	local name					SoldierClass;
	local int					ReceivedRank;

	SoldierState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(SoldierRef.ObjectID));
	if (SoldierState == none) SoldierState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', SoldierRef.ObjectID));

	// Get received rank for soldier class
	SoldierClass = SoldierState.GetSoldierClassTemplateName();
	ReceivedRank = GetReceivedRank(SoldierClass, NewGameState);

	// Promote up to received rank (if soldier rank was lower)
	while (SoldierState.GetRank() < ReceivedRank)
	{
		SoldierState.RankUpSoldier(NewGameState);
	}
	SoldierState.SetKillsForRank(ReceivedRank);
}
