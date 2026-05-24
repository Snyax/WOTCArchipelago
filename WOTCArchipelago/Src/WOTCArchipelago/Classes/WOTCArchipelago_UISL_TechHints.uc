class WOTCArchipelago_UISL_TechHints extends UIScreenListener;

var localized string strItemPrefix;
var localized string strPlayerPrefix;

var localized string strClassProgression;
var localized string strClassUseful;
var localized string strClassTrap;
var localized string strClassNormal;

var localized array<string> arrProgressionHints;
var localized array<string> arrUsefulHints;
var localized array<string> arrTrapHints;
var localized array<string> arrNormalHints;

var localized string strNoHint;

event OnInit(UIScreen Screen)
{
	if (UIChooseResearch(Screen) == none) return;
	HintResearchProjects(UIChooseResearch(Screen));
}

event OnReceiveFocus(UIScreen Screen)
{
	if (UIChooseResearch(Screen) == none) return;
	HintResearchProjects(UIChooseResearch(Screen));
}

private function HintResearchProjects(UIChooseResearch ResearchScreen)
{
	local int				Idx;
	local X2TechTemplate	TechTemplate;
	local SpoilerEntry		TechSpoiler;
	local XComGameState		NewGameState;

	local string			strClass;
	local string			strItem;
	local string			strPlayer;
	local string			strHint;

	for (Idx = 0; Idx < Min(ResearchScreen.arrItems.Length, ResearchScreen.m_arrRefs.Length); Idx++)
	{
		TechTemplate = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(ResearchScreen.m_arrRefs[Idx].ObjectID)).GetMyTemplate();
		if (!class'WOTCArchipelago_Spoiler'.static.GetSpoilerEntryByLocation(TechTemplate.DataName, TechSpoiler)) continue;

		strItem = default.strItemPrefix $ "???";
		strPlayer = default.strPlayerPrefix $ "???";

		// Hint everything
		if (`APCFG(HINT_TECH_LOC_FULL))
		{
			if (TechSpoiler.bProgression) strClass = default.strClassProgression;
			else if (TechSpoiler.bUseful) strClass = default.strClassUseful;
			else if (TechSpoiler.bTrap) strClass = default.strClassTrap;
			else strClass = default.strClassNormal;

			strItem = default.strItemPrefix $ TechSpoiler.Item $ " (" $ strClass $ ")";
			strPlayer = default.strPlayerPrefix $ TechSpoiler.Player $ " (" $ TechSpoiler.Game $ ")";

			ResearchScreen.arrItems[Idx].Desc = strItem $ strPlayer;

			// Create server hint
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating server hint");
			`APCLIENT.CreateServerHint(NewGameState, TechTemplate.DataName);
			`GAMERULES.SubmitGameState(NewGameState);
		}
		// Hint classification
		else if (`APCFG(HINT_TECH_LOC_PART))
		{
			if (TechSpoiler.bProgression) strHint = static.GetClassHint(TechSpoiler.Item, default.arrProgressionHints);
			else if (TechSpoiler.bUseful) strHint = static.GetClassHint(TechSpoiler.Item, default.arrUsefulHints);
			else if (TechSpoiler.bTrap) strHint = static.GetClassHint(TechSpoiler.Item, default.arrTrapHints);
			else strHint = static.GetClassHint(TechSpoiler.Item, default.arrNormalHints);

			ResearchScreen.arrItems[Idx].Desc = strItem $ strPlayer $ "\n\n" $ strHint;
		}
		// Hint nothing
		else
		{
			ResearchScreen.arrItems[Idx].Desc = strItem $ strPlayer $ "\n\n" $ default.strNoHint;
		}
	}

	ResearchScreen.PopulateData();
}

// Get arbitrary but deterministic hint
private static function string GetClassHint(string strItem, array<string> arrClassHints)
{
	local int		Idx;
	local int		Res;
	local string	strChar;

	for (Idx = 0; Idx < Len(strItem); Idx++)
	{
		strChar = Mid(strItem, Idx, 1);

		if (strChar == "a" || strChar == "A") Res += 1;
		if (strChar == "b" || strChar == "B") Res += 2;
		if (strChar == "c" || strChar == "C") Res += 3;
		if (strChar == "d" || strChar == "D") Res += 4;
		if (strChar == "e" || strChar == "E") Res += 5;
		if (strChar == "f" || strChar == "F") Res += 6;
		if (strChar == "g" || strChar == "G") Res += 7;
		if (strChar == "h" || strChar == "H") Res += 8;
		if (strChar == "i" || strChar == "I") Res += 9;
		if (strChar == "j" || strChar == "J") Res += 10;
		if (strChar == "k" || strChar == "K") Res += 11;
		if (strChar == "l" || strChar == "L") Res += 12;
		if (strChar == "m" || strChar == "M") Res += 13;
		if (strChar == "n" || strChar == "N") Res += 14;
		if (strChar == "o" || strChar == "O") Res += 15;
		if (strChar == "p" || strChar == "P") Res += 16;
		if (strChar == "q" || strChar == "Q") Res += 17;
		if (strChar == "r" || strChar == "R") Res += 18;
		if (strChar == "s" || strChar == "S") Res += 19;
		if (strChar == "t" || strChar == "T") Res += 20;
		if (strChar == "u" || strChar == "U") Res += 21;
		if (strChar == "v" || strChar == "V") Res += 22;
		if (strChar == "w" || strChar == "W") Res += 23;
		if (strChar == "x" || strChar == "X") Res += 24;
		if (strChar == "y" || strChar == "Y") Res += 25;
		if (strChar == "z" || strChar == "Z") Res += 26;
	}

	return arrClassHints[Res % arrClassHints.Length];
}
