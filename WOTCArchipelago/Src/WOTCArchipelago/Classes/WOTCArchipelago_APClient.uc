class WOTCArchipelago_APClient extends Actor
		config(WOTCArchipelago)
		dependson(WOTCArchipelago_TcpLink);

var private int SinceLastTick;
var private WOTCArchipelago_TcpLink TickLink;

var private bool bBlockDeathLink;
var private bool bDeathTickLoop;
var private WOTCArchipelago_TcpLink DeathTickLink;

var private int NumStrategyObjectives;

var private array<name> CheckBuffer;

var private string TechCompletedType;
var private string PromotionType;
var private string CovertActionRewardType;
var private string ResourceType;
var private string StaffType;
var private string TrapType;

var private bool bShowCustomPopup;
var private string CustomPopupTitle;
var private string CustomPopupText;

var config bool bRequirePsiGate;
var config bool bRequireStasisSuit;
var config bool bRequireAvatarCorpse;

var config array<name> AdventReinforcementEncounters;
var config array<name> AlienReinforcementEncounters;

var config bool bIgnoreMaxPanickingUnits;
var config WillEventRollData MassPanicWillRollData;

var config int MaxMagnitude;

var localized string strRequestTimedOut;
var localized string strRequestTimedOutDetails;
var localized string strClientDisconnected;
var localized string strClientDisconnectedDetails;

var localized string strDisconnectedWarning;
var localized string strDisconnectedWarningDetails;
var localized string strIncompatibleWarning;
var localized string strIncompatibleWarningDetails;

var localized string strTrapMessage;
var localized string strDialogAccept;
var localized string strTacticalMessageTitle;


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

	SinceLastTick = 0;
	TickLink = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');

	bBlockDeathLink = false;
	bDeathTickLoop = false;
	DeathTickLink = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');

	NumStrategyObjectives = 0;

	CheckBuffer = class'XComGameState_APStore'.static.ReadCheckBuffer();

	TechCompletedType = "[TechCompleted]";
	PromotionType = "[Promotion]";
	CovertActionRewardType = "[CovertActionReward]";
	ResourceType = "[Resource]";
	StaffType = "[Staff]";
	TrapType = "[Trap]";

	bShowCustomPopup = false;
	CustomPopupTitle = "";
	CustomPopupText = "";
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
function OnCheckReached(name CheckName)
{
	local WOTCArchipelago_TcpLink Link;
	
	`AMLOG("Check reached: " $ CheckName);
	
	Link = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');
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

	if (!class'WOTCArchipelago_UISL_ShellSplash'.default.bAllowInvalidLaunch)
	{
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
	}

	AppendCheckBuffer(Link.GetCheckName());
	Link.Destroy();
}

private function AppendCheckBuffer(name CheckName)
{
	local XComGameState NewGameState;

	if (CheckBuffer.Find(CheckName) == INDEX_NONE)
	{
		CheckBuffer.AddItem(CheckName);

		// Update APStore CheckBuffer
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update APStore CheckBuffer");
		class'XComGameState_APStore'.static.WriteCheckBuffer(NewGameState, CheckBuffer);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

private function ClearCheckBuffer()
{
	local XComGameState		NewGameState;
	local bool				bModified;

	bModified = CheckBuffer.Length > 0;

	while (CheckBuffer.Length > 0)
	{
		OnCheckReached(CheckBuffer[0]);
		CheckBuffer.Remove(0, 1);

	}

	if (bModified)
	{
		// Update APStore CheckBuffer
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update APStore CheckBuffer");
		class'XComGameState_APStore'.static.WriteCheckBuffer(NewGameState, CheckBuffer);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}


//=======================================================================================
//                                       HINT
//---------------------------------------------------------------------------------------

function CreateServerHint(name CheckName)
{
	local WOTCArchipelago_TcpLink Link;
	
	`AMLOG("Hint created: " $ CheckName);
	
	Link = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');
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
//                                     DEATHLINK
//---------------------------------------------------------------------------------------

function SendDeath(string DeathText)
{
	local WOTCArchipelago_TcpLink Link;

	if (!`APCFG(DEATHLINK) || bBlockDeathLink) return;
	
	`AMLOG("DeathLink triggered with cause: " $ DeathText);
	
	Link = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');
	Link.Call("/Death/" $ class'WOTCArchipelago_Utilities'.static.EscapeURL(DeathText), DeathResponseHandler, DeathErrorHandler);
}

private function DeathResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	Link.Destroy();
}

private function DeathErrorHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	`AMLOG("Death Error Status: " $ Resp.ResponseCode);
	Link.Destroy();
}

function StartDeathTickLoop()
{
	if (bDeathTickLoop) return;
	bDeathTickLoop = true;
	DeathTick();
}

private function DeathTick()
{
	if (!bDeathTickLoop) return;
	DeathTickLink.Call("/DeathTick/" $ `APCFG(DEATHLINK), DeathTickResponseHandler, DeathTickErrorHandler);
}

private function DeathTickResponseHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local array<StateObjectReference>		DeathLinkTargets;
	local XComGameStateContext_DeathLink	DeathLinkContext;

	if (`APCFG(DEATHLINK) && bDeathTickLoop)
	{
		// Execute DeathLink if cause exists
		if (Resp.Body != "")
		{
			`AMLOG("DeathLink received");

			// Compile all valid DeathLink targets
			foreach `XCOMHQ.Squad(UnitRef)
			{
				if (UnitRef.ObjectID != 0)
				{
					UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
					if (UnitState.IsAlive()) DeathLinkTargets.AddItem(UnitRef);
				}
			}

			if (DeathLinkTargets.Length == 0)
			{
				`AMLOG("No valid DeathLink targets!");
			}
			else
			{
				UnitRef = DeathLinkTargets[`SYNC_RAND(DeathLinkTargets.Length)];
				UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

				// Temporarily disable DeathLink before potentially killing unit
				bBlockDeathLink = true;

				DeathLinkContext = XComGameStateContext_DeathLink(class'XComGameStateContext_DeathLink'.static.CreateXComGameStateContext());
				DeathLinkContext.TargetUnit = UnitRef;
				DeathLinkContext.Cause = Resp.Body;

				// Roll DeathLink result
				if (`SYNC_FRAND() < `APCFG(DEATHLINK_CHANCE))
				{
					if (UnitState.IsPsionic()) DeathLinkContext.Result = eDeathLinkResult_Parry;
					else DeathLinkContext.Result = eDeathLinkResult_Hit;
				}
				else DeathLinkContext.Result = eDeathLinkResult_Miss;

				`GAMERULES.SubmitGameStateContext(DeathLinkContext);

				// Re-enable DeathLink
				bBlockDeathLink = false;
			}
		}
	}

	DeathTick();
}

private function DeathTickErrorHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	if (class'WOTCArchipelago_UISL_ShellSplash'.default.bAllowInvalidLaunch) bDeathTickLoop = false;
	else `AMLOG("DeathTick Error Status: " $ Resp.ResponseCode);

	Link.Destroy();
	DeathTickLink = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');
	DeathTick();
}

function CancelDeathTickLoop()
{
	`AMLOG("Cancelling DeathTick loop");
	bDeathTickLoop = false;
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
	local array<StateObjectReference> CurrentStrategyObjectives;

	// Handle custom popup (RaiseDialog internally creates a new GameState,
	// so this is useful in case a pending GameState already exists when the popup is created)
	if (bShowCustomPopup)
	{
		RaiseDialog(CustomPopupTitle, CustomPopupText);
		bShowCustomPopup = false;
	}

	// Only check strategy objectives for completion if they were updated since last time
	CurrentStrategyObjectives = class'XComGameState_HeadquartersXCom'.static.GetCompletedAndActiveStrategyObjectives();
	if (NumStrategyObjectives != CurrentStrategyObjectives.Length)
	{
		HandleObjectiveCompletion();
		NumStrategyObjectives = CurrentStrategyObjectives.Length;
	}

	HandleStrongholdUnlock();
	HandleReplaceFactionHero();
	HandleRanksanityPromotions();
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

	// HACK: Trigger ResearchCompleted event to complete sequence broken objectives (including final Avatar Autopsy objective)
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("HACK: Trigger ResearchCompleted event for sequence breaks");
	`XEVENTMGR.TriggerEvent('ResearchCompleted', , , NewGameState);
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
	local XComGameStateHistory	History;
	local StateObjectReference	UnitRef;
	local XComGameState_Unit	UnitState;
	local bool					bLocalGameState;

	if (!class'WOTCArchipelago_Ranksanity'.default.bEnableRanksanity) return;

	History = `XCOMHISTORY;

	bLocalGameState = false;
	if (NewGameState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Handle ranksanity promotions and location checks");
		bLocalGameState = true;
	}
	
	foreach `XCOMHQ.Crew(UnitRef)
	{
		// Filter non-soldier units and disabled soldier classes
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (!UnitState.IsSoldier()) continue;
		if (!class'WOTCArchipelago_Ranksanity'.static.IsEnabled(UnitState.GetSoldierClassTemplateName())) continue;
		
		// Grant missing promotions (from received rank items)
		class'WOTCArchipelago_Ranksanity'.static.GrantMissingPromotions(NewGameState, UnitRef);

		// Send missing rank checks (determine reached rank from total kills, can be triggered by promotions above)
		class'WOTCArchipelago_Ranksanity'.static.SendMissingChecks(NewGameState, UnitRef);
	}

	if (bLocalGameState)
	{
		// Only submit NewGameState if something actually changed
		if (NewGameState.GetNumGameStateObjects() > 0)
			`GAMERULES.SubmitGameState(NewGameState);
		else
			History.CleanupPendingGameState(NewGameState);
	}
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

	// Repeat tick in case of surplus messages to make sure
	// all items are received on the first possible turn
	if (NumMessages < Messages.Length) SendTick();

	ClearCheckBuffer();
}

private function TickErrorHandler(WOTCArchipelago_TcpLink Link, HttpResponse Resp)
{
	if (!class'WOTCArchipelago_UISL_ShellSplash'.default.bAllowInvalidLaunch)
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
	}

	Link.Destroy();
	TickLink = `XCOMGAME.Spawn(class'WOTCArchipelago_TcpLink');
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
		`GAMERULES.SubmitGameState(NewGameState);
		HandleObjectiveCompletion();  // Complete sequence broken objectives (and check for campaign completion requirements)
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
		ItemValue = ItemData.Length >= 2 ? int(ItemData[1]) : 1;

		TriggerTrap(ItemName, ItemValue);
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

static function TriggerTrap(name TrapName, optional int Value = 1)
{
	local bool										bDayOne;
	local bool										bTurnOne;
	local XComGameState								NewGameState;
	local XComGameState_HeadquartersAlien			AlienHQ;
	local int										StartingForceLevel;
	local int										MaxForceLevel;
	local XComGameState_BlackMarket					BlackMarket;
	local int										Idx;
	local XComGameStateContext_ReinforcementTrap	ReinforcementTrapContext;
	local XComGameStateContext_NoAmmoTrap			NoAmmoTrapContext;
	local int										MaxPanickingUnits;
	local StateObjectReference						UnitRef;
	local XComGameState_Unit						UnitState;
	local XComGameStateContext_WillRoll				WillRollContext;
	local XComGameStateContext_EarthquakeTrap		EarthquakeTrapContext;

	bDayOne = class'X2StrategyGameRulesetDataStructures'.static.IsFirstDay(class'XComGameState_GeoscapeEntity'.static.GetCurrentTime());

	// Ignore all
	if (`APCFG(NO_TRAPS))
	{
		`AMLOG("Ignored trap: " $ TrapName $ " x" $ Value);
		return;
	}

	// Ignore on first day (strategy)
	if (`HQPRES != none)
	{
		if (bDayOne && `APCFG(NO_DAY_ONE_TRAPS))
		{
			`AMLOG("Ignored day one trap: " $ TrapName $ " x" $ Value);
			return;
		}
	}
	// Ignore on first turn (tactical)
	else
	{
		bTurnOne = class'XComGameState_ChallengeData'.static.CalcCurrentTurnNumber() == 1;
		if (bTurnOne && (`APCFG(NO_TURN_ONE_TRAPS) || (bDayOne && `APCFG(NO_DAY_ONE_TRAPS))))
		{
			`AMLOG("Ignored turn one trap: " $ TrapName $ " x" $ Value);
			return;
		}
	}

	// Doom
	if (TrapName == 'Doom')
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger doom trap");
		AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
		AlienHQ = XComGameState_HeadquartersAlien(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));

		`HQPRES.StrategyMap2D.StrategyMapHUD.SetDoomMessage(default.strTrapMessage, false, false);
		AlienHQ.ModifyDoom(Value);

		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Force Level
	else if (TrapName == 'ForceLevel')
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger force level trap");
		AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
		AlienHQ = XComGameState_HeadquartersAlien(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));

		StartingForceLevel = class'XComGameState_HeadquartersAlien'.default.AlienHeadquarters_StartingForceLevel;
		MaxForceLevel = class'XComGameState_HeadquartersAlien'.default.AlienHeadquarters_MaxForceLevel;
		AlienHQ.ForceLevel = Clamp(AlienHQ.ForceLevel + Value, StartingForceLevel, MaxForceLevel);

		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Hide Black Market
	else if (TrapName == 'HideBlackMarket')
	{
		BlackMarket = XComGameState_BlackMarket(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));
		if (!BlackMarket.bIsOpen && !BlackMarket.bNeedsScan)
		{
			`AMLOG("Ignored HideBlackMarket trap because black market is closed");
			return;
		}

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger hide black market trap");
		BlackMarket = XComGameState_BlackMarket(NewGameState.ModifyStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));

		if (BlackMarket.bNeedsScan)
		{
			BlackMarket.AddScanDays(Value);
			BlackMarket.bNeedsAppearedPopup = true;
		}
		else
		{
			BlackMarket.bIsOpen = false;
			BlackMarket.bNeedsScan = true;
			BlackMarket.bNeedsAppearedPopup = true;
			BlackMarket.ResetScan();
		}

		`GAMERULES.SubmitGameState(NewGameState);
	}
	// Yap Central
	else if (TrapName == 'YapCentral')
	{
		for (Idx = 0; Idx < Value; Idx++)
		{
			`HQPRES.UINarrative(XComNarrativeMoment'X2NarrativeMoments.S_Setup_Phase_Fortress_Adds_Doom_Central');
		}
	}
	// ADVENT Reinforcement
	else if (TrapName == 'AdventReinforcement')
	{
		ReinforcementTrapContext = XComGameStateContext_ReinforcementTrap(class'XComGameStateContext_ReinforcementTrap'.static.CreateXComGameStateContext());
		ReinforcementTrapContext.EncounterID = default.AdventReinforcementEncounters[`SYNC_RAND_STATIC(default.AdventReinforcementEncounters.Length)];
		`GAMERULES.SubmitGameStateContext(ReinforcementTrapContext);
	}
	// Alien Reinforcement
	else if (TrapName == 'AlienReinforcement')
	{
		ReinforcementTrapContext = XComGameStateContext_ReinforcementTrap(class'XComGameStateContext_ReinforcementTrap'.static.CreateXComGameStateContext());
		ReinforcementTrapContext.EncounterID = default.AlienReinforcementEncounters[`SYNC_RAND_STATIC(default.AlienReinforcementEncounters.Length)];
		`GAMERULES.SubmitGameStateContext(ReinforcementTrapContext);
	}
	// No Ammo
	else if (TrapName == 'NoAmmo')
	{
		NoAmmoTrapContext = XComGameStateContext_NoAmmoTrap(class'XComGameStateContext_NoAmmoTrap'.static.CreateXComGameStateContext());
		`GAMERULES.SubmitGameStateContext(NoAmmoTrapContext);
	}
	// Mass Panic
	else if (TrapName == 'MassPanic')
	{
		// Temporarily ignore MAX_PANICKING_UNITS
		MaxPanickingUnits = class'X2StatusEffects'.default.MAX_PANICKING_UNITS;
		if (default.bIgnoreMaxPanickingUnits) class'X2StatusEffects'.default.MAX_PANICKING_UNITS = 999;

		foreach `XCOMHQ.Squad(UnitRef)
		{
			if (UnitRef.ObjectID == 0) continue;
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
			if (UnitState == none) continue;

			WillRollContext = class'XComGameStateContext_WillRoll'.static.CreateWillRollContext(UnitState, 'APTrap', default.strTrapMessage, true);
			WillRollContext.DoWillRoll(default.MassPanicWillRollData);
			WillRollContext.Submit();
		}

		// Restore default MAX_PANICKING_UNITS
		class'X2StatusEffects'.default.MAX_PANICKING_UNITS = MaxPanickingUnits;
	}
	// Earthquake
	else if (TrapName == 'Earthquake')
	{
		EarthquakeTrapContext = XComGameStateContext_EarthquakeTrap(class'XComGameStateContext_EarthquakeTrap'.static.CreateXComGameStateContext());
		EarthquakeTrapContext.Magnitude = `SYNC_RAND_STATIC(default.MaxMagnitude) + 1;
		`AMLOG("Magnitude " $ EarthquakeTrapContext.Magnitude);

		foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if (UnitState.ObjectID == 0) continue;
			if (UnitState.IsDead() || UnitState.IsIncapacitated()) continue;
			if (UnitState.IsImmuneToDamage(class'X2Item_DefaultDamageTypes'.default.KnockbackDamageType)) continue;
			if (UnitState.GetMyTemplate().bCanUse_eTraversal_Flying) continue;
			if (UnitState.UnitSize > 1) continue;

			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitState.ObjectID));
			if (UnitState == none) continue;

			UnitRef = UnitState.GetReference();
			EarthquakeTrapContext.AffectedUnits.AddItem(UnitRef);
			if (UnitState.GetTeam() == eTeam_XCom) EarthquakeTrapContext.LookAtUnits.AddItem(UnitRef);
		}

		`GAMERULES.SubmitGameStateContext(EarthquakeTrapContext);
	}
	else
	{
		`AMLOG("Failed to trigger unrecognized trap: " $ TrapName);
		return;
	}

	`AMLOG("Triggered trap: " $ TrapName $ " x" $ Value);
}


//=======================================================================================
//                                      DIALOG
//---------------------------------------------------------------------------------------

// `HQPRES.UIRaiseDialog internally creates a new GameState to pause time in the geoscape,
// the APClient offers the ability to display custom popups (in DoChores) to circumvent this
function RegisterCustomPopup(string Title, string Text)
{
	CustomPopupTitle = Title;
	CustomPopupText = Text;
	bShowCustomPopup = true;
}

private static function RaiseDialog(string Title, string Text)
{
	local TDialogueBoxData						kDialogData;
	local XComGameStateContext_TacticalMessage	TacticalMessageContext;

	// "None" signals to skip dialog box
	if (Title == "None") return;
	if (Text == "None") return;

	if (`HQPRES != none)
	{
		kDialogData.eType = eDialog_Normal;
		kDialogData.strTitle = Title;
		kDialogData.strText = Text;
		kDialogData.strAccept = default.strDialogAccept;

		`HQPRES.UIRaiseDialog(kDialogData);
	}
	else
	{
		TacticalMessageContext = XComGameStateContext_TacticalMessage(class'XComGameStateContext_TacticalMessage'.static.CreateXComGameStateContext());
		TacticalMessageContext.Title = default.strTacticalMessageTitle;
		TacticalMessageContext.Message1 = Title;
		TacticalMessageContext.Message2 = Text;
		TacticalMessageContext.MessageColor = eUIState_Normal;
		`GAMERULES.SubmitGameStateContext(TacticalMessageContext);
	}
}
