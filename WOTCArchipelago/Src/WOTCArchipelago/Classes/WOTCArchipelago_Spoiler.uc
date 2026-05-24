class WOTCArchipelago_Spoiler extends Object config(WOTCArchipelago_Spoiler);

struct native SpoilerEntry
{
	var name Location;
	var string Item;
	var string Player;
	var string Game;
	var bool bProgression;
	var bool bUseful;
	var bool bTrap;
};

struct native EnemyRandoEntry
{
	var name DefaultTemplateName;
	var name OverrideTemplateName;
};

struct native CharStatChange
{
	var name TemplateName;
	var ECharStatType StatType;
	var float Delta;
	var float Minimum;
	var float Maximum;
};

var config array<SpoilerEntry>		Spoiler;
var config array<EnemyRandoEntry>	EnemyRando;
var config array<CharStatChange>	CharStatChanges;

static function bool GetSpoilerEntryByLocation(name LocationName, out SpoilerEntry Entry)
{
	foreach default.Spoiler(Entry)
		if (Entry.Location == LocationName)
			return true;

	return false;
}

static function bool IsChosenHuntsanityActive()
{
	local SpoilerEntry Entry;

	return GetSpoilerEntryByLocation(name("ChosenHuntPt1:1"), Entry);
}

static function bool IsEnemyRandoActive()
{
	return (default.EnemyRando.Length > 0);
}

static function bool IsEnemyShuffled(name TemplateName)
{
	local EnemyRandoEntry Entry;

	foreach default.EnemyRando(Entry)
	{
		if (Entry.OverrideTemplateName == TemplateName)
			return true;
	}

	return false;
}

static function bool ApplyEnemyRando(out name TemplateName)
{
	local EnemyRandoEntry Entry;

	foreach default.EnemyRando(Entry)
	{
		if (Entry.DefaultTemplateName == TemplateName)
		{
			TemplateName = Entry.OverrideTemplateName;
			return true;
		}
	}

	return false;
}
