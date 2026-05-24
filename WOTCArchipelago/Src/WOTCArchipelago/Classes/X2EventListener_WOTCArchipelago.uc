class X2EventListener_WOTCArchipelago extends X2EventListener config(WOTCArchipelago);

struct native CustomGroup
{
	var name			GroupName;
	var array<name>		Members;
};

var config array<name>			CheckKillDefaultCharacterGroups;
var config array<CustomGroup>	CheckKillCustomCharacterGroups;
var config array<name>			CheckKillIgnoreDefaultGroup;

var config int RefundSparkCostSupplies;
var config int RefundSparkCostAlloys;
var config int RefundSparkCostElerium;
var config int RefundSparkCostCores;

var localized string strSparkCostRefunded;
var localized string strSparkCostRefundedDetails;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateListenerTemplate());

    return Templates;
}

private static function X2EventListenerTemplate CreateListenerTemplate()
{
    local X2EventListenerTemplate Template;

    `CREATE_X2TEMPLATE(class'X2EventListenerTemplate', Template, 'APEventListenerTemplate');

    Template.RegisterInTactical = true;
    Template.RegisterInStrategy = true;

	Template.AddEvent('UnitDied', OnUnitDied);
	Template.AddEvent('CovertActionCompleted', OnCovertActionCompleted);
    Template.AddEvent('XComVictory', OnXComVictory);
	Template.AddEvent('AfterActionWalkUp', OnWalkUp);
	Template.AddEvent('PromotionEvent', OnPromotion);

    return Template;
}

protected static function EventListenerReturn OnUnitDied(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none) return ELR_NoInterrupt;

	SendUnitKillCheck(NewGameState, UnitState);

	if (UnitState.GetTeam() == eTeam_Alien || UnitState.GetTeam() == eTeam_TheLost)
		OnEnemyDied(NewGameState, UnitState);
	else if (UnitState.GetTeam() == eTeam_XCom && UnitState.GetMyTemplateName() == 'SparkSoldier')
		RefundSparkCost(NewGameState, UnitState);

	return ELR_NoInterrupt;
}

private static function OnEnemyDied(XComGameState NewGameState, XComGameState_Unit EnemyState)
{
	DistributeExtraXP(NewGameState, EnemyState);
	GiveExtraCorpses(NewGameState, EnemyState);
}

private static function SendUnitKillCheck(XComGameState NewGameState, XComGameState_Unit UnitState)
{
	local name				CharacterTemplateName;
	local name				CharacterGroupName;
	local CustomGroup		Group;
	local bool				bCustomGroupChecked;

	CharacterTemplateName = UnitState.GetMyTemplateName();
	CharacterGroupName = UnitState.GetMyTemplateGroupName();

	// Check Custom Character Groups
	foreach default.CheckKillCustomCharacterGroups(Group)
	{
		if (Group.Members.Find(CharacterTemplateName) != INDEX_NONE)
		{
			`APCLIENT.OnCheckReached(NewGameState, name("Kill" $ Group.GroupName));
			bCustomGroupChecked = true;
		}
	}

	if (bCustomGroupChecked) return;
	if (default.CheckKillIgnoreDefaultGroup.Find(CharacterTemplateName) != INDEX_NONE) return;

	// Check Default Character Groups
	if (default.CheckKillDefaultCharacterGroups.Find(CharacterGroupName) != INDEX_NONE)
		`APCLIENT.OnCheckReached(NewGameState, name("Kill" $ CharacterGroupName));
}

private static function DistributeExtraXP(XComGameState NewGameState, XComGameState_Unit EnemyState)
{
	local StateObjectReference	SoldierRef;
	local XComGameState_Unit	SoldierState;
	local float					ExtraXp;

	foreach `XCOMHQ.Squad(SoldierRef)
	{
		if (SoldierRef.ObjectID == 0) continue;

		SoldierState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierRef.ObjectID));
		
		if (SoldierState != none && SoldierState.IsSoldier() && SoldierState.CanEarnXP() && SoldierState.IsAlive())
		{
			ExtraXp = EnemyState.GetMyTemplate().KillContribution * `APCFG(EXTRA_XP_MULT);

			SoldierState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', SoldierRef.ObjectID));
			`AMLOG("Adding XP: " $ ExtraXp $ " to " $ SoldierState.GetFullName());
			SoldierState.BonusKills += ExtraXp; // Add to bonus kills (like Wet Work, Deeper Learning)
		}
	}
}

private static function GiveExtraCorpses(XComGameState NewGameState, XComGameState_Unit EnemyState)
{
	local X2LootTableManager		LootTableManager;
	local XComGameState_BattleData	BattleData;
	local array<LootReference>		LootRefs;
	local LootReference				LootRef;
	local name						LootTableName;
	local array<name>				LootTemplateNames;
	local name						LootTemplateName;
	local int						Num;

	LootTableManager = class'X2LootTableManager'.static.GetLootTableManager();
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	
	LootRefs = EnemyState.GetMyTemplate().Loot.LootReferences;

	foreach LootRefs(LootRef)
	{
		LootTableName = LootRef.LootTableName;
		LootTableManager.RollForLootTable(LootTableName, LootTemplateNames);

		foreach LootTemplateNames(LootTemplateName)
		{
			for (Num = 0; Num < `APCFG(EXTRA_CORPSES); Num++)
			{
				BattleData.AutoLootBucket.AddItem(LootTemplateName);
			}
		}
	}
}

private static function RefundSparkCost(XComGameState NewGameState, XComGameState_Unit UnitState)
{
	local SeqAct_ShowDramaticMessage SeqActShowDramaticMessage;

	if (!`APCFG(REFUND_SPARK_COST)) return;
	
	`APADDITEM(NewGameState, 'Supplies', default.RefundSparkCostSupplies);
	`APADDITEM(NewGameState, 'AlienAlloy', default.RefundSparkCostAlloys);
	`APADDITEM(NewGameState, 'EleriumDust', default.RefundSparkCostElerium);
	`APADDITEM(NewGameState, 'EleriumCore', default.RefundSparkCostCores);

	SeqActShowDramaticMessage = new class'SeqAct_ShowDramaticMessage';
	SeqActShowDramaticMessage.Title = class'WOTCArchipelago_APClient'.default.strDramaticMessageTitle;
	SeqActShowDramaticMessage.Message1 = default.strSparkCostRefunded;
	SeqActShowDramaticMessage.Message2 = `APUNITINFO(default.strSparkCostRefundedDetails, UnitState);
	SeqActShowDramaticMessage.MessageColor = eUIState_Normal;
	SeqActShowDramaticMessage.BuildVisualization(NewGameState);
}

protected static function EventListenerReturn OnCovertActionCompleted(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	local XComGameState_ResistanceFaction	FactionState;
	local name								CheckedCounterName;
	local int								ChosenHuntPart;
	local int								ChosenHuntPartCount;

	class'X2Item_APCounterResources'.static.GetRecentCompletedChosenHuntFaction(FactionState, CheckedCounterName, NewGameState);

	// No chosen hunt covert action
	if (FactionState == none) return ELR_NoInterrupt;

	ChosenHuntPart = `APCTRINC(CheckedCounterName, NewGameState);

	if (`APCTRREAD('ReaperChosenHuntChecked', NewGameState) >= ChosenHuntPart) ChosenHuntPartCount += 1;
	if (`APCTRREAD('SkirmisherChosenHuntChecked', NewGameState) >= ChosenHuntPart) ChosenHuntPartCount += 1;
	if (`APCTRREAD('TemplarChosenHuntChecked', NewGameState) >= ChosenHuntPart) ChosenHuntPartCount += 1;

	`APCLIENT.OnCheckReached(NewGameState, name("ChosenHuntPt" $ ChosenHuntPart $ ":" $ ChosenHuntPartCount));
	return ELR_NoInterrupt;
}

protected static function EventListenerReturn OnXComVictory(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	`APCLIENT.OnCheckReached(NewGameState, 'Victory');
	return ELR_NoInterrupt;
}

protected static function EventListenerReturn OnWalkUp(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	local XComGameState_MissionSite		MissionState;
	local XComGameState_BattleData		BattleData;
	local int							NumChosenDefeated;

	// Check for broadcast goal
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(`XCOMHQ.MissionRef.ObjectID));
	if (MissionState.GetMissionSource().DataName == 'MissionSource_Broadcast')
		`APCLIENT.OnCheckReached(NewGameState, 'Broadcast');

	// Check for stronghold goal
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData.bChosenDefeated)
	{
		NumChosenDefeated = `APCTRINC('ChosenDefeated', NewGameState);
		`APCLIENT.OnCheckReached(NewGameState, name("Stronghold" $ NumChosenDefeated));
	}

	// Check for promotions
	`APCLIENT.HandleRanksanityPromotions(NewGameState);

	return ELR_NoInterrupt;
}

protected static function EventListenerReturn OnPromotion(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	`APCLIENT.HandleRanksanityPromotions(NewGameState);
	return ELR_NoInterrupt;
}
