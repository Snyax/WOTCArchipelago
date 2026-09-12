class XComGameStateContext_NoAmmoTrap extends XComGameStateContext;

function bool Validate(optional EInterruptionStatus InInterruptionStatus)
{
	return true;
}

function XComGameState ContextBuildGameState()
{
	local XComGameState			NewGameState;
	local StateObjectReference	UnitRef;
	local XComGameState_Unit	UnitState;
	local XComGameState_Item	WeaponState;

	NewGameState = `XCOMHISTORY.CreateNewGameState(true, self);

	foreach `XCOMHQ.Squad(UnitRef)
	{
		if (UnitRef.ObjectID == 0) continue;
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState == none) continue;

		WeaponState = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, NewGameState);
		if (WeaponState == none) continue;

		WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', WeaponState.ObjectID));
		WeaponState.Ammo = 0;
	}

	return NewGameState;
}

function string SummaryString()
{
	return "XComGameStateContext_NoAmmoTrap";
}
