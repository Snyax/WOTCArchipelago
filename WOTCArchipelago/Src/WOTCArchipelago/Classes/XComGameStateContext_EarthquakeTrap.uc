class XComGameStateContext_EarthquakeTrap extends XComGameStateContext config(WOTCArchipelago);

var config string ScreenShakeAnim;
var config float ScreenShakeDuration;
var config float ScreenShakeRate;

var array<StateObjectReference> AffectedUnits;
var array<StateObjectReference> LookAtUnits;
var int Magnitude;

function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

function XComGameState ContextBuildGameState()
{
	local XComGameState			NewGameState;
	local StateObjectReference	UnitRef;
	local XComGameState_Unit	UnitState;
	local int					Damage;
	local TTile					OriginalTile;
	local TTile					AdjacentTile;

	NewGameState = `XCOMHISTORY.CreateNewGameState(true, self);

	foreach AffectedUnits(UnitRef)
	{
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
		Damage = Magnitude / 2;
		Damage = Min(UnitState.GetCurrentStat(eStat_HP) + UnitState.GetCurrentStat(eStat_ShieldHP) - 1, Damage);  // Never kill
		if (Damage > 0) UnitState.TakeDamage(NewGameState, Damage, 0, 0);

		UnitState.GetKeystoneVisibilityLocation(OriginalTile);
		if (!UnitState.FindAvailableNeighborTile(AdjacentTile)) continue;
		if (`XWORLD.IsAdjacentTileBlocked(OriginalTile, AdjacentTile)) continue;
		UnitState.SetVisibilityLocation(AdjacentTile);
		`XWORLD.SetTileBlockedByUnitFlag(UnitState);
	}

	return NewGameState;
}

protected function ContextBuildVisualization()
{
	local XComGameStateVisualizationMgr		VisMgr;
	local StateObjectReference				UnitRef;
	local VisualizationActionMetadata		EmptyTrack;
	local VisualizationActionMetadata		ActionMetadata;
	local bool								bShakeCamera;
	local X2Action_CameraLookAtPlayAnim		LookAtPlayAnimCamera;
	local X2Action_CameraLookAt				LookAtCamera;
	local int								OldHP;
	local int								NewHP;
	local X2VisualizerInterface				TargetVisualizerInterface;
	local array<X2Action>					LeafNodes;
	local X2Action_MarkerNamed				JoinActions;

	VisMgr = `XCOMVISUALIZATIONMGR;

	// Look at units
	bShakeCamera = true;
	foreach LookAtUnits(UnitRef)
	{
		ActionMetadata = EmptyTrack;
		ActionMetadata.VisualizeActor = `XCOMHISTORY.GetVisualizer(UnitRef.ObjectID);
		`XCOMHISTORY.GetCurrentAndPreviousGameStatesForObjectID(UnitRef.ObjectID, ActionMetadata.StateObject_OldState, ActionMetadata.StateObject_NewState, eReturnType_Reference, AssociatedState.HistoryIndex);

		// Camera shake
		if (bShakeCamera)
		{
			LookAtPlayAnimCamera = X2Action_CameraLookAtPlayAnim(class'X2Action_CameraLookAtPlayAnim'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
			LookAtPlayAnimCamera.LookAtActor = ActionMetadata.VisualizeActor;
			LookAtPlayAnimCamera.LookAtDuration = default.ScreenShakeDuration;
			LookAtPlayAnimCamera.BlockUntilFinished = true;
			LookAtPlayAnimCamera.Anim = default.ScreenShakeAnim;
			LookAtPlayAnimCamera.Rate = default.ScreenShakeRate;
			LookAtPlayAnimCamera.Intensity = float(Magnitude) * 0.75;
			LookAtPlayAnimCamera.bLoop = true;
			if (Magnitude > 1) LookAtPlayAnimCamera.DistortUI = default.ScreenShakeDuration + 1.0;
			bShakeCamera = false;
		}

		LookAtCamera = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
		LookAtCamera.LookAtActor = ActionMetadata.VisualizeActor;
		LookAtCamera.LookAtDuration = 1.0;
		LookAtCamera.BlockUntilFinished = true;

		class'X2Action_BlockAbilityActivation'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded);
	}

	// Unit animations
	foreach AffectedUnits(UnitRef)
	{
		ActionMetadata = EmptyTrack;
		ActionMetadata.VisualizeActor = `XCOMHISTORY.GetVisualizer(UnitRef.ObjectID);
		`XCOMHISTORY.GetCurrentAndPreviousGameStatesForObjectID(UnitRef.ObjectID, ActionMetadata.StateObject_OldState, ActionMetadata.StateObject_NewState, eReturnType_Reference, AssociatedState.HistoryIndex);

		OldHP = XComGameState_Unit(ActionMetadata.StateObject_OldState).GetCurrentStat(eStat_HP);
		NewHP = XComGameState_Unit(ActionMetadata.StateObject_NewState).GetCurrentStat(eStat_HP);
		if (OldHP != NewHP) class'X2Action_ApplyWeaponDamageToUnit'.static.AddToVisualizationTree(ActionMetadata, self, false, VisMgr.BuildVisTree);
		class'X2Action_Knockback'.static.AddToVisualizationTree(ActionMetadata, self, false, VisMgr.BuildVisTree);

		TargetVisualizerInterface = X2VisualizerInterface(ActionMetadata.VisualizeActor);
		if (TargetVisualizerInterface != none) TargetVisualizerInterface.BuildAbilityEffectsVisualization(AssociatedState, ActionMetadata);
	}

	VisMgr.GetAllLeafNodes(VisMgr.BuildVisTree, LeafNodes);
	JoinActions = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(ActionMetadata, self, false, none, LeafNodes));
	JoinActions.SetName("Join");
}

function string SummaryString()
{
	return "XComGameStateContext_EarthquakeTrap";
}
