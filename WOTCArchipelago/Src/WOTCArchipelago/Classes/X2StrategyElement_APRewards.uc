class X2StrategyElement_APRewards extends X2StrategyElement_XpackRewards;

var localized string strAPChosenHuntReward;
var localized string strAPChosenHuntRewardPreview;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Rewards;

	// Chosen Hunt Covert Action Replacement Reward
	Rewards.AddItem(CreateAPChosenHuntRewardTemplate());

	return Rewards;
}

static function X2DataTemplate CreateAPChosenHuntRewardTemplate()
{
	local X2RewardTemplate Template;

	`CREATE_X2Reward_TEMPLATE(Template, 'Reward_APChosenHunt');

	Template.IsRewardAvailableFn = IsAPChosenHuntRewardAvailable;
	Template.GiveRewardFn = GiveAPChosenHuntReward;
	Template.GetRewardStringFn = GetAPChosenHuntRewardString;
	Template.GetRewardPreviewStringFn = GetAPChosenHuntRewardPreviewString;

	return Template;
}

static function bool IsAPChosenHuntRewardAvailable(optional XComGameState NewGameState, optional StateObjectReference AuxRef)
{
	local XComGameState_ResistanceFaction	FactionState;
	local XComGameState_AdventChosen		ChosenState;

	FactionState = GetFactionState(NewGameState, AuxRef);
	if (FactionState != none)
	{
		ChosenState = FactionState.GetRivalChosen();
		if (FactionState.bMetXCom && ChosenState.bMetXCom) return true;
	}

	return false;
}

static function GiveAPChosenHuntReward(XComGameState NewGameState, XComGameState_Reward RewardState, optional StateObjectReference AuxRef, optional bool bOrder = false, optional int OrderHours = -1)
{
	local XComGameState_CovertAction	CovertActionState;
	local int							Count;

	CovertActionState = XComGameState_CovertAction(`XCOMHISTORY.GetGameStateForObjectID(AuxRef.ObjectID));

	switch (CovertActionState.GetMyTemplateName())
	{
		case 'CovertAction_RevealChosenMovements':
			Count = `APCTRINC('ChosenHuntPt1Checked', NewGameState);
			`APCLIENT.OnCheckReached(NewGameState, name("ChosenHuntPt1:" $ Count));
			break;
		case 'CovertAction_RevealChosenStrengths':
			Count = `APCTRINC('ChosenHuntPt2Checked', NewGameState);
			`APCLIENT.OnCheckReached(NewGameState, name("ChosenHuntPt2:" $ Count));
			break;
		case 'CovertAction_RevealChosenStronghold':
			Count = `APCTRINC('ChosenHuntPt3Checked', NewGameState);
			`APCLIENT.OnCheckReached(NewGameState, name("ChosenHuntPt3:" $ Count));
			break;
	}
}

static function string GetAPChosenHuntRewardString(XComGameState_Reward RewardState)
{
	return default.strAPChosenHuntReward;
}

static function string GetAPChosenHuntRewardPreviewString(XComGameState_Reward RewardState)
{
	return default.strAPChosenHuntRewardPreview;
}
