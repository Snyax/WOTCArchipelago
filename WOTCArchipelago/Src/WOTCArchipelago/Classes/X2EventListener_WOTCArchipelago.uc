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

var localized string strDLCauseGeneric;
var localized string strDLCauseBleedout;
var localized string strDLCauseBleedoutWithMedikit;
var localized string strDLCauseBleedoutAfterDeathLink;
var localized string strDLCauseFire;
var localized string strDLCauseAcid;
var localized string strDLCausePoison;
var localized string strDLCauseFall;
var localized string strDLCauseExplosion;
var localized string strDLCausePanic;
var localized string strDLCauseMindControl;
var localized string strDLCauseSuicide;
var localized string strDLCauseBetrayal;
var localized string strDLCauseLost;
var localized string strDLCauseNatOne;
var localized string strDLCauseLuckyStreak;
var localized string strDLCauseDeathExplosion;
var localized string strDLCauseCritWithCover;
var localized string strDLCauseRookie;
var localized string strDLCauseAdvent;
var localized string strDLCauseChosenAssassin;
var localized string strDLCauseChosenHunter;
var localized string strDLCauseChosenWarlock;
var localized string strDLCauseAlienName;

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
    Template.AddEvent('XComVictory', OnXComVictory);
	Template.AddEvent('AfterActionWalkUp', OnWalkUp);
	Template.AddEvent('PromotionEvent', OnPromotion);
	Template.AddEvent('PlayerTurnBegun', OnPlayerTurnBegun);
	Template.AddEvent('TacticalGameEnd', OnTacticalGameEnd);

    return Template;
}

protected static function EventListenerReturn OnUnitDied(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none) return ELR_NoInterrupt;

	SendUnitKillCheck(UnitState);

	if (UnitState.GetTeam() == eTeam_Alien || UnitState.GetTeam() == eTeam_TheLost)
	{
		OnEnemyDied(NewGameState, UnitState);
	}
	else if (UnitState.GetTeam() == eTeam_XCom)
	{
		if (UnitState.IsSoldier()) SendDeath(NewGameState, UnitState);
		if (UnitState.GetMyTemplateName() == 'SparkSoldier') RefundSparkCost(NewGameState, UnitState);
	}

	return ELR_NoInterrupt;
}

private static function OnEnemyDied(XComGameState NewGameState, XComGameState_Unit EnemyState)
{
	DistributeExtraXP(NewGameState, EnemyState);
	GiveExtraCorpses(NewGameState, EnemyState);
}

private static function SendUnitKillCheck(XComGameState_Unit UnitState)
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
			`APCLIENT.OnCheckReached(name("Kill" $ Group.GroupName));
			bCustomGroupChecked = true;
		}
	}

	if (bCustomGroupChecked) return;
	if (default.CheckKillIgnoreDefaultGroup.Find(CharacterTemplateName) != INDEX_NONE) return;

	// Check Default Character Groups
	if (default.CheckKillDefaultCharacterGroups.Find(CharacterGroupName) != INDEX_NONE)
		`APCLIENT.OnCheckReached(name("Kill" $ CharacterGroupName));
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

private static function SendDeath(XComGameState NewGameState, XComGameState_Unit Soldier)
{
	local string							Cause;
	local XComGameStateContext				Context;
	local XComGameStateContext_TickEffect	TickEffectContext;
	local XComGameState_Effect				Effect;
	local name								EffectName;
	local StateObjectReference				ItemRef;
	local XComGameState_Item				ItemState;
	local bool								bCarryingMedikit;
	local DamageResult						LastDamage;
	local XComGameStateContext_Ability		AbilityContext;
	local XComGameStateContext_Ability		PrevAbilityContext;
	local XComGameState_Unit				Killer;
	local int								HitChance;
	local int								LuckyStreak;
	local int								Idx;
	local array<StateObjectReference>		FlankingEnemies;
	local bool								bFlanked;

	Context = NewGameState.GetContext();
	TickEffectContext = XComGameStateContext_TickEffect(Context);
	AbilityContext = XComGameStateContext_Ability(Context);

	// TickEffect
	if (TickEffectContext != none)
	{
		Effect = XComGameState_Effect(`XCOMHISTORY.GetGameStateForObjectID(TickEffectContext.TickedEffect.ObjectID));
		if (Effect != none)
		{
			EffectName = Effect.GetX2Effect().EffectName;

			// Bleedout
			if (EffectName == class'X2StatusEffects'.default.BleedingOutName)
			{
				Cause = default.strDLCauseBleedout;

				bCarryingMedikit = false;
				foreach Soldier.InventoryItems(ItemRef)
				{
					ItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemRef.ObjectID));
					if (ItemState != none) continue;
					if (ItemState.GetMyTemplateName() == 'Medikit' || ItemState.GetMyTemplateName() == 'NanoMedikit')
						bCarryingMedikit = true;
				}

				// ...while carrying a medikit
				if (bCarryingMedikit)
					Cause = default.strDLCauseBleedoutWithMedikit;
				// ...after surviving DeathLink
				else if (Soldier.DamageResults.Length != 0)
				{
					LastDamage = Soldier.DamageResults[Soldier.DamageResults.Length - 1];
					if (XComGameStateContext_DeathLink(LastDamage.Context) != none)
						Cause = default.strDLCauseBleedoutAfterDeathLink;
				}
			}
			// Fire
			else if (EffectName == class'X2StatusEffects'.default.BurningName)
				Cause = default.strDLCauseFire;
			// Acid
			else if (EffectName == class'X2StatusEffects'.default.AcidBurningName)
				Cause = default.strDLCauseAcid;
			// Poison
			else if (EffectName == class'X2StatusEffects'.default.PoisonedName)
				Cause = default.strDLCausePoison;
		}
	}
	// Ability
	else if (AbilityContext != none)
	{
		Killer = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
		if (Killer != none)
		{
			// XCOM
			if (Killer.GetTeam() == eTeam_XCom)
			{
				// Panic
				if (Killer.IsPanicked())
					Cause = default.strDLCausePanic;
				// Mind Control
				else if (Killer.IsMindControlled())
					Cause = default.strDLCauseMindControl;
				// Self
				else if (Killer.ObjectID == Soldier.ObjectID)
					Cause = default.strDLCauseSuicide;
				// Ally
				else Cause = default.strDLCauseBetrayal;
			}
			// Lost
			else if (Killer.GetTeam() == eTeam_TheLost)
				Cause = default.strDLCauseLost;
			// ADVENT / Chosen / Alien
			else
			{
				HitChance = AbilityContext.ResultContext.CalculatedHitChance;

				LuckyStreak = 0;
				for (Idx = Soldier.DamageResults.Length - 1; Idx >= 0; Idx--)
				{
					PrevAbilityContext = XComGameStateContext_Ability(Soldier.DamageResults[Idx].Context);
					if (PrevAbilityContext == none) continue;
					if (PrevAbilityContext.ResultContext.HitResult == eHit_Success) break;
					if (PrevAbilityContext.ResultContext.HitResult == eHit_Crit) break;
					LuckyStreak++;
				}

				class'X2TacticalVisibilityHelpers'.static.GetFlankingEnemiesOfTarget(Soldier.ObjectID, FlankingEnemies);
				bFlanked = FlankingEnemies.Find('ObjectID', Soldier.ObjectID) != INDEX_NONE;

				// Nat 1
				if (HitChance > 0 && HitChance <= 5)
					Cause = default.strDLCauseNatOne;
				// Lucky Streak
				else if (LuckyStreak >= 5)
					Cause = default.strDLCauseLuckyStreak;
				// Death Explosion
				else if (AbilityContext.InputContext.AbilityTemplateName == 'DeathExplosion')
					Cause = default.strDLCauseDeathExplosion;
				// Crit + Cover
				else if (AbilityContext.ResultContext.HitResult == eHit_Crit && !bFlanked)
					Cause = default.strDLCauseCritWithCover;
				// Rookie
				else if (Soldier.GetRank() == 0)
					Cause = default.strDLCauseRookie;
				// ADVENT
				else if (Killer.IsAdvent())
					Cause = default.strDLCauseAdvent;
				// Chosen Assassin
				else if (Killer.GetMyTemplateGroupName() == 'ChosenAssassin')
					Cause = default.strDLCauseChosenAssassin;
				// Chosen Hunter
				else if (Killer.GetMyTemplateGroupName() == 'ChosenSniper')
					Cause = default.strDLCauseChosenHunter;
				// Chosen Warlock
				else if (Killer.GetMyTemplateGroupName() == 'ChosenWarlock')
					Cause = default.strDLCauseChosenWarlock;
				// Alien
				else Cause = default.strDLCauseAlienName $ Killer.GetMyTemplateGroupName();
			}
		}
	}
	// Fall
	else if (XComGameStateContext_Falling(Context) != none)
		Cause = default.strDLCauseFall;
	// Explosion
	else if (Soldier.bKilledByExplosion)
		Cause = default.strDLCauseExplosion;

	if (Cause == "") Cause = default.strDLCauseGeneric;
	`APCLIENT.SendDeath(`APUNITINFO(Cause, Soldier));
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
	SeqActShowDramaticMessage.Title = class'WOTCArchipelago_APClient'.default.strTacticalMessageTitle;
	SeqActShowDramaticMessage.Message1 = default.strSparkCostRefunded;
	SeqActShowDramaticMessage.Message2 = `APUNITINFO(default.strSparkCostRefundedDetails, UnitState);
	SeqActShowDramaticMessage.MessageColor = eUIState_Normal;
	SeqActShowDramaticMessage.BuildVisualization(NewGameState);
}

protected static function EventListenerReturn OnXComVictory(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	`APCLIENT.OnCheckReached('Victory');
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
		`APCLIENT.OnCheckReached('Broadcast');

	// Check for stronghold goal
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData.bChosenDefeated)
	{
		NumChosenDefeated = `APCTRINC('ChosenDefeated', NewGameState);
		`APCLIENT.OnCheckReached(name("Stronghold" $ NumChosenDefeated));
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

protected static function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	if (XComGameState_Player(EventSource).TeamFlag == eTeam_XCom)
	{
		`APCLIENT.StartDeathTickLoop();
		`APCLIENT.SendTick();
	}

	return ELR_NoInterrupt;
}

protected static function EventListenerReturn OnTacticalGameEnd(Object EventData, Object EventSource, XComGameState NewGameState, name EventName, Object CallbackData)
{
	`APCLIENT.CancelDeathTickLoop();
	return ELR_NoInterrupt;
}
