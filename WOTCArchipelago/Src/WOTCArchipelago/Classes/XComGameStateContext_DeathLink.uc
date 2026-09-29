class XComGameStateContext_DeathLink extends XComGameStateContext;

enum EDeathLinkResult
{
	eDeathLinkResult_Hit,
	eDeathLinkResult_Miss,
	eDeathLinkResult_Tank,
	eDeathLinkResult_Parry,
};

var StateObjectReference TargetUnit;
var string Cause;
var EDeathLinkResult Result;

var localized string strDeathLinkReceived;
var localized string strDeathLinkDodged;
var localized string strDeathLinkWithstood;
var localized string strDeathLinkParried;

function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

function XComGameState ContextBuildGameState()
{
	local XComGameState			NewGameState;
	local XComGameState_Unit	TargetUnitState;

	NewGameState = `XCOMHISTORY.CreateNewGameState(true, self);
	TargetUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', TargetUnit.ObjectID));

	if (Result == eDeathLinkResult_Hit)
	{
		// Deal damage equal to current health and ignore shields
		TargetUnitState.TakeDamage(NewGameState, TargetUnitState.GetCurrentStat(eStat_HP), 0, 0, , , , , , , , true);
	}

	return NewGameState;
}

protected function ContextBuildVisualization()
{
	local VisualizationActionMetadata	ActionMetadata;
	local X2VisualizerInterface			TargetVisualizerInterface;
	local XComGameState_Unit			TargetUnitState;
	local X2Action_CameraLookAt			LookAtCamera;
	local X2Action_PlayAnimation		AnimationAction;
	local X2Action_PlayMessageBanner	MessageAction;
	local string						Message;
	local EUIState						MessageColor;

	ActionMetadata.VisualizeActor = `XCOMHISTORY.GetVisualizer(TargetUnit.ObjectID);
	`XCOMHISTORY.GetCurrentAndPreviousGameStatesForObjectID(TargetUnit.ObjectID, ActionMetadata.StateObject_OldState, ActionMetadata.StateObject_NewState, eReturnType_Reference, AssociatedState.HistoryIndex);

	// Message banner
	TargetUnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	switch (Result)
	{
		case eDeathLinkResult_Hit:
			Message = Cause;
			MessageColor = eUIState_Bad;
			break;
		case eDeathLinkResult_Miss:
			Message = `APUNITINFO(default.strDeathLinkDodged, TargetUnitState);
			MessageColor = eUIState_Normal;
			break;
		case eDeathLinkResult_Tank:
			Message = `APUNITINFO(default.strDeathLinkWithstood, TargetUnitState);
			MessageColor = eUIState_Good;
			break;
		case eDeathLinkResult_Parry:
			Message = `APUNITINFO(default.strDeathLinkParried, TargetUnitState);
			MessageColor = eUIState_Good;
			break;
	}

	MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
	MessageAction.AddMessageBanner(class'WOTCArchipelago_APClient'.default.strTacticalMessageTitle, "", default.strDeathLinkReceived, Message, MessageColor);

	// Look at unit
	LookAtCamera = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
	LookAtCamera.LookAtActor = ActionMetadata.VisualizeActor;
	LookAtCamera.BlockUntilActorOnScreen = true;

	// Play unit animation
	if (Result == eDeathLinkResult_Tank)
	{
		LookAtCamera.LookAtDuration = 3.0;
		AnimationAction = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
		AnimationAction.Params.AnimName = 'HL_Psi_MindControlled';
	}
	else if (Result == eDeathLinkResult_Parry)
	{
		LookAtCamera.LookAtDuration = 6.0;
		AnimationAction = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded));
		AnimationAction.Params.AnimName = 'HL_Psi_MindControl';
	}
	else class'X2Action_ApplyWeaponDamageToUnit'.static.AddToVisualizationTree(ActionMetadata, self, false, ActionMetadata.LastActionAdded);

	TargetVisualizerInterface = X2VisualizerInterface(ActionMetadata.VisualizeActor);
	if (TargetVisualizerInterface != none) TargetVisualizerInterface.BuildAbilityEffectsVisualization(AssociatedState, ActionMetadata);
}

function string SummaryString()
{
	return "XComGameStateContext_DeathLink";
}
