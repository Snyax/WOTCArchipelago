class XComGameState_APStore extends XComGameState_BaseObject;

var private array<name> CheckBuffer;

static function array<name> ReadCheckBuffer(optional XComGameState NewGameState)
{
	local XComGameState_APStore		APStore;
	local array<name>				EmptyBuffer;

	`AMLOG("Reading CheckBuffer");

	if (NewGameState != none)
	{
		foreach NewGameState.IterateByClassType(class'XComGameState_APStore', APStore) break;
		if (APStore != none) return APStore.CheckBuffer;
	}

	APStore = XComGameState_APStore(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_APStore', true));
	if (APStore != none) return APStore.CheckBuffer;

	`AMLOG("No APStore found");
	EmptyBuffer.Length = 0;
	return EmptyBuffer;
}

static function WriteCheckBuffer(XComGameState NewGameState, array<name> NewBuffer)
{
	local XComGameState_APStore APStore;

	`AMLOG("Writing CheckBuffer of length " $ NewBuffer.Length);

	foreach NewGameState.IterateByClassType(class'XComGameState_APStore', APStore) break;
	if (APStore == none)
	{
		APStore = XComGameState_APStore(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_APStore', true));
		if (APStore == none)
		{
			APStore = XComGameState_APStore(NewGameState.CreateNewStateObject(class'XComGameState_APStore'));
		}
		else
		{
			APStore = XComGameState_APStore(NewGameState.ModifyStateObject(class'XComGameState_APStore', APStore.ObjectID));
		}
	}

	APStore.CheckBuffer = NewBuffer;
}
