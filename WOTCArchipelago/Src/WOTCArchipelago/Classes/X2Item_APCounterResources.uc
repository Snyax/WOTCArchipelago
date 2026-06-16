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
	APCounterItems.AddItem(CreateCounterTemplate('ChosenHuntPt1Checked'));
	APCounterItems.AddItem(CreateCounterTemplate('ChosenHuntPt2Checked'));
	APCounterItems.AddItem(CreateCounterTemplate('ChosenHuntPt3Checked'));

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
