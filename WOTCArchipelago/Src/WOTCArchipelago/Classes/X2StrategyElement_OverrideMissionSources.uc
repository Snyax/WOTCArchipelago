// Helper class for overriding mission source functionality (NOT an MCO)
class X2StrategyElement_OverrideMissionSources extends X2StrategyElement_XpackMissionSources config(WOTCArchipelago);

var config int SupplyRaidSkipMaxSupplies;
var config int SupplyRaidSkipMaxAlloys;
var config int SupplyRaidSkipMaxElerium;
var config int SupplyRaidSkipMaxCores;

var localized string strSkippedSupplyRaid;
var localized string strSkippedCouncilMission;
var localized string strSkippedResistanceOp;
var localized string strSkippedRewardCollection;


// SPAWN OVERRIDE FUNCTIONS

static function SpawnSupplyRaidMission_Override(XComGameState NewGameState, int MissionMonthIndex)
{
	local XComGameState_MissionSite MissionState;
	local XComGameState_WorldRegion RegionState;
	local XComGameState_Reward RewardState;
	local array<XComGameState_WorldRegion> PossibleRegions;
	local float MissionDuration;
	local int iReward;
	local XComGameState_MissionCalendar CalendarState;
	local XComGameState_HeadquartersResistance ResHQ;
	local WOTCArchipelago_APClient APClient;

	CalendarState = GetMissionCalendar(NewGameState);

	// Calculate Mission Expiration timer (same for each op)
	MissionDuration = float((default.MissionMinDuration + `SYNC_RAND_STATIC(default.MissionMaxDuration - default.MissionMinDuration + 1)) * 3600);

	// Spawn the supply raid from the current mission event		
	MissionState = XComGameState_MissionSite(NewGameState.ModifyStateObject(class'XComGameState_MissionSite', CalendarState.CurrentMissionMonth[MissionMonthIndex].Missions[0].ObjectID));
	MissionState.TimeUntilDespawn = MissionDuration;
	MissionState.Available = true;
	MissionState.Expiring = true;
	MissionState.TimerStartDateTime = `STRATEGYRULES.GameTime;
	MissionState.SetProjectedExpirationDateTime(MissionState.TimerStartDateTime);
	PossibleRegions = MissionState.GetMissionSource().GetMissionRegionFn(NewGameState);
	RegionState = PossibleRegions[0];
	MissionState.Region = RegionState.GetReference();
	MissionState.Location = RegionState.GetRandomLocationInRegion();

	// Generate Rewards
	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	for(iReward = 0; iReward < MissionState.Rewards.Length; iReward++)
	{
		RewardState = XComGameState_Reward(NewGameState.ModifyStateObject(class'XComGameState_Reward', MissionState.Rewards[iReward].ObjectID));
		RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), MissionState.Region);
	}

	MissionState.SetMissionData(MissionState.GetRewardType(), false, 0);
	`HQPRES.StrategyMap2D.GetMapItem(MissionState, NewGameState).InitStatic3DUI(MissionState);

	MissionState.PickPOI(NewGameState);

	if (`APCFG(SKIP_SUPPLY_RAIDS))
	{
		// Skip mission
		GiveSupplyRaidSkipRewards();
		SkipMission(NewGameState, MissionState);
		`AMLOG("Skipped Supply Raid Mission");

		// Show custom skip mission popup
		APClient = `APCLIENT;
		APClient.CustomPopupTitle = default.strSkippedSupplyRaid;
		APClient.CustomPopupText = default.strSkippedRewardCollection;
		APClient.bShowCustomPopup = true;
	}
	else
	{
		// Set Popup flag
		CalendarState.MissionPopupSources.AddItem(MissionState.Source);
	}
}

static function SpawnCouncilMission_Override(XComGameState NewGameState, int MissionMonthIndex)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite MissionState;
	local XComGameState_WorldRegion RegionState;
	local XComGameState_Reward RewardState;
	local X2RewardTemplate RewardTemplate;
	local X2MissionSourceTemplate MissionSource;
	local array<XComGameState_Reward> MissionRewards;
	local array<XComGameState_WorldRegion> PossibleRegions;
	local float MissionDuration;
	local XComGameState_MissionCalendar CalendarState;
	local XComGameState_HeadquartersResistance ResHQ;
	local WOTCArchipelago_APClient APClient;

	CalendarState = GetMissionCalendar(NewGameState);

	// Calculate Mission Expiration timer
	MissionDuration = float((default.MissionMinDuration + `SYNC_RAND_STATIC(default.MissionMaxDuration - default.MissionMinDuration + 1)) * 3600);

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate('MissionSource_Council'));
	PossibleRegions = MissionSource.GetMissionRegionFn(NewGameState);
	RegionState = PossibleRegions[0];

	// Generate the mission reward
	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate(SelectCouncilMissionRewardType(CalendarState)));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	if (RewardState.GetMyTemplateName() == 'Reward_Supplies')
		RewardState.GenerateReward(NewGameState, default.CouncilMissionSupplyScalar * ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	else
		RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	MissionRewards.AddItem(RewardState);
	
	// All Council Missions also give an Intel reward
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Intel'));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	MissionRewards.AddItem(RewardState);
	
	MissionState = XComGameState_MissionSite(NewGameState.CreateNewStateObject(class'XComGameState_MissionSite'));

	MissionState.BuildMission(MissionSource, RegionState.GetRandom2DLocationInRegion(), RegionState.GetReference(), MissionRewards, true, true, , MissionDuration);

	MissionState.PickPOI(NewGameState);

	`XEVENTMGR.TriggerEvent('CouncilMissionSpawned', MissionState, MissionState, NewGameState);
	
	CalendarState.CreatedMissionSources.AddItem('MissionSource_Council');

	if (`APCFG(SKIP_COUNCIL_MISSIONS))
	{
		// Skip mission
		SkipMission(NewGameState, MissionState);
		`AMLOG("Skipped Council Mission");

		// Show custom skip mission popup
		APClient = `APCLIENT;
		APClient.CustomPopupTitle = default.strSkippedCouncilMission;
		APClient.CustomPopupText = default.strSkippedRewardCollection;
		APClient.bShowCustomPopup = true;
	}
	else
	{
		// Set Popup flag
		CalendarState.MissionPopupSources.AddItem('MissionSource_Council');
	}
}

static function SpawnResOpMission_Override(XComGameState NewGameState, int MissionMonthIndex)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite MissionState;
	local XComGameState_ResistanceFaction FactionState;
	local X2MissionSourceTemplate MissionSource;
	local XComGameState_MissionCalendar CalendarState;
	local WOTCArchipelago_APClient APClient;

	CalendarState = GetMissionCalendar(NewGameState);

	// We only want a limited amount of Res Ops per campaign
	if(CalendarState.GetNumTimesMissionSourceCreated('MissionSource_ResistanceOp') >= default.MaxResOpsPerCampaign)
	{
		SpawnCouncilMission_Override(NewGameState, MissionMonthIndex);
		return;
	}

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate('MissionSource_ResistanceOp'));
	
	MissionState = BuildResOpMission(NewGameState, MissionSource);
	FactionState = SelectRandomResistanceOpFaction();
	MissionState.ResistanceFaction = FactionState.GetReference();
	
	// Set mission source flag in the calendar - do this after creating the mission so rewards are generated properly
	CalendarState.CreatedMissionSources.AddItem('MissionSource_ResistanceOp');

	if (`APCFG(SKIP_FACTION_MISSIONS))
	{
		// Skip mission
		SkipMission(NewGameState, MissionState);
		`AMLOG("Skipped Resistance Op Mission");

		// Show custom skip mission popup
		APClient = `APCLIENT;
		APClient.CustomPopupTitle = default.strSkippedResistanceOp;
		APClient.CustomPopupText = default.strSkippedRewardCollection;
		APClient.bShowCustomPopup = true;
	}
	else
	{
		// Set Popup flag
		CalendarState.MissionPopupSources.AddItem('MissionSource_ResistanceOp');
	}
}


// SUCCESS OVERRIDE FUNCTIONS

static function CouncilOnSuccess_Override(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local array<int> ExcludeIndices;

	// Don't exclude any optional rewards
	if (!`APCFG(SKIP_COUNCIL_MISSIONS))
	{
		ExcludeIndices = GetCouncilExcludeRewards(MissionState);
	}

	MissionState.bUsePartialSuccessText = (ExcludeIndices.Length > 0);
	GiveRewards(NewGameState, MissionState, ExcludeIndices);
	SpawnPointOfInterest(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_CouncilMissionsCompleted');
}

static function ResOpOnSuccess_Override(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local array<int> ExcludeIndices;

	// Don't exclude any optional rewards
	if (!`APCFG(SKIP_FACTION_MISSIONS))
	{
		ExcludeIndices = GetResOpExcludeRewards(MissionState);
	}

	MissionState.bUsePartialSuccessText = (ExcludeIndices.Length > 0);
	GiveRewards(NewGameState, MissionState, ExcludeIndices);
	SpawnPointOfInterest(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_ResistanceOpsCompleted');
	
	`XEVENTMGR.TriggerEvent('ResistanceOpComplete', , , NewGameState);
}


// HELPER FUNCTIONS

private static function SkipMission(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_MissionSite FortressMission;
	local int idx;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	AlienHQ = XComGameState_HeadquartersAlien(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));
	FortressMission = AlienHQ.GetFortressMission();

	// Remove Mission Tags from the general tags list
	XComHQ.RemoveMissionTacticalTags(MissionState);

	// Handle tactical objective complete doom removal (should not be any other pending doom at this point)
	for(idx = 0; idx < AlienHQ.PendingDoomData.Length; idx++)
	{
		if(AlienHQ.PendingDoomData[idx].Doom > 0)
		{
			AlienHQ.PendingDoomData[idx].Doom = Clamp(AlienHQ.PendingDoomData[idx].Doom, 0, AlienHQ.GetCurrentDoom(true));
			AlienHQ.AddDoomToFortress(NewGameState, AlienHQ.PendingDoomData[idx].Doom, , false);
			AlienHQ.PendingDoomEntity = FortressMission.GetReference();

			if(AlienHQ.PendingDoomData[idx].DoomMessage != "" && FortressMission.ShouldBeVisible())
			{
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, AlienHQ.PendingDoomData[idx].DoomMessage, true);
			}
			
		}
		else if(AlienHQ.PendingDoomData[idx].Doom < 0)
		{
			AlienHQ.PendingDoomData[idx].Doom = Clamp(AlienHQ.PendingDoomData[idx].Doom, -AlienHQ.GetCurrentDoom(true), 0);
			AlienHQ.RemoveDoomFromFortress(NewGameState, -AlienHQ.PendingDoomData[idx].Doom, , false);
			AlienHQ.PendingDoomEntity = FortressMission.GetReference();

			if(AlienHQ.PendingDoomData[idx].DoomMessage != "" && FortressMission.ShouldBeVisible())
			{
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, AlienHQ.PendingDoomData[idx].DoomMessage, false);
				class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvatarProgressReduced', -AlienHQ.PendingDoomData[idx].Doom);
			}
		}
		else
		{
			AlienHQ.PendingDoomData.Remove(idx, 1);
			AlienHQ.PendingDoomEvent = '';
			idx--;
		}
	}

	// If accelerating doom, stop
	if(AlienHQ.bAcceleratingDoom)
	{
		AlienHQ.StopAcceleratingDoom();
	}

	// Process mission success
	MissionState.GetMissionSource().OnSuccessFn(NewGameState, MissionState);
}

private static function XComGameState_MissionSite BuildResOpMission(XComGameState NewGameState, X2MissionSourceTemplate MissionSource, optional bool bNoPOI)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite MissionState;
	local XComGameState_WorldRegion RegionState;
	local XComGameState_MissionCalendar CalendarState;
	local XComGameState_Reward RewardState;
	local X2RewardTemplate RewardTemplate;
	local array<XComGameState_Reward> MissionRewards;
	local array<XComGameState_WorldRegion> PossibleRegions;
	local float MissionDuration;
	local XComGameState_HeadquartersResistance ResHQ;
	
	// Calculate Mission Expiration timer
	MissionDuration = float((default.MissionMinDuration + `SYNC_RAND_STATIC(default.MissionMaxDuration - default.MissionMinDuration + 1)) * 3600);

	PossibleRegions = MissionSource.GetMissionRegionFn(NewGameState);
	RegionState = PossibleRegions[0];

	// Generate the mission reward (either Scientist or Engineer)
	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	CalendarState = GetMissionCalendar(NewGameState);
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate(SelectResistanceOpRewardType(CalendarState)));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	AddTacticalTagToRewardUnit(NewGameState, RewardState, 'VIPReward');
	MissionRewards.AddItem(RewardState);

	// All Resistance Op missions also give an Intel reward
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Intel'));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
	MissionRewards.AddItem(RewardState);

	MissionState = XComGameState_MissionSite(NewGameState.CreateNewStateObject(class'XComGameState_MissionSite'));

	// If first on non-narrative, do not allow Swarm Defense since the reinforcement groups will be too strong
	if (!(XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings')).bXPackNarrativeEnabled) &&
		!CalendarState.HasCreatedMissionOfSource('MissionSource_ResistanceOp'))
	{
		MissionState.ExcludeMissionFamilies.AddItem("SwarmDefense");
	}

	MissionState.BuildMission(MissionSource, RegionState.GetRandom2DLocationInRegion(), RegionState.GetReference(), MissionRewards, true, true, , MissionDuration);
	
	if (!bNoPOI)
	{
		MissionState.PickPOI(NewGameState);
	}

	if (MissionState.GeneratedMission.Mission.MissionFamily == "GatherSurvivors" ||	MissionState.GeneratedMission.Mission.MissionFamily == "RecoverExpedition")
	{
		// Gather Survivors and Recover Expedition have an optional soldier reward
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Soldier'));
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
		AddTacticalTagToRewardUnit(NewGameState, RewardState, 'SoldierRewardA');
		MissionState.Rewards.AddItem(RewardState.GetReference());
	}

	if (MissionState.GeneratedMission.Mission.MissionFamily == "GatherSurvivors")
	{
		// Gather Survivors missions also have a second optional soldier to rescue
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Soldier'));
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		RewardState.GenerateReward(NewGameState, ResHQ.GetMissionResourceRewardScalar(RewardState), RegionState.GetReference());
		AddTacticalTagToRewardUnit(NewGameState, RewardState, 'SoldierRewardB');
		MissionState.Rewards.AddItem(RewardState.GetReference());
	}

	return MissionState;
}

private static function AddTacticalTagToRewardUnit(XComGameState NewGameState, XComGameState_Reward RewardState, name TacticalTag)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));
	if (UnitState != none)
	{
		UnitState.TacticalTag = TacticalTag;
	}
}

private static function GiveSupplyRaidSkipRewards()
{
	local WOTCArchipelago_APClient APClient;

	APClient = `APCLIENT;

	APClient.AddItemNames.AddItem('Supplies');
	APClient.AddItemQuantities.AddItem(GetRandomAmount(default.SupplyRaidSkipMaxSupplies));

	APClient.AddItemNames.AddItem('AlienAlloy');
	APClient.AddItemQuantities.AddItem(GetRandomAmount(default.SupplyRaidSkipMaxAlloys));

	APClient.AddItemNames.AddItem('EleriumDust');
	APClient.AddItemQuantities.AddItem(GetRandomAmount(default.SupplyRaidSkipMaxElerium));

	APClient.AddItemNames.AddItem('EleriumCore');
	APClient.AddItemQuantities.AddItem(GetRandomAmount(default.SupplyRaidSkipMaxCores));
}

private static function int GetRandomAmount(int MaxAmount)
{
	local float Mult;

	Mult = `APCFG(SKIP_RAID_REWARD_MULT_BASE) + `APCFG(SKIP_RAID_REWARD_MULT_ERR) * (2.0 * `SYNC_FRAND_STATIC() - 1.0);
	return Clamp(MaxAmount * Mult, 0, MaxAmount);
}
