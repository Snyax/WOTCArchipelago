class WOTCArchipelago_APClient extends Actor
		config(WOTCArchipelago)
		dependson(WOTCArchipelago_TcpLink);

struct native Translation {
	var name WorldName;
	var name ModName;
};

var array<name> AddItemNames;
var array<int> AddItemQuantities;

var bool bShowCustomPopup;
var string CustomPopupTitle;
var string CustomPopupText;

var private int SinceLastTick;
var private WOTCArchipelago_TcpLink TickLink;

var private string TechCompletedType;
var private string PromotionType;
var private string CovertActionRewardType;
var private string ResourceType;
var private string StaffType;
var private string TrapType;

var private array<name> CheckBuffer;

var config bool bRequirePsiGate;
var config bool bRequireStasisSuit;
var config bool bRequireAvatarCorpse;

var config array<Translation> LocationTranslator;

var localized string strRequestTimedOut;
var localized string strRequestTimedOutDetails;
var localized string strClientDisconnected;
var localized string strClientDisconnectedDetails;

var localized string strDisconnectedWarning;
var localized string strDisconnectedWarningDetails;
var localized string strIncompatibleWarning;
var localized string strIncompatibleWarningDetails;

var localized string strDoomTrapMessage;
var localized string strDialogAccept;
var localized string strDramaticMessageTitle;


//=======================================================================================
//                                       INIT
//---------------------------------------------------------------------------------------

static function WOTCArchipelago_APClient GetAPClient()
{
	local WOTCArchipelago_APClient APClient;

	foreach `XCOMGAME.AllActors(class'WOTCArchipelago_APClient', APClient)
	{
		break;
	}

	if (APClient == none)
	{
		APClient = `XCOMGAME.Spawn(class'WOTCArchipelago_APClient');
		APClient.Initialize();
	}

	return APClient;
}

private function Initialize()
{
	`AMLOG("Initializing APClient");

	bShowCustomPopup = false;
	CustomPopupTitle = "";
	CustomPopupText = "";

	SinceLastTick = 0;
	TickLink = Spawn(class'WOTCArchipelago_TcpLink');

	TechCompletedType = "[TechCompleted]";
	PromotionType = "[Promotion]";
	CovertActionRewardType = "[CovertActionReward]";
	ResourceType = "[Resource]";
	StaffType = "[Staff]";
	TrapType = "[Trap]";
}


//=======================================================================================
//                                       CHECK
//---------------------------------------------------------------------------------------

// CheckName depends on the type of check
//
// Research/Shadow Chamber Projects:	TechTemplate.DataName
// Enemy Kills:							'Kill' + CharTemplate.CharacterGroupName
// Item Uses:							'Use' + ItemTemplate.DataName
// Chosen Hunt Covert Actions:			'ChosenHuntPt' + [1/2/3] + ':' + [1/2/3]
// Soldier Class Ranks:					SoldierClassTemplate.DataName + 'Rank' + [MinRank..MaxRank]
function OnCheckReached(XComGameState NewGameState, name CheckName)
{
	local Translation				Entry;
	local WOTCArchipelago_TcpLink	Link;

	// Translate location name (for APWorld mods)
	foreach default.LocationTranslator(Entry)
	{
		if (CheckName == Entry.ModName)
		{
			CheckName = Entry.WorldName;
			break;
		}
	}
	
	`AMLOG("Check reached: " $ CheckName);
	
	Link = Spawn(class'WOTCArchipelago_TcpLink');
	Link.Call("/Check/" $ CheckName, CheckResponseHandler, CheckErrorHandler);
}

private function CheckResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	local array<string>		Messages;
	local string			Message;

	if (Resp.ResponseCode >= 300) return;

	Messages = SplitString(Resp.Body, "\n\n", true);

	foreach Messages(Message)
	{
		HandleMessage(Message);
	}
	
	Link.Destroy();
	ClearCheckBuffer();
}

private function CheckErrorHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	`AMLOG("Check Error Status: " $ Resp.ResponseCode);

	// Client can not be reached
	if (Resp.ResponseCode == 408)
	{
		RaiseDialog(default.strRequestTimedOut, default.strRequestTimedOutDetails);
	}
	// Client is not connected to server
	else if (Resp.ResponseCode == 503)
	{
		RaiseDialog(default.strClientDisconnected, default.strClientDisconnectedDetails);
	}

	AppendCheckBuffer(Link.GetCheckName());
	Link.Destroy();
}

private function AppendCheckBuffer(name CheckName)
{
	if (CheckBuffer.Find(CheckName) == INDEX_NONE) CheckBuffer.AddItem(CheckName);
}

private function ClearCheckBuffer()
{
	local XComGameState		NewGameState;
	local name				CheckName;

	while (CheckBuffer.Length > 0)
	{
		CheckName = CheckBuffer[0];

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Re-send check " $ CheckName $ " from buffer");
		OnCheckReached(NewGameState, CheckName);
		`GAMERULES.SubmitGameState(NewGameState);

		CheckBuffer.Remove(0, 1);
	}
}


//=======================================================================================
//                                       HINT
//---------------------------------------------------------------------------------------

function CreateServerHint(XComGameState NewGameState, name CheckName)
{
	local WOTCArchipelago_TcpLink Link;
	
	`AMLOG("Hint created: " $ CheckName);
	
	Link = Spawn(class'WOTCArchipelago_TcpLink');
	Link.Call("/Hint/" $ CheckName, HintResponseHandler, HintErrorHandler);
}

private function HintResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	Link.Destroy();
	ClearCheckBuffer();
}

private function HintErrorHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	`AMLOG("Hint Error Status: " $ Resp.ResponseCode);
	Link.Destroy();
}


//=======================================================================================
//                                      UPDATE
//---------------------------------------------------------------------------------------

function Update()
{
	if (SinceLastTick % 4 == 0) DoChores();

	// Periodically send ticks
	if (SinceLastTick++ < 25) return;
	SinceLastTick = 0;
	SendTick();
}

function DoChores()
{
	// Handle add item
	if (AddItemNames.Length > 0) HandleAddItem();

	// Handle custom popup
	if (bShowCustomPopup)
	{
		RaiseDialog(CustomPopupTitle, CustomPopupText);
		bShowCustomPopup = false;
	}

	HandleObjectiveCompletion();
	HandleStrongholdUnlock();
	HandleReplaceFactionHero();
	HandleRanksanityPromotions();
}

private function HandleAddItem()
{
	local XComGameState		NewGameState;
	local int				Idx;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding items to HQ inventory");

	for (Idx = 0; Idx < AddItemNames.Length; Idx++)
	{
		if (AddItemQuantities.Length <= Idx)
		{
			`AMLOG("Too few quantities given for add item");
			AddItemQuantities.AddItem(1);
		}

		`APADDITEM(NewGameState, AddItemNames[Idx], AddItemQuantities[Idx]);
	}
	
	`GAMERULES.SubmitGameState(NewGameState);

	AddItemNames.Length = 0;
	AddItemQuantities.Length = 0;
}

private static function HandleObjectiveCompletion()
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState						NewGameState;

	XComHQ = `XCOMHQ;

	// Add story objective completed counters to HQ inventory
	if (!default.bRequirePsiGate || XComHQ.IsObjectiveCompleted('T4_M2_ConstructPsiGate')) `APCTRINC('PsiGateObjectiveCompleted');
	if (!default.bRequireStasisSuit || XComHQ.IsObjectiveCompleted('T2_M4_BuildStasisSuit')) `APCTRINC('StasisSuitObjectiveCompleted');
	if (!default.bRequireAvatarCorpse || XComHQ.IsObjectiveCompleted('T1_M6_S0_RecoverAvatarCorpse')) `APCTRINC('AvatarCorpseObjectiveCompleted');

	// HACK: Periodically trigger events to fix sequence broken objectives
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("HACK: Trigger events for sequence breaks");
	`XEVENTMGR.TriggerEvent('ResearchCompleted', , , NewGameState);
	`XEVENTMGR.TriggerEvent('FacilityConstructionCompleted', , , NewGameState); // Proving Grounds, Shadow Chamber
	`XEVENTMGR.TriggerEvent('ItemConstructionCompleted', , , NewGameState); // Skulljack
	`GAMERULES.SubmitGameState(NewGameState);

	// Remove story objective completed counters from HQ inventory
	`APCTRDEC('PsiGateObjectiveCompleted');
	`APCTRDEC('StasisSuitObjectiveCompleted');
	`APCTRDEC('AvatarCorpseObjectiveCompleted');
}

private static function HandleStrongholdUnlock()
{
	local XComGameState_AdventChosen ChosenState;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_AdventChosen', ChosenState)
	{
		if (!ChosenState.bDefeated && ChosenState.bMetXCom && ChosenState.GetRivalFaction().bMetXCom)
		{
			if (ChosenState.GetMyTemplateName() == 'Chosen_Assassin' && `APCTRREAD('AssassinStrongholdReceived') >= 1)
			{
				UnlockChosenStronghold(ChosenState);
				`APCTRDEC('AssassinStrongholdReceived');
			}
			else if (ChosenState.GetMyTemplateName() == 'Chosen_Hunter' && `APCTRREAD('HunterStrongholdReceived') >= 1)
			{
				UnlockChosenStronghold(ChosenState);
				`APCTRDEC('HunterStrongholdReceived');
			}
			else if (ChosenState.GetMyTemplateName() == 'Chosen_Warlock' && `APCTRREAD('WarlockStrongholdReceived') >= 1)
			{
				UnlockChosenStronghold(ChosenState);
				`APCTRDEC('WarlockStrongholdReceived');
			}
		}
	}
}

private static function UnlockChosenStronghold(XComGameState_AdventChosen ChosenState)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Unlocking chosen stronghold mission");

	ChosenState = XComGameState_AdventChosen(NewGameState.ModifyStateObject(class'XComGameState_AdventChosen', ChosenState.ObjectID));
	ChosenState.MakeStrongholdMissionVisible(NewGameState);
	ChosenState.MakeStrongholdMissionAvailable(NewGameState);

	`GAMERULES.SubmitGameState(NewGameState);

	`AMLOG("Unlocked stronghold of " $ ChosenState.GetMyTemplateName());
}

private static function HandleReplaceFactionHero()
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_ResistanceFaction	FactionState;
	local bool								bSoldierPresent;
	local name								CharacterClass;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;

	if (!`APCFG(REPLACE_FACTION_HERO)) return;

	History = `XCOMHISTORY;
	XComHQ = `XCOMHQ;

	foreach History.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		if (!FactionState.bMetXCom) continue;
			
		bSoldierPresent = false;
		CharacterClass = FactionState.GetMyTemplate().ChampionCharacterClass;

		foreach XComHQ.Crew(UnitRef)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));

			if (UnitState.GetMyTemplateName() == CharacterClass)
			{
				bSoldierPresent = true;
				break;
			}
		}

		if (!bSoldierPresent)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Replace faction hero");
			`APADDSTAFF(NewGameState, CharacterClass);
			`GAMERULES.SubmitGameState(NewGameState);
		}
	}
}

static function HandleRanksanityPromotions(optional XComGameState NewGameState)
{
	local StateObjectReference	UnitRef;
	local XComGameState_Unit	UnitState;
	local bool					bLocalGameState;

	if (!class'WOTCArchipelago_Ranksanity'.default.bEnableRanksanity) return;

	bLocalGameState = false;
	if (NewGameState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Handle ranksanity promotions and location checks");
		bLocalGameState = true;
	}
	
	foreach `XCOMHQ.Crew(UnitRef)
	{
		// Filter non-soldier units and disabled soldier classes
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		if (!UnitState.IsSoldier()) continue;
		if (!class'WOTCArchipelago_Ranksanity'.static.IsEnabled(UnitState.GetSoldierClassTemplateName())) continue;
		
		// Grant missing promotions (from received rank items)
		class'WOTCArchipelago_Ranksanity'.static.GrantMissingPromotions(NewGameState, UnitRef);

		// Send missing rank checks (determine reached rank from total kills, can be triggered by promotions above)
		class'WOTCArchipelago_Ranksanity'.static.SendMissingChecks(NewGameState, UnitRef);
	}

	if (bLocalGameState) `GAMERULES.SubmitGameState(NewGameState);
}


//=======================================================================================
//                                       TICK
//---------------------------------------------------------------------------------------

function SendTick()
{
	local string Path;

	// Strategy
	if (`HQPRES != none)
	{
		Path = "/Tick/Strategy/" $ `APCTRREAD('ItemsReceivedStrategy');
		TickLink.Call(Path, TickStrategyResponseHandler, TickErrorHandler);
	}
	// Tactical
	else
	{
		Path = "/Tick/Tactical/" $ `APCTRREAD('ItemsReceivedTactical');
		TickLink.Call(Path, TickTacticalResponseHandler, TickErrorHandler);
	}
}

private function TickStrategyResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	local array<string>		Messages;
	local int				NumMessages;
	local string			Message;
	local int				ItemNr;

	if (Resp.ResponseCode >= 300) return;

	Messages = SplitString(Resp.Body, "\n\n", true);

	// Max 5 messages per tick (plus 1 state message)
	NumMessages = Min(5 + 1, Messages.Length);

	for (ItemNr = 0; ItemNr < NumMessages; ItemNr++)
	{
		Message = Messages[ItemNr];
		
		// Check for integer state message
		if (Message == string(int(Message)))
		{
			// Abort if state is mismatched
			if (int(Message) != `APCTRREAD('ItemsReceivedStrategy')) return;
			continue;
		}

		HandleMessage(Message);
		`APCTRINC('ItemsReceivedStrategy');
	}
	
	ClearCheckBuffer();
}

private function TickTacticalResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	local array<string>		Messages;
	local int				NumMessages;
	local string			Message;
	local int				ItemNr;

	if (Resp.ResponseCode >= 300) return;

	Messages = SplitString(Resp.Body, "\n\n", true);

	// Max 5 messages per tick (plus 1 state message)
	NumMessages = Min(5 + 1, Messages.Length);

	for (ItemNr = 0; ItemNr < NumMessages; ItemNr++)
	{
		Message = Messages[ItemNr];

		// Check for integer state message
		if (Message == string(int(Message)))
		{
			// Abort if state is mismatched
			if (int(Message) != `APCTRREAD('ItemsReceivedTactical')) return;
			continue;
		}
		
		HandleMessage(Message);
		`APCTRINC('ItemsReceivedTactical');
	}

	ClearCheckBuffer();
}

private function TickErrorHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	`AMLOG("Tick Error Status: " $ Resp.ResponseCode);

	// Client can not be reached
	if (Resp.ResponseCode == 408)
	{
	    RaiseDialog(default.strRequestTimedOut, default.strRequestTimedOutDetails);
	}
	// Client is not connected to server
	else if (Resp.ResponseCode == 503)
	{
	    RaiseDialog(default.strClientDisconnected, default.strClientDisconnectedDetails);
	}

	Link.Destroy();
	TickLink = Spawn(class'WOTCArchipelago_TcpLink');
}


//=======================================================================================
//                                      RESPONSE
//---------------------------------------------------------------------------------------

private function HandleMessage(string Message)
{
	local array<string>		Lines;
	local array<string>		ItemData;
	local name				ItemName;
	local int				ItemValue;
	local XComGameState		NewGameState;

	Lines = SplitString(Message, "\n", true);
	
	// TechCompleted
	if (Left(Lines[0], Len(TechCompletedType)) == TechCompletedType)
	{
		ItemName = name(Mid(Lines[0], Len(TechCompletedType)));

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding TechCompleted item to HQ inventory");
		`APADDITEM(NewGameState, ItemName);
		`XEVENTMGR.TriggerEvent('ResearchCompleted', , , NewGameState); // Trigger ResearchCompleted event
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Promotion
	else if (Left(Lines[0], Len(PromotionType)) == PromotionType)
	{
		ItemName = name(Mid(Lines[0], Len(PromotionType), Len(Lines[0]) - Len(PromotionType) - 4));  // Cut off trailing "Rank"
		ItemName = class'X2Item_APCounterResources'.static.GetRankReceivedCounterName(ItemName);  // Write counter name into ItemName
		`APCTRINC(ItemName);
		HandleRanksanityPromotions();  // Promote soldiers immediately
	}
	// CovertActionReward
	else if (Left(Lines[0], Len(CovertActionRewardType)) == CovertActionRewardType)
	{
		ItemName = name(Mid(Lines[0], Len(CovertActionRewardType)));

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Giving CovertActionReward item");
		GiveCovertActionReward(NewGameState, ItemName);
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Resource
	else if (Left(Lines[0], Len(ResourceType)) == ResourceType)
	{
		ItemData = SplitString(Mid(Lines[0], Len(ResourceType)), ":");
		ItemName = name(ItemData[0]);
		ItemValue = int(ItemData[1]);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding resource item to HQ inventory");
		`APADDITEM(NewGameState, ItemName, ItemValue);
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Staff
	else if (Left(Lines[0], Len(StaffType)) == StaffType)
	{
		ItemData = SplitString(Mid(Lines[0], Len(StaffType)), ":");
		ItemName = name(ItemData[0]);
		ItemValue = int(ItemData[1]);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding staff to HQ crew");
		`APADDSTAFF(NewGameState, ItemName, ItemValue);
		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Trap
	else if (Left(Lines[0], Len(TrapType)) == TrapType)
	{
		ItemData = SplitString(Mid(Lines[0], Len(TrapType)), ":");
		ItemName = name(ItemData[0]);
		ItemValue = int(ItemData[1]);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Triggering trap");
		TriggerTrap(NewGameState, ItemName, ItemValue);
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		// No item received, raise arbitrary dialogue and exit
		RaiseDialog(Lines[0], Lines[1]);
		return;
	}

	// If item was received, raise ItemReceived dialogue
	RaiseDialog(Lines[1], Lines[2]);
}

private static function GiveCovertActionReward(XComGameState NewGameState, name RewardName)
{
	if (RewardName == 'FactionInfluence') RaiseFactionInfluence(NewGameState);
	else if (RewardName == 'AssassinStronghold') `APCTRINC('AssassinStrongholdReceived', NewGameState);
	else if (RewardName == 'HunterStronghold') `APCTRINC('HunterStrongholdReceived', NewGameState);
	else if (RewardName == 'WarlockStronghold') `APCTRINC('WarlockStrongholdReceived', NewGameState);
}

private static function RaiseFactionInfluence(XComGameState NewGameState, optional XComGameState_ResistanceFaction FactionState)
{
	if (FactionState == none)
	{
		// Pick starting faction at influence 0 or any faction at influence 1
		foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
		{
			if (FactionState.Influence == eFactionInfluence_Minimal && FactionState.bFirstFaction) break;
			if (FactionState.Influence == eFactionInfluence_Respected) break;
			FactionState = none;
		}

		if (FactionState == none)
		{
			// Otherwise, pick any faction at influence 0 (ignore bFarthestFaction for now)
			foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
			{
				if (FactionState.Influence == eFactionInfluence_Minimal) break;
				FactionState = none;
			}
		}
	}

	// No appropriate faction found
	if (FactionState == none) return;

	FactionState = XComGameState_ResistanceFaction(NewGameState.ModifyStateObject(class'XComGameState_ResistanceFaction', FactionState.ObjectID));
	FactionState.IncreaseInfluenceLevel(NewGameState);

	`AMLOG("Increased influence of " $ FactionState.GetMyTemplateName());
}

private static function TriggerTrap(XComGameState NewGameState, name TrapName, optional int Quantity = 1)
{
	local XComGameState_HeadquartersAlien	AlienHQ;
	local int								StartingForceLevel;
	local int								MaxForceLevel;
	local int								Idx;

	// Ignore traps on the first day if the setting is active
	if (class'X2StrategyGameRulesetDataStructures'.static.IsFirstDay(class'XComGameState_GeoscapeEntity'.static.GetCurrentTime()))
	{
		if (`APCFG(NO_STARTING_TRAPS)) return;
	}

	AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	AlienHQ = XComGameState_HeadquartersAlien(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));

	StartingForceLevel = class'XComGameState_HeadquartersAlien'.default.AlienHeadquarters_StartingForceLevel;
	MaxForceLevel = class'XComGameState_HeadquartersAlien'.default.AlienHeadquarters_MaxForceLevel;

	for (Idx = 0; Idx < Quantity; Idx++)
	{
		// Doom
		if (TrapName == 'Doom')
		{
			`HQPRES.StrategyMap2D.StrategyMapHUD.SetDoomMessage(default.strDoomTrapMessage, false, false);
			AlienHQ.ModifyDoom();
		}
		// Force Level
		else if (TrapName == 'ForceLevel')
		{
			AlienHQ.ForceLevel = Clamp(AlienHQ.ForceLevel + 1, StartingForceLevel, MaxForceLevel);
		}
	}

	`AMLOG("Triggered trap: " $ TrapName $ " x" $ Quantity);
}


//=======================================================================================
//                                      DIALOG
//---------------------------------------------------------------------------------------

private static function RaiseDialog(string Title, string Text)
{
	local TDialogueBoxData				kDialogData;
	local SeqAct_ShowDramaticMessage	SeqActShowDramaticMessage;
	local XComGameState					NewGameState;

	// "None" signifies to skip dialog box
	if (Title == "None") return;
	if (Text == "None") return;

	if (`HQPRES != none)
	{
		kDialogData.eType		= eDialog_Normal;
		kDialogData.strTitle	= Title;
		kDialogData.strText		= Text;
		kDialogData.strAccept	= default.strDialogAccept;

		`HQPRES.UIRaiseDialog(kDialogData);
	}
	else
	{
		SeqActShowDramaticMessage = new class'SeqAct_ShowDramaticMessage';
		SeqActShowDramaticMessage.Title = default.strDramaticMessageTitle;
		SeqActShowDramaticMessage.Message1 = Title;
		SeqActShowDramaticMessage.Message2 = Text;
		SeqActShowDramaticMessage.MessageColor = eUIState_Normal;
		
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SeqAct: Archipelago Tactical Message");
		SeqActShowDramaticMessage.BuildVisualization(NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}
