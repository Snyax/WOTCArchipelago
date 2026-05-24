class X2Item_ResearchCompleted extends X2Item config(WOTCArchipelago);

struct native ResearchProject
{
	var name TechName;
	var name CompletionItemName;
};

var config array<ResearchProject> CheckCompleteTechs;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate>		CompletionItems;
	local ResearchProject			Project;
	local name						CompletionItemName;

	foreach default.CheckCompleteTechs(Project)
	{
		CompletionItemName = Project.CompletionItemName;
		if (CompletionItemName == '')
			CompletionItemName = name(string(Project.TechName) $ "Completed");

		CompletionItems.AddItem(CreateResearchCompletedTemplate(CompletionItemName, Project.TechName));
	}

	return CompletionItems;
}

private static function X2DataTemplate CreateResearchCompletedTemplate(name CompletionItemName, name TechTemplateName)
{
	local X2CompletionItemTemplate Template;

	`CREATE_X2TEMPLATE(class'X2CompletionItemTemplate', Template, CompletionItemName);

	Template.ItemCat = 'goldenpath';
	
	Template.AssociatedClass = class'X2TechTemplate';
	Template.AssociatedTemplateName = TechTemplateName;

	Template.OnAcquiredFn = CallTechDelegate;

	return Template;
}

static function bool CallTechDelegate(XComGameState NewGameState, XComGameState_Item ItemState)
{
	local X2ItemTemplate				ItemTemplate;
	local X2CompletionItemTemplate		CompletionItemTemplate;
	local name							AssociatedTemplateName;
	local XComGameState_Tech			TechState;

	ItemTemplate = ItemState.GetMyTemplate();

	if (!ClassIsChildOf(ItemTemplate.Class, class'X2CompletionItemTemplate'))
	{
		`ERROR("Wrong type for " $ ItemTemplate.DataName);
		return false;
	}

	CompletionItemTemplate = X2CompletionItemTemplate(ItemTemplate);
	AssociatedTemplateName = CompletionItemTemplate.AssociatedTemplateName;
	
	// Find Associated TechState
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Tech', TechState)
	{
		if (TechState.GetMyTemplateName() == AssociatedTemplateName) break;
	}

	if (TechState == none || TechState.GetMyTemplateName() != AssociatedTemplateName)
	{
		`ERROR("No TechState for " $ AssociatedTemplateName);
		return false;
	}

	// Call Associated TechDelegate
	CompletionItemTemplate.AssociatedTechDelegate(NewGameState, TechState);

	`AMLOG("Called Tech Delegate for " $ CompletionItemTemplate.DataName);
	return true;
}
