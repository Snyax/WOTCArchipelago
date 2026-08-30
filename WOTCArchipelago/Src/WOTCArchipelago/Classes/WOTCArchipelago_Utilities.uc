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

static function string EscapeURL(coerce string Str)
{
	// This first obviously
	Str = Repl(Str, "%", "%25");

	// Reserved characters
	Str = Repl(Str, "!", "%21");
	Str = Repl(Str, "#", "%23");
	Str = Repl(Str, "$", "%24");
	Str = Repl(Str, "&", "%26");
	Str = Repl(Str, "'", "%27");
	Str = Repl(Str, "(", "%28");
	Str = Repl(Str, ")", "%29");
	Str = Repl(Str, "*", "%2A");
	Str = Repl(Str, "+", "%2B");
	Str = Repl(Str, ",", "%2C");
	Str = Repl(Str, "/", "%2F");
	Str = Repl(Str, ":", "%3A");
	Str = Repl(Str, ";", "%3B");
	Str = Repl(Str, "=", "%3D");
	Str = Repl(Str, "?", "%3F");
	Str = Repl(Str, "@", "%40");
	Str = Repl(Str, "[", "%5B");
	Str = Repl(Str, "]", "%5D");

	// Special characters
	Str = Repl(Str, " ", "%20");
	Str = Repl(Str, "\"", "%22");
	Str = Repl(Str, "-", "%2D");
	Str = Repl(Str, ".", "%2E");
	Str = Repl(Str, "<", "%3C");
	Str = Repl(Str, ">", "%3E");
	Str = Repl(Str, "\\", "%5C");
	Str = Repl(Str, "^", "%5E");
	Str = Repl(Str, "_", "%5F");
	Str = Repl(Str, "`", "%60");
	Str = Repl(Str, "{", "%7B");
	Str = Repl(Str, "|", "%7C");
	Str = Repl(Str, "}", "%7D");
	Str = Repl(Str, "~", "%7E");
	Str = Repl(Str, "´", "%C2%B4");

	// Non-latin letter characters
	Str = Repl(Str, "À", "%C3%80", true);
	Str = Repl(Str, "Á", "%C3%81", true);
	Str = Repl(Str, "Â", "%C3%82", true);
	Str = Repl(Str, "Ä", "%C3%84", true);
	Str = Repl(Str, "Ç", "%C3%87", true);
	Str = Repl(Str, "È", "%C3%88", true);
	Str = Repl(Str, "É", "%C3%89", true);
	Str = Repl(Str, "Ê", "%C3%8A", true);
	Str = Repl(Str, "Ì", "%C3%8C", true);
	Str = Repl(Str, "Í", "%C3%8D", true);
	Str = Repl(Str, "Î", "%C3%8E", true);
	Str = Repl(Str, "Ò", "%C3%92", true);
	Str = Repl(Str, "Ó", "%C3%93", true);
	Str = Repl(Str, "Ô", "%C3%94", true);
	Str = Repl(Str, "Ö", "%C3%96", true);
	Str = Repl(Str, "Ù", "%C3%99", true);
	Str = Repl(Str, "Ú", "%C3%9A", true);
	Str = Repl(Str, "Û", "%C3%9B", true);
	Str = Repl(Str, "Ü", "%C3%9C", true);
	Str = Repl(Str, "ß", "%C3%9F", true);
	Str = Repl(Str, "à", "%C3%A0", true);
	Str = Repl(Str, "á", "%C3%A1", true);
	Str = Repl(Str, "â", "%C3%A2", true);
	Str = Repl(Str, "ä", "%C3%A4", true);
	Str = Repl(Str, "ç", "%C3%A7", true);
	Str = Repl(Str, "è", "%C3%A8", true);
	Str = Repl(Str, "é", "%C3%A9", true);
	Str = Repl(Str, "ê", "%C3%AA", true);
	Str = Repl(Str, "ì", "%C3%AC", true);
	Str = Repl(Str, "í", "%C3%AD", true);
	Str = Repl(Str, "î", "%C3%AE", true);
	Str = Repl(Str, "ñ", "%C3%B1", true);
	Str = Repl(Str, "ò", "%C3%B2", true);
	Str = Repl(Str, "ó", "%C3%B3", true);
	Str = Repl(Str, "ô", "%C3%B4", true);
	Str = Repl(Str, "ö", "%C3%B6", true);
	Str = Repl(Str, "ù", "%C3%B9", true);
	Str = Repl(Str, "ú", "%C3%BA", true);
	Str = Repl(Str, "û", "%C3%BB", true);
	Str = Repl(Str, "ü", "%C3%BC", true);
	
	return Str;
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
