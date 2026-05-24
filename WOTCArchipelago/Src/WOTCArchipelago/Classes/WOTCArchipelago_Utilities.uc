class WOTCArchipelago_Utilities extends Object;

var localized string strFirstName;
var localized string strLastName;
var localized string strNickName;
var localized string strRankFullName;
var localized string strFullName;
var localized string strRankName;
var localized string strRankLastName;
var localized string strFullNickName;

static function bool GetNewestStateObject(int ObjectID, out XComGameState_BaseObject StateObject, optional XComGameState NewGameState)
{
	if (NewGameState != none)
	{
		StateObject = NewGameState.GetGameStateForObjectID(ObjectID);
		if (StateObject != none) return true;
	}

	StateObject = `XCOMHISTORY.GetGameStateForObjectID(ObjectID);
	return (StateObject != none);
}

static function bool GetNewestItemStateInHQInventory(name TemplateName, out XComGameState_Item ItemState, optional XComGameState NewGameState)
{
	local XComGameState_BaseObject			StateObject;
	local XComGameState_HeadquartersXCom	XComHQ;
	local int								Idx;

	if (!GetNewestStateObject(`XCOMHQ.ObjectID, StateObject, NewGameState)) return false;

	XComHQ = XComGameState_HeadquartersXCom(StateObject);
	for (Idx = 0; Idx < XComHQ.Inventory.Length; Idx++)
	{
		if (GetNewestStateObject(XComHQ.Inventory[Idx].ObjectID, StateObject, NewGameState))
		{
			ItemState = XComGameState_Item(StateObject);
			if (ItemState.GetMyTemplateName() == TemplateName) return true;
		}
	}

	return false;
}

static function int GetItemCountInHQInventory(name TemplateName, optional XComGameState NewGameState)
{
	local XComGameState_Item				ItemState;

	if (GetNewestItemStateInHQInventory(TemplateName, ItemState, NewGameState))
	{
		return ItemState.Quantity;
	}

	return 0;
}

static function AddItemToHQInventory(XComGameState NewGameState, name TemplateName, optional int Quantity = 1)
{
    local XComGameState_HeadquartersXCom	XComHQ;
	local X2ItemTemplateManager             ItemMgr;
	local X2ItemTemplate					ItemTemplate;
    local XComGameState_Item				ItemState;
	
    XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', `XCOMHQ.ObjectID));

	// Create ItemState
	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	ItemTemplate = ItemMgr.FindItemTemplate(TemplateName);
    ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
	ItemState.Quantity = Quantity;
	
	// Add item to inventory
    XComHQ.PutItemInInventory(NewGameState, ItemState);

	// Do not print to log for story objective completion resource items
	if (TemplateName == 'PsiGateObjectiveCompleted') return;
	if (TemplateName == 'StasisSuitObjectiveCompleted') return;
	if (TemplateName == 'AvatarCorpseObjectiveCompleted') return;
	`AMLOG("Added item to HQ inventory: " $ TemplateName $ " x" $ Quantity);
}

static function AddStaffToHQCrew(XComGameState NewGameState, name TemplateName, optional int Quantity = 1)
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				UnitState;
	local int								Idx;

	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', `XCOMHQ.ObjectID));

	for (Idx = 0; Idx < Quantity; Idx++)
	{
		// Create UnitState
		UnitState = `CHARACTERPOOLMGR.CreateCharacter(NewGameState, `XPROFILESETTINGS.Data.m_eCharPoolUsage, TemplateName);
		UnitState.RandomizeStats();

		// Add staff to crew
		XComHQ.AddToCrew(NewGameState, UnitState);
		XComHQ.HandlePowerOrStaffingChange(NewGameState);
	}

	`AMLOG("Added staff to HQ crew: " $ TemplateName $ " x" $ Quantity);
}

static function int ReadCounter(name CounterName, optional XComGameState NewGameState)
{
	return GetItemCountInHQInventory(CounterName, NewGameState);
}

static function int IncrementCounter(name CounterName, optional XComGameState NewGameState)
{
	if (NewGameState != none)
	{
		AddItemToHQInventory(NewGameState, CounterName);
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding counter item to HQ Inventory");
		AddItemToHQInventory(NewGameState, CounterName);
		`GAMERULES.SubmitGameState(NewGameState);
		NewGameState = none;
	}

	return ReadCounter(CounterName, NewGameState);
}

static function int DecrementCounter(name CounterName, optional XComGameState NewGameState)
{
	if (NewGameState != none)
	{
		AddItemToHQInventory(NewGameState, CounterName, -1);
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing counter item from HQ Inventory");
		AddItemToHQInventory(NewGameState, CounterName, -1);
		`GAMERULES.SubmitGameState(NewGameState);
		NewGameState = none;
	}

	return ReadCounter(CounterName, NewGameState);
}

static function string InsertUnitInfo(coerce string Str, XComGameState_Unit UnitState)
{
	Str = Repl(Str, default.strFirstName, UnitState.GetName(eNameType_First));
	Str = Repl(Str, default.strLastName, UnitState.GetName(eNameType_Last));
	Str = Repl(Str, default.strNickName, UnitState.GetName(eNameType_Nick));
	Str = Repl(Str, default.strRankFullName, UnitState.GetName(eNameType_RankFull));
	Str = Repl(Str, default.strFullName, UnitState.GetName(eNameType_Full));
	Str = Repl(Str, default.strRankName, UnitState.GetName(eNameType_Rank));
	Str = Repl(Str, default.strRankLastName, UnitState.GetName(eNameType_RankLast));
	Str = Repl(Str, default.strFullNickName, UnitState.GetName(eNameType_FullNick));

	return Str;
}
