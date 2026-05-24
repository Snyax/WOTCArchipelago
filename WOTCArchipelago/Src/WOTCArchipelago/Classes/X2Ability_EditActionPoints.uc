class X2Ability_EditActionPoints extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateTurnStartActionPointAbility('AddActionPoint', 1));
	Templates.AddItem(CreateTurnStartActionPointAbility('RemoveActionPoint', -1));
	Templates.AddItem(CreateNeverConsumeAllPointsAbility());

	return Templates;
}

private static function X2DataTemplate CreateTurnStartActionPointAbility(name TemplateName, int NumActionPoints)
{
	local X2AbilityTemplate						Template;
	local X2AbilityTrigger_UnitPostBeginPlay	Trigger;
	local X2Effect_TurnStartActionPoints		TSAPEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	Template.bDontDisplayInAbilitySummary = true;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;

	Trigger = new class'X2AbilityTrigger_UnitPostBeginPlay';
	Template.AbilityTriggers.AddItem(Trigger);

	TSAPEffect = new class'X2Effect_TurnStartActionPoints';
	TSAPEffect.ActionPointType = class'X2CharacterTemplateManager'.default.StandardActionPoint;
	TSAPEffect.NumActionPoints = Abs(NumActionPoints);
	TSAPEffect.bActionPointsRemoved = NumActionPoints < 0;
	TSAPEffect.bInfiniteDuration = true;
	Template.AddTargetEffect(TSAPEffect);
	
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

private static function X2DataTemplate CreateNeverConsumeAllPointsAbility()
{
	local X2AbilityTemplate						Template;
	local X2AbilityTrigger_UnitPostBeginPlay	Trigger;
	local X2Effect_Persistent					DNCAPEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'NeverConsumeAllPoints');

	Template.bDontDisplayInAbilitySummary = true;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;

	Trigger = new class'X2AbilityTrigger_UnitPostBeginPlay';
	Template.AbilityTriggers.AddItem(Trigger);

	DNCAPEffect = new class'X2Effect_Persistent';
	DNCAPEffect.EffectName = 'DoNotConsumeAllPoints';
	DNCAPEffect.DuplicateResponse = eDupe_Ignore;
	DNCAPEffect.BuildPersistentEffect(1, true, true);
	DNCAPEffect.SetDisplayInfo(ePerkBuff_Passive, "", "", "", false);
	DNCAPEffect.bRemoveWhenTargetDies = true;
	Template.AddTargetEffect(DNCAPEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}
