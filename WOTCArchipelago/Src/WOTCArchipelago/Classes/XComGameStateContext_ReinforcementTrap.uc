class XComGameStateContext_ReinforcementTrap extends XComGameStateContext;

var name EncounterID;
var name VisualizationType;

function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return `TACTICALMISSIONMGR.ConfigurableEncounters.Find('EncounterID', EncounterID) != INDEX_NONE;
}

function XComGameState ContextBuildGameState()
{
	local XComGameState NewGameState;

	NewGameState = `XCOMHISTORY.CreateNewGameState(true, self);

	if (!Validate())
	{
		`AMLOG("Invalid EncounterID: " $ EncounterID);
		return NewGameState;
	}

	class'XComGameState_AIReinforcementSpawner'.static.InitiateReinforcements(
		EncounterID,
		,  // Override countdown
		,
		,
		15,  // Ideal spawn tile offset
		NewGameState,
		,
		VisualizationType,
		false,  // Don't spawn in XCOM LOS
		true,  // Must spawn in XCOM LOS
		false,  // Don't spawn in hazards
		false,  // Force scamper
		false,  // Always orient along LOP
		true  // Ignore unit cap
	);

	return NewGameState;
}

function string SummaryString()
{
	return "XComGameStateContext_ReinforcementTrap_" $ EncounterID;
}

defaultproperties
{
	VisualizationType = "ATT"
}
