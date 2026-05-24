// Helper class for overriding reward functionality (NOT an MCO)
class X2StrategyElement_OverrideRewards extends X2StrategyElement_XpackRewards;

// This function is not copied from vanilla code (though most in "Override" helper classes are)
static function GiveRankUpReward_Override(XComGameState NewGameState, XComGameState_Reward RewardState, optional StateObjectReference AuxRef, optional bool bOrder = false, optional int OrderHours = -1)
{
	local XComGameState_Unit		UnitState;
	local X2SoldierClassTemplate	SoldierClassTemplate;
	local int						DeservedSoldierRank;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(AuxRef.ObjectID));
	if (UnitState == none) UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AuxRef.ObjectID));

	if (UnitState.IsSoldier() && class'WOTCArchipelago_Ranksanity'.static.IsEnabled(UnitState.GetSoldierClassTemplateName()))
	{
		SoldierClassTemplate = UnitState.GetSoldierClassTemplate();
		DeservedSoldierRank = class'WOTCArchipelago_Ranksanity'.static.GetSoldierRankByKills(UnitState);
		UnitState.SetKillsForRank(Min(DeservedSoldierRank + 1, SoldierClassTemplate.GetMaxConfiguredRank()));
	}
	else
	{
		// Call the original function here
		GiveRankUpReward(NewGameState, RewardState, AuxRef, bOrder, OrderHours);
	}
}

static function GeneratePersonnelReward_Override(XComGameState_Reward RewardState, XComGameState NewGameState, optional float RewardScalar = 1.0, optional StateObjectReference RegionRef)
{
	local XComGameState_Unit NewUnitState;
	local XComGameState_WorldRegion RegionState;
	local name nmCountry;
	
	// Grab the region and pick a random country
	nmCountry = '';
	RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(RegionRef.ObjectID));

	if(RegionState != none)
	{
		nmCountry = RegionState.GetMyTemplate().GetRandomCountryInRegion();
	}

	NewUnitState = CreatePersonnelUnit_Override(NewGameState, RewardState.GetMyTemplate().rewardObjectTemplateName, nmCountry, (RewardState.GetMyTemplateName() == 'Reward_Rookie'));
	RewardState.RewardObjectReference = NewUnitState.GetReference();
}

static function XComGameState_Unit CreatePersonnelUnit_Override(XComGameState NewGameState, name nmCharacter, name nmCountry, optional bool bIsRookie)
{
	local XComGameStateHistory History;
	local XComGameState_Unit NewUnitState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local int idx, NewRank, StartingIdx;
	local name SoldierClass;

	History = `XCOMHISTORY;

	//Use the character pool's creation method to retrieve a unit
	NewUnitState = `CHARACTERPOOLMGR.CreateCharacter(NewGameState, `XPROFILESETTINGS.Data.m_eCharPoolUsage, nmCharacter, nmCountry);
	NewUnitState.RandomizeStats();

	if (NewUnitState.IsSoldier())
	{
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		ResistanceHQ = XComGameState_HeadquartersResistance(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));

		if (!NewGameState.GetContext().IsStartState())
		{
			ResistanceHQ = XComGameState_HeadquartersResistance(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersResistance', ResistanceHQ.ObjectID));
		}

		NewUnitState.ApplyInventoryLoadout(NewGameState);

		StartingIdx = 0;
		if(NewUnitState.GetMyTemplate().DefaultSoldierClass != '' && NewUnitState.GetMyTemplate().DefaultSoldierClass != class'X2SoldierClassTemplateManager'.default.DefaultSoldierClass)
		{
			// Some character classes start at squaddie on creation
			StartingIdx = 1;
		}

		// Promote to squaddie first for soldier class selection...
		if (StartingIdx == 0 && !bIsRookie)
		{
			NewUnitState.RankUpSoldier(NewGameState, ResistanceHQ.SelectNextSoldierClass());
			NewUnitState.ApplySquaddieLoadout(NewGameState);
			NewUnitState.bNeedsNewClassPopup = false;

			StartingIdx = 1;
		}

		NewRank = GetPersonnelRewardRank(true, bIsRookie);

		// ...then determine received rank (if ranksanity is enabled for the soldier class)
		SoldierClass = NewUnitState.GetSoldierClassTemplateName();
		if (!bIsRookie && class'WOTCArchipelago_Ranksanity'.static.IsEnabled(SoldierClass))
		{
			NewRank = class'WOTCArchipelago_Ranksanity'.static.GetReceivedRank(SoldierClass, NewGameState);
		}

		NewUnitState.StartingRank = NewRank;

		for (idx = StartingIdx; idx < NewRank; idx++)
		{
			NewUnitState.RankUpSoldier(NewGameState, NewUnitState.GetSoldierClassTemplate().DataName);
		}

		// Set an appropriate fame score for the unit
		NewUnitState.StartingFame = XComHQ.AverageSoldierFame;
		NewUnitState.bIsFamous = true;
	}
	else
	{
		NewUnitState.SetSkillLevel(GetPersonnelRewardRank(false));
	}

	return NewUnitState;
}
