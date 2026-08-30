class XComGameStateContext_TacticalMessage extends XComGameStateContext;

var string Title;
var string Message1;
var string Message2;
var EUIState MessageColor;

function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

function XComGameState ContextBuildGameState()
{
	return `XCOMHISTORY.CreateNewGameState(true, self);
}

protected function ContextBuildVisualization()
{
	local XComGameState_KismetVariable	KismetVar;
	local VisualizationActionMetadata	ActionMetadata;
	local X2Action_PlayMessageBanner	MessageAction;

	if (Message1 == "" && Message2 == "") return;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_KismetVariable', KismetVar) break;

	ActionMetadata.StateObject_OldState = KismetVar;
	ActionMetadata.StateObject_NewState = KismetVar;

	MessageAction = X2Action_PlayMessageBanner(class'X2Action_PlayMessageBanner'.static.AddToVisualizationTree(ActionMetadata, self));
	MessageAction.AddMessageBanner(Title, "", Message1, Message2, MessageColor);
}

function string SummaryString()
{
	return "XComGameStateContext_TacticalMessage";
}
