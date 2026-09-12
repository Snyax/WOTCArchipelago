// Helper class for accessing debug values
class WOTCArchipelago_Defaults extends Object config(WOTCArchipelago);

// Unique AP generation ID set by the client
var config string DEF_AP_GEN_ID;

// Enable debug logging to /Documents/My Games/XCOM2 War of the Chosen/XComGame/Logs/Launch.log
var config bool DEF_DEBUG_LOGGING;

// Hint research projects
var config bool DEF_HINT_TECH_LOC_PART;
var config bool DEF_HINT_TECH_LOC_FULL;

// Skip certain time-consuming missions
var config bool DEF_SKIP_SUPPLY_RAIDS;
var config bool DEF_SKIP_COUNCIL_MISSIONS;
var config bool DEF_SKIP_FACTION_MISSIONS;

// Disable certain time-consuming covert op risks
var config bool DEF_DISABLE_AMBUSH_RISK;
var config bool DEF_DISABLE_CAPTURE_RISK;

// Skipped supply raid rewards
var config float DEF_SKIP_RAID_REWARD_MULT_BASE;
var config float DEF_SKIP_RAID_REWARD_MULT_ERR;

// Increase XP/corpse gain
var config float DEF_EXTRA_XP_MULT;
var config int DEF_EXTRA_CORPSES;

// DeathLink
var config bool DEF_DEATHLINK;
var config float DEF_DEATHLINK_CHANCE;

// Improve access to soldiers
var config bool DEF_INSTANT_ROOKIE_TRAINING;
var config bool DEF_INSTANT_SPARK_BUILDING;
var config bool DEF_REFUND_SPARK_COST;
var config bool DEF_REPLACE_FACTION_HERO;

// Disable traps
var config bool DEF_NO_TRAPS;
var config bool DEF_NO_DAY_ONE_TRAPS;
var config bool DEF_NO_TURN_ONE_TRAPS;

// MCM version
var config int DEF_VERSION;
