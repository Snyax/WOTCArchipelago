class X2Item_APCounterResources extends X2Item;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate>		APCounterItems;
	local array<name>				RanksanitySoldierClasses;
	local name						SoldierClass;

	// Items Received
	APCounterItems.AddItem(CreateCounterTemplate('ItemsReceivedStrategy'));
	APCounterItems.AddItem(CreateCounterTemplate('ItemsReceivedTactical'));

	// Chosen Hunt Covert Actions Checked
	APCounterItems.AddItem(CreateCounterTemplate('ReaperChosenHuntChecked'));
	APCounterItems.AddItem(CreateCounterTemplate('SkirmisherChosenHuntChecked'));
	APCounterItems.AddItem(CreateCounterTemplate('TemplarChosenHuntChecked'));

	// Chosen Stronghold Unlocks Received
	APCounterItems.AddItem(CreateCounterTemplate('AssassinStrongholdReceived'));
	APCounterItems.AddItem(CreateCounterTemplate('HunterStrongholdReceived'));
	APCounterItems.AddItem(CreateCounterTemplate('WarlockStrongholdReceived'));

	// Chosen Defeated
	APCounterItems.AddItem(CreateCounterTemplate('ChosenDefeated'));

	// Story Objectives Completed
	APCounterItems.AddItem(CreateCounterTemplate('PsiGateObjectiveCompleted'));
	APCounterItems.AddItem(CreateCounterTemplate('StasisSuitObjectiveCompleted'));
	APCounterItems.AddItem(CreateCounterTemplate('AvatarCorpseObjectiveCompleted'));

	// Ranksanity Promotions Sent/Received
	RanksanitySoldierClasses = class'WOTCArchipelago_Ranksanity'.static.GetEnabledSoldierClasses();
	foreach RanksanitySoldierClasses(SoldierClass)
	{
		APCounterItems.AddItem(CreateCounterTemplate(GetRankSentCounterName(SoldierClass)));
		APCounterItems.AddItem(CreateCounterTemplate(GetRankReceivedCounterName(SoldierClass)));
	}

	return APCounterItems;
}

// Count chosen hunt covert ops completed by each faction
static function CountChosenHuntCompleted(out int NumReaperChosenHuntCompleted, out int NumSkirmisherChosenHuntCompleted, out int NumTemplarChosenHuntCompleted, optional XComGameState NewGameState)
{
	local XComGameState_ResistanceFaction	FactionState;
	local array<name>						ChosenHuntNameList;
	local name								ChosenHuntName;

	ChosenHuntNameList.AddItem('CovertAction_RevealChosenMovements');
	ChosenHuntNameList.AddItem('CovertAction_RevealChosenStrengths');
	ChosenHuntNameList.AddItem('CovertAction_RevealChosenStronghold');

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		if (NewGameState != none)
			FactionState = XComGameState_ResistanceFaction(NewGameState.GetGameStateForObjectID(FactionState.ObjectID));

		foreach ChosenHuntNameList(ChosenHuntName)
		{
			if (FactionState.CompletedCovertActions.Find(ChosenHuntName) != INDEX_NONE)
			{
				if (FactionState.GetMyTemplateName() == 'Faction_Reapers') NumReaperChosenHuntCompleted += 1;
				if (FactionState.GetMyTemplateName() == 'Faction_Skirmishers') NumSkirmisherChosenHuntCompleted += 1;
				if (FactionState.GetMyTemplateName() == 'Faction_Templars') NumTemplarChosenHuntCompleted += 1;
			}
		}
	}
}

// Get faction of most recently completed (and not checked) chosen hunt covert op
static function GetRecentCompletedChosenHuntFaction(out XComGameState_ResistanceFaction FactionState, out name CheckedCounterName, optional XComGameState NewGameState)
{
	local int NumReaperChosenHuntCompleted;
	local int NumSkirmisherChosenHuntCompleted;
	local int NumTemplarChosenHuntCompleted;

	CountChosenHuntCompleted(NumReaperChosenHuntCompleted, NumSkirmisherChosenHuntCompleted, NumTemplarChosenHuntCompleted, NewGameState);

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_ResistanceFaction', FactionState)
	{
		switch (FactionState.GetMyTemplateName())
		{
			case 'Faction_Reapers':
				CheckedCounterName = 'ReaperChosenHuntChecked';
				if (`APCTRREAD(CheckedCounterName, NewGameState) < NumReaperChosenHuntCompleted) return;
				break;
			case 'Faction_Skirmishers':
				CheckedCounterName = 'SkirmisherChosenHuntChecked';
				if (`APCTRREAD(CheckedCounterName, NewGameState) < NumSkirmisherChosenHuntCompleted) return;
				break;
			case 'Faction_Templars':
				CheckedCounterName = 'TemplarChosenHuntChecked';
				if (`APCTRREAD(CheckedCounterName, NewGameState) < NumTemplarChosenHuntCompleted) return;
				break;
		}
	}

	// No chosen hunt covert action
	FactionState = none;
}

static function name GetRankSentCounterName(name SoldierClass)
{
	return name("RankSent" $ SoldierClass);
}

static function name GetRankReceivedCounterName(name SoldierClass)
{
	return name("RankReceived" $ SoldierClass);
}

private static function X2DataTemplate CreateCounterTemplate(name TemplateName)
{
	local X2ItemTemplate Template;

	`CREATE_X2TEMPLATE(class'X2ItemTemplate', Template, TemplateName);
	Template.CanBeBuilt = false;
	Template.HideInInventory = true;
	Template.ItemCat = 'resource';

	return Template;
}
