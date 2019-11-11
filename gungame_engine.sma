#include <amxmodx>
#include <colorchat>
#include <hamsandwich>
#include <fakemeta_util>
#include <cstrike>
#include <engine>
#include <sqlx>
#include <fun>

#define AUTHOR "aSior - amxx.pl/user/60210-asiorr/"


// Used in custom mapchooser.
native showMapVoteMenu();


#pragma semicolon 1
#pragma compress 1

// Uncomment if testmode should be enabled.
#define TEST_MODE

// Uncomment to provide amxx more detailed log_amx data when handling an error.
#define DEBUG_MODE

// Mainly used to create size of static arrays.
#define MAX_CHARS 33

// Used in loops and to determine static array sizes (+1).
#define MAX_PLAYERS 32

#define ForPlayers(%1) for(new %1 = 1; %1 <= MAX_PLAYERS; %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)
#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof %2; %1++)

// Handle name length.
#define printName(%1) (strlen(userName[%1]) > maxNicknameLength ? userShortName[%1] : userName[%1])

// Just for lookup command purposes, not actual VIP.
#define VIP_FLAG ADMIN_LEVEL_H

// Task indexes.
enum (+= 2500)
{
	TASK_RESPAWN = 1337,
	TASK_NOTIFY,
	TASK_DISPLAYHUD,

	TASK_GIVEGRENADE,
	TASK_REWARDWINNER,

	TASK_SPAWNPROTECTION,
	TASK_RESPAWN_ON_JOIN,
	TASK_IDLECHECK
};

// Enum for weaponsData array.
enum (+= 1)
{
	weaponCSW = 0,
	weaponKills,
	weaponDamage
};

// Main data array. [0] is weapon CSW_ index. [1] is kills required to level-up. [2] is damage multiplier (30 = 30%, 110 = 110%).
new const weaponsData[][] =
{
	{ CSW_GLOCK18, 2, 100 },
	{ CSW_USP, 2, 100 },
	{ CSW_P228, 2, 100 },

	{ CSW_FIVESEVEN, 2, 100 },
	{ CSW_DEAGLE, 2, 100 },
	{ CSW_ELITE, 2, 100 },
	
	{ CSW_M3, 3, 100 },
	{ CSW_XM1014, 3, 100 },
	{ CSW_TMP, 3, 100 },
	
	{ CSW_MAC10, 3, 100 },
	{ CSW_UMP45, 3, 100 },
	{ CSW_MP5NAVY, 3, 100 },
	
	{ CSW_P90, 4, 100 },
	{ CSW_GALIL, 4, 100 },
	{ CSW_FAMAS, 3, 100 },
	
	{ CSW_AK47, 4, 100 },
	{ CSW_SCOUT, 2, 100 },
	{ CSW_M4A1, 4, 100 },

	{ CSW_SG552, 4, 100 },
	{ CSW_AUG, 4, 100 },
	{ CSW_AWP, 4, 100 },

	{ CSW_G3SG1, 2, 100 },
	{ CSW_SG550, 2, 100 },
	{ CSW_M249, 2, 100 },

	{ CSW_HEGRENADE, 3, 100 },
	{ CSW_KNIFE, 1, 100 }
};

// Custom weapon names (used in HUD, ending-message etc).
new const customWeaponNames[][] =
{
	"Glock",
	"USP",
	"P228",

	"Five-seven",
	"Deagle",
	"Duals",
	
	"M3",
	"XM1014",
	"TMP",
	
	"Mac-10",
	"UMP",
	"MP5",
	
	"P90",
	"Galil",
	"Famas",
	
	"AK-47",
	"Scout",
	"M4A1",

	"SG-552",
	"AUG",
	"AWP",

	"Autokampa (TT)",
	"Autokampa (CT)",
	"M249",

	"Granat HE",
	"Noz"
};

// Commands to be blocked (using PLUGIN_HANDLED_MAIN).
new const blockedCommands[][] =
{
	"drop",
	"fullupdate",
	"radio1",

	"radio2",
	"radio3",
	"kill"
};

// Time in which player CAN get killed, but the killer will not be granted any weapon kills if victim is in spawn protection.
const Float:spawnProtectionTime = 1.5;

// RGB of colored shell (set_user_rendering) when in spawn protection.
new const spawnProtectionColors[] = { 80, 0, 0 };

// Shell thickness.
new const spawnProtectionShell = 100;

// Respawn time during GunGame.
const Float:respawnInterval = 3.0;	


// Default HE explode time.
const Float:defaultExplodeTime = 3.0;

// Modified HE explode time (set to defaultExplodeTime to disable).
new const Float:heGrenadeExplodeTime = 1.1;


// Hud objects enum.
enum (+= 1)
{
	hudObjectDefault = 0,
	hudObjectDamage,
	hudObjectWarmup
};

// HUD refresh time.
const Float:hudDisplayInterval = 1.0;

// HUD RGB colors.
new const hudColors[] = { 200, 130, 0 };


// Determines wheter to enable flashes on last level. Does not support wand.
new const bool:flashesEnabled = true;

// Time between giving a player next HE grenade (during warmup & on HE weapon level).
new const Float:giveBackHeInterval = 1.8;

// Time between giving a player next Flash grenade.
new const Float:giveBackFlashInterval = 4.5;


// Time of warmup in seconds.
new const warmupDuration = 120;

// Level that will be set to warmup winner. Value < 1 will disable notifications and picking warmup winner.
new const warmupLevelReward = 3;

// Health that players will be set to during warmup.
new const warmupHealth = 50;

// Set that to CSW_ index, -1 to get random weapon, -2 to get wands (ignoring wandEnabled value) or -3 to get random weapon for every player.
new const warmupWeapon = -3;

// Time to respawn player during warmup.
const Float:warumpRespawnInterval = 2.0;

// RGB colors of warmup HUD.
new const warmupHudColors[] = { 255, 255, 255 };


// Enable falldamage?
const bool:fallDamageEnabled = false;


// Refill weapon clip on kill?
new const bool:refillWeaponAmmo = true;

// Ammo indexes;
new const ammoAmounts[] =
{
	0, 13, -0,
	10, 1, 7,
	0, 30, 30,
	1, 30, 20,
	25, 30, 35,
	25, 12, 20,
	10, 30, 100,
	8, 30, 30,
	20, 2, 7,
	30, 30, 0,
	50
};


// Determines interval between AFK checks.
const Float:idleCheckInterval = 3.0;

// Hit power of a slap when player is 'AFK'.
new const idleSlapPower = 5;

// Determines max strikes that player can have before slaps start occuring.
new const idleMaxStrikes = 2;

// Distance that resets camping-player idle strikes.
new const idleMaxDistance = 80;


// Armor level for every player.
new const defaultArmorLevel = 0;

// Set that really high, so we dont have to worry about screen getting back to non-colored.
const Float:blackScreenTimer = 50.0;


// If that's set to true, knife will instantly give you knifeKillReward levels. Otherwise knifeKillReward means weapon kills.
new const knifeKillInstantLevelup = false;

// Knife kill reward value based on knifeKillInstantLevelup var.
new const knifeKillReward = 2;


// Determines whether you want last level weapon to be knife (false) or wand (true).
new const wandEnabled = false;

// Base weapon_* for wand.
new const wandBaseEntity[] = "weapon_knife";

// Wand primary attack sprite brightness.
new const wandAttackSpriteBrightness = 255;

// Wand primary attack sprite life.
new const wandAttackSpriteLife = 4;

// Wand primary attack max distance.
new const wandAttackMaxDistance = 550;

// Wand primary attack interval.
new const Float:wandAttackInterval = 2.2;

// Wand models [0] - V_ || [1] - P_.
new const wandModels[][] =
{
	"models/gungame/v_wand.mdl",
	"models/gungame/p_wand.mdl"
};

// Wand sounds enum.
enum (+= 1)
{
	wandSoundShoot
};

// Wand sounds.
new const wandSounds[][] =
{
	"testSounds/wandShoot.wav"
};

// Wand primary attack sprite RGB.
new const wandAttackSpriteColor[] =
{
	20,
	20,
	200
};

// Wand sprites enum.
enum (+= 1)
{
	wandSpriteAttack,
	wandSpriteExplodeOnHit,
	wandSpritePostHit,
	wandSpriteBlood
};

new const wandSprites[][] =
{
	"sprites/gungame/wandAttack.spr",
	"sprites/gungame/wandExplodeOnHit.spr",
	"sprites/gungame/wandPostHit.spr",
	"sprites/blood.spr"
};

// [0] - Damage || [1] - blood scale.
new const wandDamageEffects[][] =
{
	{ 0, 0 },		// None
	{ 90, 25 },		// Head
	{ 65, 15 },		// Chest
	{ 65, 15 },		// Chest
	{ 30, 10 },		// Hands
	{ 30, 10 },		// Hands
	{ 30, 10 },		// Legs
	{ 30, 10 }		// Legs
};


// Prefix shown in game-ending message and chat when leveling-up.
new const chatPrefix[] = "[GUN GAME]";


// String that will replace rest of the nickname when clumping it to the short one.
new const nicknameReplaceToken[] = "...";

// Max. name length in short-name variable (to prevent char-overflow in ending message). Ex: "pretty long nickname" -> "pretty lon".
const maxNicknameLength = 10 + charsmax(nicknameReplaceToken);


// Take damage hud hold-time.
const Float:takeDamageHudTime = 1.3;

// Take damage hud colors.
new const takeDamageHudColor[] = { 0, 200, 200 };


// Classnames of weapons on the ground (to prevent picking them up).
new const droppedWeaponsClassnames[][] =
{
	"weaponbox",
	"armoury_entity",
	"weapon_shield"
};


// Sound types.
enum (+= 1)
{
	soundLevelUp = 0,
	soundLevelDown,
	soundTimerTick,

	soundWarmup,
	soundAnnounceWinner,
	soundGameStart
};

// Command executed when playing sound on client. (mp3 play / spk)
new const defaultSoundCommand[] = "mp3 play";

// Number of maximum sounds in soundsData array.
new const maxSounds = 2;

// Main sound-data array. Every index is a different sound. Indexes with strlen == 0 will be continued, instead plugin will use first available index.
new const soundsData[][][] =
{
	{ "testSounds/levelup.wav", "" },
	{ "testSounds/leveldown.wav", "" },
	{ "testSounds/timertick4.wav", "" },

	{ "testSounds/warmup.wav", "" },
	{ "testSounds/announcewinner.wav", "" },
	{ "testSounds/gungamestart.wav", "testSounds/gungamestart2.wav" }
};

// Custom volumes of each sound.
new const Float:soundsVolumeData[][] =
{
	{ 1.0, 1.0 },	// Levelup
	{ 1.0, 1.0 },	// Leveldown
	{ 1.0, 1.0 },	// Timer tick

	{ 0.8, 1.0 },	// Warmup
	{ 1.0, 1.0 },	// Announce winner
	{ 1.0, 1.0 }	// Gungame start
};


// Sprites enum.
enum (+= 1)
{
	spriteLevelup = 0
};

// Sprite paths.
new const spritesData[][] =
{
	"sprites/levelupBeam.spr"
};

// Z axis.
new const Float:spriteLevelupZaxis = 200.0;

// Life.
new const spriteLevelupLife = 2;

// Width.
new const spriteLevelupWidth = 15;

// RGB.
new const spriteLevelupRGB[] = { 0, 255, 0 };

// Brightness.
new const spriteLevelupBrightness = 80;


// Remove weapons off the ground when loading map?
new const removeWeaponsOffTheGround = true;


new const gameCvars[][][] =
{
	{ "mp_round_infinite", "1" },
	{ "mp_autoteambalance", "0" },
	{ "mp_roundover", "0" },

	{ "mp_nadedrops", "0" },
	{ "mp_auto_reload_weapons", "1" },
	{ "mp_refill_bpammo_weapons", "3" },

	{ "mp_auto_join_team", "1" },
	{ "mp_hostage_hurtable", "0" },
	{ "mp_show_radioicon", "0" },

	{ "sv_alltalk", "1" },
	{ "mp_freeforall", "1" },
	{ "mp_autokick", "0" },

	{ "sv_airaccelerate", "30" },
	{ "sv_maxspeed", "999" }
};


// Player-info command (checked in sayHandle instead of register_clcmd to extract nickname from message).
new const lookupCommand[] = "/info";


// Commands to menu which lists weapons & their data.
new const listWeaponsCommands[][] =
{
	"/lista",
	"/listabroni",
	"/bronie",
	"/bron",
	"/guns"
};


// Mysql database enum.
enum databaseEnum (+= 1)
{
	databaseHost,
	databaseUser,
	databasePass,
	databaseDB,
	databaseTableName
};

// Mysql database.
new const mysqlData[][] =
{
	"",
	"",
	"",
	"",
	""
};


// Determines number of top-players that will be shown in game-ending message.
const topPlayersDisplayed = 10;

// Top players motd HTML code.
new const topPlayersMotdHTML[][] =
{
	"<style> body{ background: #202020 } tr{ text-align: left } table{ font-size: 12px; color: #ffffff; padding: 0px } h1{ color: #FFF; font-family: Verdana }</style><body>",
	"<table width = 100%% border = 0 align = center cellpadding = 0 cellspacing = 2>",
	"<tr><th><h3>Pozycja</h3><th><b><h3>Nazwa gracza</h3></b><th><h3>Wygrane gry</h3></th></tr>"
};

// Top players motd commands.
new const topPlayersMotdCommands[][] =
{
	"/top",
	"/topka",
	"/topgg"
};


#if defined DEBUG_MODE

// Prefix used in log_amx to log custom error messages.
new const nativesLogPrefix[] = "[GUNGAME ERROR]";

#endif

// Value which will be returned if an error occured in any of natives.
new const nativesErrorValue = -1;

// Natives: [][0] is native name, [][1] is native function.
new const nativesData[][][] =
{
	{ "SetUserLevel", "native_SetUserLevel" },
	{ "GetUserLevel", "native_GetUserLevel" },
	
	{ "GetMaxLevel", "native_GetMaxLevel" },
	
	{ "RespawnPlayer", "native_RespawnPlayer" },
	
	{ "GetUserWeapon", "native_GetUserWeapon" },
	{ "GetWeaponsData", "native_GetWeaponsData" },

	{ "GetUserWins", "naitve_GetUserWins" },
	{ "GetUserCombo", "native_GetUserCombo" }
};


new userLevel[MAX_PLAYERS + 1],
	userKills[MAX_PLAYERS + 1],
	userName[MAX_PLAYERS + 1][MAX_CHARS],
	userShortName[MAX_PLAYERS + 1][MAX_CHARS],
	userTimeToRespawn[MAX_PLAYERS + 1],
	userWins[MAX_PLAYERS + 1],
	bool:userSpawnProtection[MAX_PLAYERS + 1],
	userCombo[MAX_PLAYERS + 1],
	userLastOrigin[MAX_PLAYERS + 1][3],
	userIdleStrikes[MAX_PLAYERS + 1],
	bool:userFalling[MAX_PLAYERS + 1],
	userWarmupWeapon[MAX_PLAYERS + 1] = { -1, ... },
	userWarmupCustomWeaponIndex[MAX_PLAYERS + 1] = { -1, ... },

	weaponNames[sizeof(weaponsData)][MAX_CHARS - 1],
	weaponEntityNames[sizeof(weaponsData)][MAX_CHARS],
	weaponTempName[MAX_CHARS],

	bool:gungameEnded,

	maxLevel,
	halfMaxLevel,

	hudObjects[3],

	bool:warmupEnabled,
	warmupTimer,
	warmupWeaponIndex,
	warmupWeaponName = -1,

	spriteLevelupIndex,

	Handle:mysqlHandle,
	bool:mysqlLoaded,

	topPlayersNames[topPlayersDisplayed + 1][MAX_CHARS],
	topPlayersWins[topPlayersDisplayed + 1],
	bool:topPlayersDataLoaded,
	topPlayersMotdCode[MAX_CHARS * 50],
	topPlayersMotdLength,
	topPlayersMotdName[MAX_CHARS],
	bool:topPlayersMotdCreated,

	wandSpritesIndexes[sizeof(wandSprites)],
	wandLastAttack[MAX_PLAYERS + 1];


public plugin_init()
{
	register_plugin("GunGame", "v2.0", AUTHOR);

	// Register Death and team assign events.
	register_event("DeathMsg", "playerDeathEvent", "a");
	register_event("TeamInfo", "onTeamAssign", "a");

	// Register info change and model set events.
	register_forward(FM_ClientUserInfoChanged, "clientInfoChanged");
	register_forward(FM_SetModel, "setEntityModel");

	// Register message events (say, TextMsg and radio message).
	register_message(get_user_msgid("SayText"), "sayHandle");
	register_message(get_user_msgid("TextMsg"), "textGrenadeMessage");
	register_message(get_user_msgid("SendAudio"), "audioGrenadeMessage");

	// Register spawn, damage, addItem and multiple other events on player.
	RegisterHam(Ham_Spawn, "player", "playerSpawn", true);
	RegisterHam(Ham_TakeDamage, "player", "takeDamage", false);

	// Register item-add forward on player classname.
	RegisterHam(Ham_AddPlayerItem, "player", "onAddItemToPlayer");

	// Register greande think forward if HE explode time differs from default.
	if(heGrenadeExplodeTime != defaultExplodeTime)
	{
		RegisterHam(Ham_Think, "grenade", "heGrenadeThink");
	}

	// Register knife deployement for model-changes if wand is enabled.
	if(wandEnabled)
	{
		RegisterHam(Ham_Item_Deploy, wandBaseEntity, "weaponDeploy", true);
	}

	// Register collision event on every weapon registered in gungame.
	ForArray(i, droppedWeaponsClassnames)
	{
		RegisterHam(Ham_Touch, droppedWeaponsClassnames[i], "onPlayerWeaponTouch", false);
	}

	// Get names of weapons.
	ForArray(i, weaponsData)
	{
		getWeaponsName(i, weaponsData[i][weaponCSW], weaponNames[i], charsmax(weaponNames[]));
	}

	// Register primary attack with weapons registered in gungame.
	ForArray(i, weaponsData)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, weaponEntityNames[i], "primaryAttack");
	}


	// Block some commands.
	registerCommands(blockedCommands, sizeof blockedCommands, "blockCommandUsage");

	// Register weapon list commands.
	registerCommands(listWeaponsCommands, sizeof listWeaponsCommands, "listWeaponsMenu");

	// Register top player menu commands.
	registerCommands(topPlayersMotdCommands, sizeof topPlayersMotdCommands, "topPlayersMotdHandler");
	

	// Create hud objects.
	ForRange(i, 0, charsmax(hudObjects))
	{
		hudObjects[i] = CreateHudSyncObj();
	}

	// Hook 'say' client command to create custom lookup command.
	register_clcmd("say", "sayCustomCommandHandle");

	// Get gungame max level.
	maxLevel = sizeof weaponsData - 1;

	// Get half of max gungame level rounded, so we can limit level on freshly-joined players.
	halfMaxLevel = floatround(float(maxLevel) / 2, floatround_round);

	// Toggle warmup a bit delayed from plugin start.
	set_task(1.0, "delayed_toggleWarmup");

	// Load top players from MySQL.
	loadTopPlayers();

	// Load cvars.
	loadGameCvars();

	// Remove weapons off the ground if enabled.
	if(removeWeaponsOffTheGround)
	{
		removeWeaponsOffGround();
	}

#if defined TEST_MODE

	// Test commands.
	register_clcmd("say /lvl", "setMaxLevel");
	register_clcmd("say /addlvl", "addLevel");
	register_clcmd("say /kills", "addKills");
	register_clcmd("say /addkill", "addFrag");
	register_clcmd("say /win", "testWinMessage");
	register_clcmd("say /warmup", "warmupFunction");

#endif
}

// Code sections are: "Natives", "Forwards & menus & unassigned publics", "Database", "Tasks" and "Functions"

/*
		[ Natives ]
*/

// Register natives on mode 0.
public plugin_natives()
{
	ForArray(i, nativesData)
	{
		register_native(nativesData[i][0], nativesData[i][1], false);
	}
}

public native_SetUserLevel(plugin, params)
{
	// Get targeted player index.
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Get level to be set.
	new level = get_param(2);

	// Log to console and return if level is too high/low.
	if(0 > level > maxLevel)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Level value incorrect (%i).", nativesLogPrefix, level);
		
		#endif

		return nativesErrorValue;
	}

	// Set level.
	userLevel[index] = level;

	return 1;
}

public native_GetUserLevel(plugin, params)
{
	// Get targeted player index.
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Return user level.
	return userLevel[index];
}

public native_GetUserWeaponKills(plugin, params)
{
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Return weapon kills.
	return userKills[index];
}

// Return max level.
public native_GetMaxLevel(plugin, params)
{
	return maxLevel;
}

public native_RespawnPlayer(plugin, params)
{
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	new Float:time = get_param_f(2);

	// Log to console and return if respawn time is too low.
	if(time < 0.0)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Respawn time is too low (%f).", time);
		
		#endif

		return nativesErrorValue;
	}

	// Set respawn task.
	respawnPlayer(index, time);

	return 1;
}

public native_GetUserWeapon(plugin, params)
{
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Return user current weapon.
	return weaponsData[userLevel[index]][0];
}

public native_GetWeaponsData(plugin, params)
{
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	new value = get_param(2),
		min = 0,
		max = 2

	// Log to console and return if data index is too high/low.
	if(min > value > max)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Weapons data array is too %s (%i [Min. %i | Max. %i]).", nativesLogPrefix, 0 > value ? "low" : "high", value, min, max);
		
		#endif

		return nativesErrorValue;
	}

	// Return weapons data.
	return weaponsData[userLevel[index]][value];
}

public naitve_GetUserWins(plugin, params)
{
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	return userWins[index];
}

public native_GetUserCombo(plugin, params)
{
	new index = get_param(1);

	if(isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	return userCombo[index];
}

/*
		[ Forwards & menus & unassigned publics ]
*/

public plugin_precache()
{
	new filePath[MAX_CHARS * 3];

	// Loop through sounds data array and precache sounds.
	ForArray(i, soundsData)
	{
		ForRange(j, 0, maxSounds - 1)
		{
			// Continue if currently processed soundsData cell length is 0.
			if(!strlen(soundsData[i][j]))
			{
				continue;
			}

			// Add 'sound/' to downloaded file path.
			formatex(filePath, charsmax(filePath), "%s%s", containi(soundsData[i][j], "sound/") == -1 ? "sound/" : "", soundsData[i][j]);

			if(!file_exists(filePath))
			{
				// Log error and continue to next sound file if currently processed file was not found.
				#if defined DEBUG_MODE

				log_amx("Warning: skipping file ^"%s^" precaching ([%i][%i]). File was not found.", soundsData[i][j], i, j);
				
				#endif

				continue;
			}

			// Precache sound using fakemeta.
			engfunc(EngFunc_PrecacheSound, soundsData[i][j]);
		}
	}

	// Precache sprite.
	spriteLevelupIndex = engfunc(EngFunc_PrecacheModel, spritesData[spriteLevelup]);

	// Connect do mysql database here, since precache is called before init.
	connectDatabase();

	// Precache wand models.
	ForArray(i, wandModels)
	{
		engfunc(EngFunc_PrecacheModel, wandModels[i]);
	}

	// Precache wand sprites.
	ForArray(i, wandSprites)
	{
		wandSpritesIndexes[i] = engfunc(EngFunc_PrecacheModel, wandSprites[i]);
	}

	// Precache wand sounds.
	ForArray(i, wandSounds)
	{
		precache_sound(wandSounds[i]);
	}
}

public client_authorized(index)
{
	// Do nothing if user is a hltv.
	if(is_user_hltv(index))
	{
		return;
	}

	// Get player's name once, so we dont do that every time we need that data.
	get_user_name(index, userName[index], charsmax(userName[]));

	// Clamp down player's name so we can use that to prevent char-overflow in HUD etc.
	clampDownClientName(index, userShortName[index], charsmax(userShortName[]), maxNicknameLength, nicknameReplaceToken);

	// Load mysql data.
	getWinsData(index);

	// Preset user level to 0.
	userLevel[index] = 0;

	// Dont calculate level if gungame has ended.
	if(gungameEnded)
	{
		return;
	}

	new lowestLevel = getCurrentLowestLevel(),
		newLevel = (lowestLevel > 0 ? lowestLevel : 0 > halfMaxLevel ? halfMaxLevel : newLevel);

	// Set user level to current lowest or half of max level if current lowest is greater than half.
	userLevel[index] = newLevel;
	userKills[index] = 0;

	// Respawn player.
	set_task(2.0, "respawnPlayerOnJoin", index + TASK_RESPAWN_ON_JOIN);
}

// Remove hud tasks on disconnect.
public client_disconnected(index)
{
	removeHud(index);
}

// Get user's name again when changed.
public clientInfoChanged(index)
{
	get_user_name(index, userName[index], charsmax(userName[]));

	clampDownClientName(index, userShortName[index], charsmax(userShortName[]), maxNicknameLength, nicknameReplaceToken);
}

// Prevent picking up weapons of off the ground.
public onPlayerWeaponTouch(weapon, index)
{
	return is_user_connected(index) ? HAM_SUPERCEDE : HAM_IGNORED;
}

public setEntityModel(entity, model[])
{
	// Return if this model is too short to work with.
	if(strlen(model) < 8)
	{
		return;
	}

	// Clamp down matches a bit.
	if(model[7] != 'w' || model[8] != '_')
	{
		return;
	}

	// Get damage time of grenade.
	static Float:damageTime;
	pev(entity, pev_dmgtime, damageTime);

	// Return if grenade was not yet thrown.
	if(!damageTime)
	{
		return;
	}

	new owner = pev(entity, pev_owner);

	// Return if grenade owner is not present.
	if(!is_user_connected(owner))
	{
		return;
	}
			
	// Set tasks to give grenade back after it has exploded. 
	if(model[9] == 'h' && model[10] == 'e')
	{
		if(weaponsData[userLevel[owner]][weaponCSW] == CSW_HEGRENADE || warmupWeapon == CSW_HEGRENADE && warmupEnabled)
		{
			set_task(giveBackHeInterval, "giveHeGrenade", owner + TASK_GIVEGRENADE);
		}

		if(heGrenadeExplodeTime != defaultExplodeTime)
		{
			set_pev(entity, pev_dmgtime, get_gametime() + heGrenadeExplodeTime);
		}
	}
	else if(model[9] == 'f' && model[10] == 'l' && weaponsData[userLevel[owner]][weaponCSW] == CSW_KNIFE)
	{
		set_task(giveBackFlashInterval, "giveFlashGrenade", owner + TASK_GIVEGRENADE);
	}
}

public primaryAttack(entity)
{
	new index = get_pdata_cbase(entity, 41, 4);

	// Block attacking if gungame has ended.
	if(gungameEnded && is_user_alive(index))
	{
		return PLUGIN_HANDLED;
	}

	new weaponIndex = cs_get_weapon_id(entity);

	// Handle wand attacking.
	wandAttack(index, weaponIndex);

	return PLUGIN_CONTINUE;
}

public onAddItemToPlayer(index, weaponEntity)
{
	if(cs_get_weapon_id(weaponEntity) != CSW_C4)
	{
		return HAM_IGNORED;
	}

	// Disable player's planting ability.
	cs_set_user_plant(index, false, false);

	// Reset body model to get rid of bomb on the back.
	set_pev(index, pev_body, false);

	// Kill weapon entity.
	ExecuteHam(Ham_Item_Kill, weaponEntity);

	SetHamReturnInteger(false);

	return HAM_SUPERCEDE;
}

public client_PreThink(index)
{
	// Return if player is not alive, is hltv or a bot.
	if(!fallDamageEnabled || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Set falling status based on current velocity.
	userFalling[index] = bool:(entity_get_float(index, EV_FL_flFallVelocity) > 350.00);
}

public client_PostThink(index)
{
	// Return if player is not alive, is hltv, is bot or is not falling.
	if(!fallDamageEnabled || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index) || !userFalling[index])
	{
		return;
	}

	// Block falldamage.
	entity_set_int(index, EV_INT_watertype, -3);
}

public onTeamAssign()
{
	new index = read_data(1);

	// Do noting if player already spawned.
	if(is_user_alive(index))
	{
		return;
	}

	new userTeam = get_user_team(index);

	// Narrow matches a bit.
	if(userTeam == 0 || userTeam == 3)
	{
		return;
	}

	// Remove respawn task if present.
	if(task_exists(index + TASK_RESPAWN))
	{
		remove_task(index + TASK_RESPAWN);
	}

	// Remove respawn info task if present.
	if(task_exists(index + TASK_NOTIFY))
	{
		remove_task(index + TASK_NOTIFY);
	}

	// Respawn player shortly after joining team.
	set_task(2.0, "respawnPlayerOnJoin", index + TASK_RESPAWN_ON_JOIN);
}

public takeDamage(victim, idinflictor, attacker, Float:damage, damagebits)
{
	// Return if attacker isnt alive, self damage, no damage or players are on the same team.
	if(!is_user_alive(attacker) || victim == attacker || !damage || !is_user_alive(victim) || get_user_team(attacker) == get_user_team(victim))
	{
		return HAM_IGNORED;
	}

	// Return if gungame has ended.
	if(gungameEnded)
	{
		return HAM_SUPERCEDE;
	}

	// Set damage multiplier.
	SetHamParamFloat(4, damage * (weaponsData[userLevel[attacker]][weaponDamage] / 100.0));

	// Show damage info in hud.
	set_hudmessage(takeDamageHudColor[0], takeDamageHudColor[1], takeDamageHudColor[2], 0.8, 0.4, 0, 6.0, takeDamageHudTime, 0.0, 0.0);
	ShowSyncHudMsg(attacker, hudObjects[hudObjectDamage], "%i^n", floatround(damage, floatround_round));

	return HAM_IGNORED;
}

public heGrenadeThink(entity)
{
	// Return if invalid entity or grenade is not HE.
	if(!pev_valid(entity) || !isHeGrenade(entity))
	{
		return;
	}

	// Set on ground flag to he grenade.
	set_pev(entity, pev_flags, FL_ONGROUND);
}

public weaponDeploy(entity)
{
	new index = pev(entity, pev_owner),
		weapon = cs_get_weapon_id(entity);

	// Return if player isnt alive or its not a warmup with wands.
	if(!warmupEnabled && warmupWeapon != -2 || !is_user_alive(index) || userLevel[index] != maxLevel || !wandEnabled || weapon != CSW_KNIFE)
	{
		return;
	}
		
	setWandModels(index);
	setWeaponAnimation(index, 3);
}

public playerDeathEvent()
{
	new victim = read_data(2);

	// Return if victim is a bot or hltv.
	if(is_user_bot(victim) || is_user_hltv(victim))
	{
		return;
	}

	// Return if gungame has ended.
	if(gungameEnded)
	{
		removeIdleCheck(victim);

		return;
	}

	// Respawn player shortly if warmup is enabled.
	if(warmupEnabled)
	{
		respawnPlayer(victim, warumpRespawnInterval);
	
		return;
	}

	// Remove grenade task if present.
	if(task_exists(victim + TASK_GIVEGRENADE))
	{
		remove_task(victim + TASK_GIVEGRENADE);
	}

	// Remove HUD.
	removeHud(victim);
	
	// Set killstreak to 0.	
	userCombo[victim] = 0;
	
	new killer = read_data(1),
		weapon[12];

	// Get weapon name.
	read_data(4, weapon, charsmax(weapon));

	if(killer == victim || !killer)
	{
		// Decement user level if he killed himself with grenade.
		if(equal(weapon, "hegrenade"))
		{
			decrementUserWeaponKills(victim, 1, true);
		}

		// Prevent weapon-drop to the floor.
		removePlayerWeapons(victim);

		// Respawn player.
		respawnPlayer(victim, respawnInterval);

		return;
	}

	if(userLevel[killer] == maxLevel)
	{
		// End gungame if user has reached max level + 1.
		endGunGame(killer);
		
		return;
	}

	// Respawn victim normally.
	respawnPlayer(victim, respawnInterval);

	if(userSpawnProtection[victim])
	{
		// Remove protection task if present.
		if(task_exists(victim + TASK_SPAWNPROTECTION))
		{
			remove_task(victim + TASK_SPAWNPROTECTION);
		}

		// Toggle off respawn protection.
		toggleSpawnProtection(victim, false);

		// Prevent weapon-drop to the floor.
		removePlayerWeapons(victim);

		return;
	}

	if(equal(weapon, "knife") && userLevel[killer] != maxLevel)
	{
		if(userLevel[victim] > 1)
		{
			// Decrement victim level when killed with knife and his level is greater than 1.
			decrementUserLevel(victim, 1);

			// Notify player.
			ColorChat(victim, RED, "%s^x01 Zostales zabity z kosy przez^x04 %n^x01. Twoj poziom spadl do^x04 %i^x01.", chatPrefix, killer, userLevel[victim] + 1);
		}

		// Increment killer's weapon kills by two instead of leveling up imediatly.
		knifeKillInstantLevelup ? incrementUserLevel(killer, knifeKillReward, true) : incrementUserWeaponKills(killer, knifeKillReward);
	}
	else
	{
		incrementUserWeaponKills(killer, 1);
	}

	// Ammo refill enabled?
	if(refillWeaponAmmo)
	{
		refillAmmo(killer);
	}

	// Prevent weapon-drop to the floor.
	if(is_user_alive(victim))
	{
		removePlayerWeapons(victim);
	}

	// Notify about killer's health left.
	ColorChat(victim, RED, "%s^x01 Zabity przez^x04 %n^x01 (^x04%i^x01 HP)", chatPrefix, killer, get_user_health(killer));
}

public playerSpawn(index)
{
	// Return if gungame has ended or player isnt alive.
	if(!is_user_alive(index) || gungameEnded)
	{
		return;
	}

	if(warmupEnabled)
	{
		// Give weapons to player.
		giveWarmupWeapons(index);

		set_user_health(index, warmupHealth);
	}
	else
	{
		// Enable hud.
		showHud(index);

		// Give weapons to player.
		giveWeapons(index);

		// Enbale spawn protection.
		toggleSpawnProtection(index, true);

		// Set task to disable spawn protection.
		set_task(spawnProtectionTime, "spawnProtectionOff", index + TASK_SPAWNPROTECTION);

		// Set task to chcek if player is AFK.
		set_task(idleCheckInterval, "checkIdle", index + TASK_IDLECHECK, .flags = "b");
	}
}

public sayHandle(msgId, msgDest, msgEnt)
{
	new index = get_msg_arg_int(1);

	// Return if sender is not connected anymore.
	if(!is_user_connected(index))
	{
		return PLUGIN_CONTINUE;
	}

	new chatString[2][192];

	// Get message arguments.
	get_msg_arg_string(2, chatString[0], charsmax(chatString[]));

	if(equal(chatString[0], "#Cstrike_Chat_All"))
	{
		// Get message arguments.
		get_msg_arg_string(4, chatString[0], charsmax(chatString[]));
		
		// Set argument to empty string.
		set_msg_arg_string(4, "");

		// Format new message to be sent.
		formatex(chatString[1], charsmax(chatString[]), "^x04[%i Lv. (%s)]^x03 %n^x01 :  %s", userLevel[index] + 1, customWeaponNames[userLevel[index]], index, chatString[0]);
	}
	else // Format new message to be sent.
	{
		formatex(chatString[1], charsmax(chatString[]), "^x04[%i Lv. (%s)]^x01 %s", userLevel[index] + 1, customWeaponNames[userLevel[index]], chatString[0]);
	}

	// Send new message.
	set_msg_arg_string(2, chatString[1]);

	return PLUGIN_CONTINUE;
}

public sayCustomCommandHandle(index)
{
	new message[MAX_CHARS - 10],
		command[MAX_CHARS - 10];

	// Remove quotes from message.
	getChatMessageArguments(message, charsmax(message));
	
	// Retrieve command from message.
	getFirstArgument(command, charsmax(command), message, charsmax(message));

	// Show player info if commands are matching.
	if(containi(command, lookupCommand) > -1)
	{
		showPlayerInfo(index, getPlayerByName(message));
	}

	return PLUGIN_CONTINUE;
}

public textGrenadeMessage(msgid, dest, id)
{
	// Return if text is not the one we are looking for.
	if(get_msg_args() != 5 || get_msg_argtype(5) != ARG_STRING)
	{
		return PLUGIN_CONTINUE;
	}

	static argumentText[MAX_CHARS - 1];

	// Get message argument.
	get_msg_arg_string(5, argumentText, charsmax(argumentText));

	// Return if it is not the one we are looking for.
	if(!equal(argumentText, "#Fire_in_the_hole"))
	{
		return PLUGIN_CONTINUE;
	}

	// Get message argument.
	get_msg_arg_string(2, argumentText, charsmax(argumentText));

	// Return if player is not alive.
	if(!is_user_alive(str_to_num(argumentText)))
	{
		return PLUGIN_CONTINUE;
	}

	// Block message.
	return PLUGIN_HANDLED;
}

public audioGrenadeMessage()
{
	// Return if this sound is not the one we are interesed in.
	if(get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING)
	{
		return PLUGIN_CONTINUE;
	}

	new argumentText[MAX_CHARS - 10];

	// Get message arguments.
	get_msg_arg_string(2, argumentText, charsmax(argumentText));

	// Return if it is not the one we are looking for.
	if(!equal(argumentText[1], "!MRAD_FIREINHOLE"))
	{
		return PLUGIN_CONTINUE;
	}

	// Block sending audio message.
	return PLUGIN_HANDLED;
}

public displayWarmupTimer()
{
	// Return if warmup has ended.
	if(!warmupEnabled)
	{
		return;
	}

	// Decrement warmup timer.
	warmupTimer--;

	if(warmupTimer >= 0)
	{
		// Play timer tick sound.
		playSound(0, soundTimerTick, -1, false);

		// Get warmup weapon name index if not done so yet.
		if(warmupWeaponName == -1)
		{
			getWarmupWeaponName();
		}
			
		// Display warmup hud.
		set_hudmessage(warmupHudColors[0], warmupHudColors[1], warmupHudColors[2], -1.0, 0.1, 0, 6.0, 0.6, 0.2, 0.2);
		
		if(warmupWeapon == -3)
		{
			ForPlayers(i)
			{
				if(!is_user_alive(i) || is_user_hltv(i) || is_user_bot(i) || userWarmupWeapon[i] == -1)
				{
					continue;
				}

				ShowSyncHudMsg(i, hudObjects[hudObjectWarmup], "[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]", warmupTimer, customWeaponNames[userWarmupCustomWeaponIndex[i]]);
			}
		}
		else
		{
			ShowSyncHudMsg(0, hudObjects[hudObjectWarmup], "[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]", warmupTimer, warmupWeapon == -2 ? "Rozdzki" : customWeaponNames[warmupWeapon == -1 ? warmupWeaponIndex : warmupWeaponName]);
		}

		// Set task to display hud again.
		set_task(1.2, "displayWarmupTimer");
	}
	else // Disable warmup if timer is less than 0.
	{
		toggleWarmup(false);
	}
}

public listWeaponsMenu(index)
{
	// Create menu handler.
	new menuIndex = menu_create("Lista broni:^n[Bron ^t-^tpoziom  ^t-^t ilosc wymaganych zabojstw]", "listWeaponsMenu_handler");

	ForArray(i, weaponsData)
	{
		// Add item to menu.
		menu_additem(menuIndex, fmt("[%s - %i lv. - %i]", i == maxLevel ? (wandEnabled ? "Rozdzka" : customWeaponNames[i]) : customWeaponNames[i], i + 1, weaponsData[i][weaponKills]));
	}

	// Display menu to player.
	menu_display(index, menuIndex);

	return PLUGIN_CONTINUE;
}

public listWeaponsMenu_handler(id, menu, item)
{
	// Destroy menu.
	menu_destroy(menu);

	return PLUGIN_CONTINUE;
}

public topPlayersMotdHandler(index)
{
	// Return if top players data was not loaded yet.
	if(!topPlayersDataLoaded)
	{
		ColorChat(index, RED, "%s^x01 Topka nie zostala jeszcze zaladowana.", chatPrefix);
	
		return PLUGIN_CONTINUE;
	}

	// Create top players motd if this is the first time someone has used command on this map.
	if(!topPlayersMotdCreated)
	{
		createTopPlayersMotd();
	}

	// Display motd.
	show_motd(index, topPlayersMotdCode, topPlayersMotdName);

	return PLUGIN_CONTINUE;
}

/*
		[ TASKS ]
*/

public delayed_toggleWarmup()
{
	toggleWarmup(true);
}

public rewardWarmupWinner(taskIndex)
{
	new winner = taskIndex - TASK_REWARDWINNER;

	// Return if user is not connected or his level is somehow incorrect. 
	if(!is_user_connected(winner) || userLevel[winner] >= warmupLevelReward)
	{
		return;
	}

	// Add reward.
	incrementUserLevel(winner, warmupLevelReward - userLevel[winner] - 1, false);
}

public giveHeGrenade(taskIndex)
{
	new index = taskIndex - TASK_GIVEGRENADE;

	// Return if player is not alive or this type of grenade is none of his weapons.
	if(!is_user_alive(index) || !warmupEnabled && weaponsData[userLevel[index]][weaponCSW] != CSW_HEGRENADE || warmupEnabled && warmupWeaponIndex == CSW_HEGRENADE)
	{
		return;
	}

	// Add grenade.
	give_item(index, "weapon_hegrenade");
}

public giveFlashGrenade(taskIndex)
{
	new index = taskIndex - TASK_GIVEGRENADE;

	// Return if player is not alive or flash grenade is none of his allowed weapons.
	if(!is_user_alive(index) || weaponsData[userLevel[index]][weaponCSW] != CSW_KNIFE)
	{
		return;
	}

	// Add grenade.
	give_item(index, "weapon_flashbang");
}

public spawnProtectionOff(taskIndex)
{
	new index = taskIndex - TASK_SPAWNPROTECTION;

	// Return if player is not alive.
	if(!is_user_alive(index))
	{
		return;
	}

	// Disable spawn protection.
	toggleSpawnProtection(index, false);
}

public checkIdle(taskIndex)
{
	new index = taskIndex - TASK_IDLECHECK;

	// Return if player is not alive.
	if(!is_user_alive(index))
	{
		return;
	}

	new currentOrigin[3];

	// Get user position.
	get_user_origin(index, currentOrigin);

	if(!userLastOrigin[index][0] && !userLastOrigin[index][1] && !userLastOrigin[index][2])
	{
		// Handle position update.
		ForRange(i, 0, 2)
		{
			userLastOrigin[index][i] = currentOrigin[i];
		}

		return;
	}

	// Get distance from last position to current position.
	new distance = get_distance(userLastOrigin[index], currentOrigin);

	// Handle position update.
	ForRange(i, 0, 2)
	{
		userLastOrigin[index][i] = currentOrigin[i];
	}

	if(distance < idleMaxDistance)
	{
		// Slap player if he's camping, make sure not to kill him.
		if(++userIdleStrikes[index] >= idleMaxStrikes)
		{
			ForRange(i, 0, 1)
			{
				user_slap(index, !i ? (get_user_health(index) > idleSlapPower ? idleSlapPower : 0) : 0);
			}
		}
	}
	else
	{
		// Set user strikes back to 0.
		userIdleStrikes[index] = 0;
		
		// Set user last position to 0.
		ForRange(i, 0, 2)
		{
			userLastOrigin[index][i] = 0;
		}
	}
}

public clientRespawn(taskIndex)
{
	new index = taskIndex - TASK_RESPAWN;

	// Return if player is not connected anymore.
	if(!is_user_connected(index))
	{
		return;
	}

	// Execute spawn forward on this player.
	ExecuteHamB(Ham_CS_RoundRespawn, index);
}

public respawnNotify(taskIndex)
{
	new index = taskIndex - TASK_NOTIFY;

	// Return if player not connected or gungame has ended.
	if(!is_user_connected(index) || gungameEnded)
	{
		return;
	}

	// Remove tasks if they exists somehow.
	if(is_user_alive(index))
	{
		if(task_exists(index + TASK_RESPAWN))
		{
			remove_task(index + TASK_RESPAWN);
		}

		if(task_exists(index + TASK_NOTIFY))
		{
			remove_task(index + TASK_NOTIFY);
		}

		return;
	}

	// Print respawn-time info.
	client_print(index, print_center, "Odrodzenie za: %i", userTimeToRespawn[index]);

	// Decrease respawn time.
	userTimeToRespawn[index]--;
}

public displayHud(taskIndex)
{
	new index = taskIndex - TASK_DISPLAYHUD;

	if(!is_user_alive(index))
	{
		return;
	}

	new leader = getGameLeader(), leaderData[MAX_CHARS * 3], nextWeapon[25];

	// Format leader's data if available.
	if(!leader)
	{
		formatex(leaderData, charsmax(leaderData), "^nLider: Brak");
	}
	else
	{
		formatex(leaderData, charsmax(leaderData), "^nLider: %s :: %i poziom [%s - %i/%i]", printName(leader), userLevel[leader] + 1, userLevel[leader] == maxLevel ? (wandEnabled ? "Rozdzka" : customWeaponNames[userLevel[leader]]) : customWeaponNames[userLevel[leader]], userKills[leader], weaponsData[userLevel[leader]][weaponKills]);
	}

	// Format next weapon name if available, change knife to wand if enabled so.
	if(userLevel[index] == sizeof weaponsData - 2)
	{
		formatex(nextWeapon, charsmax(nextWeapon), "%s", wandEnabled ? "Rozdzka" : customWeaponNames[userLevel[index] + 1]);
	}
	else
	{
		formatex(nextWeapon, charsmax(nextWeapon), "%s", isOnLastLevel(index) ? "Brak" : customWeaponNames[userLevel[index] + 1]);
	}

	// Display hud.
	set_hudmessage(hudColors[0], hudColors[1], hudColors[2], -1.0, 0.02, 0, 6.0, hudDisplayInterval + 0.1, 0.0, 0.0);
	ShowSyncHudMsg(index, hudObjects[hudObjectDefault], "Poziom: %i/%i [%s - %i/%i] :: Zabic z rzedu: %i^nNastepna bron: %s%s", userLevel[index] + 1, sizeof weaponsData, isOnLastLevel(index) ? (wandEnabled ? "Rozdzka" : customWeaponNames[userLevel[leader]]) : customWeaponNames[userLevel[index]], userKills[index], weaponsData[userLevel[index]][weaponKills], userCombo[index], nextWeapon, leaderData);
}

// Respawn player.
public respawnPlayerOnJoin(taskIndex)
{
	respawnPlayer(taskIndex - TASK_RESPAWN_ON_JOIN, 0.1);
}

/*
		[ Database ]
*/

connectDatabase()
{
	new mysqlRequest[MAX_CHARS * 4];

	// Create mysql tuple.
	mysqlHandle = SQL_MakeDbTuple(mysqlData[databaseHost], mysqlData[databaseUser], mysqlData[databasePass], mysqlData[databaseDB]);

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest), "CREATE TABLE IF NOT EXISTS `%s` (`userName` VARCHAR(35), `userWins` INT(5), PRIMARY KEY (`userName`));", mysqlData[databaseTableName]);

	// Send request to database.
	SQL_ThreadQuery(mysqlHandle, "connectDatabaseHandler", mysqlRequest);
}

public connectDatabaseHandler(failState, Handle:query, error[], errorNumber, data[], dataSize)
{
	// Connection has succeded?
	mysqlLoaded = bool:(failState == TQUERY_SUCCESS);

	// Throw log to server's console if error occured.
	if(!mysqlLoaded)
	{
		log_amx("Database connection status: Not connected. Error (%i): %s", errorNumber, error);
	}

	return PLUGIN_CONTINUE;
}

public getWinsData(index)
{
	new mysqlRequest[MAX_CHARS * 3],
		data[2];

	data[0] = index;

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest), "SELECT `userWins` FROM `%s` WHERE `userName` = '%n';", mysqlData[databaseTableName], index);

	// Send request to database.
	SQL_ThreadQuery(mysqlHandle, "getWinsDataHandler", mysqlRequest, data, charsmax(data));
}

// Read user wins from database.
public getWinsDataHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	if(SQL_NumRows(query))
	{
		userWins[data[0]] = SQL_ReadResult(query, 0);
	}
}

public saveWinsData(index)
{
	new mysqlRequest[MAX_CHARS * 5];

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest), "INSERT INTO `%s` (`userName`, `userWins`) VALUES ('%n', %i) ON DUPLICATE KEY UPDATE `userWins` = %i;", mysqlData[databaseTableName], index, userWins[index], userWins[index]);

	// Send request to database.
	SQL_ThreadQuery(mysqlHandle, "saveWinsDataHandler", mysqlRequest);
}

// Pretty much ignore any data that database sends back.
public saveWinsDataHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	return PLUGIN_CONTINUE;
}

public loadTopPlayers()
{
	new mysqlRequest[MAX_CHARS * 3];

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest), "SELECT * FROM `%s` ORDER BY `userWins` DESC LIMIT %i;", mysqlData[databaseTableName], topPlayersDisplayed + 1);

	// Send request to database.
	SQL_ThreadQuery(mysqlHandle, "loadTopPlayersHandler", mysqlRequest);
}

public loadTopPlayersHandler(failState, Handle:query, error[], errorNumber, data[], dataSize)
{
	new iterator;

	// Load top players while there are any.
	while(SQL_MoreResults(query))
	{
		// Get top player name.
		SQL_ReadResult(query, 0, topPlayersNames[iterator], charsmax(topPlayersNames[]));
		
		// Assign his wins to variable.
		topPlayersWins[iterator] = SQL_ReadResult(query, 1);

		// Iterate loop.
		iterator++;

		// Go to next result.
		SQL_NextRow(query);
	}

	// Database laoded successfully.
	topPlayersDataLoaded = true;

	// Create motd.
	createTopPlayersMotd();
}

/*
		[ FUNCTIONS ]
*/

loadGameCvars()
{
	ForArray(i, gameCvars)
	{
		set_cvar_num(gameCvars[i][0], str_to_num(gameCvars[i][1]));
	}
}

bool:isOnLastLevel(index)
{
	return bool:(userLevel[index] == maxLevel);
}

// To be used in natives only.
isPlayerConnected(index)
{
	// Throw error and return error value if player is not connected.
	if(!is_user_connected(index))
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Player is not connected (%i).", nativesLogPrefix, index);
		
		#endif

		return nativesErrorValue;
	}

	return 1;
}

createTopPlayersMotd()
{
	new playersDisplayed;

	// Add HTML code to string in a loop.
	ForArray(i, topPlayersMotdHTML)
	{
		topPlayersMotdLength += formatex(topPlayersMotdCode[topPlayersMotdLength], charsmax(topPlayersMotdCode), topPlayersMotdHTML[i]);
	}

	ForRange(i, 0, topPlayersDisplayed - 1)
	{
		// Continue if player has no wins at all.
		if(!topPlayersWins[i])
		{
			continue;
		}

		// Add HTML to motd.
		topPlayersMotdLength += formatex(topPlayersMotdCode[topPlayersMotdLength], charsmax(topPlayersMotdCode), "<tr><td><b><h4>%d</h4></b><td><h4>%s</h4><td><h4>%d</h4><td></tr>", i + 1, topPlayersNames[i], topPlayersWins[i]);
		
		playersDisplayed++;
	}

	// Format motd title.
	formatex(topPlayersMotdName, charsmax(topPlayersMotdName), "Top %i graczy GunGame", playersDisplayed);

	topPlayersMotdCreated = true;
}

removeIdleCheck(index)
{
	// AFK-check task exists?
	if(task_exists(index + TASK_IDLECHECK))
	{
		// Remove AFK-check task.
		remove_task(index + TASK_IDLECHECK);
		
		// Set last user position to 0 to prevent bugs with respawning close to death-place.
		ForRange(i, 0, 2)
		{
			userLastOrigin[index][i] = 0;
		}
	
		// Set AFK-strikes to zero.
		userIdleStrikes[index] = 0;
	}
}

giveWarmupWeapons(index)
{
	// Return if player is not alive.
	if(!is_user_alive(index))
	{
		return;
	}

	// Strip weapons.
	removePlayerWeapons(index);

	// Give knife as a default weapon.
	give_item(index, "weapon_knife");
	
	if(warmupWeapon > -1)
	{
		new weaponName[MAX_CHARS - 1];
	
		// Get warmup weapon entity classname.	
		get_weaponname(warmupWeapon, weaponName, charsmax(weaponName));

		// Set weapon backpack ammo to 100.
		cs_set_user_bpammo(index, warmupWeapon, 100);
	}

	// Add random warmup weapon multiple times.
	else if(warmupWeapon == -1)
	{
		// Add weapon.
		give_item(index, weaponEntityNames[warmupWeaponIndex]);

		// Set weapon bp ammo to 100.
		cs_set_user_bpammo(index, get_weaponid(weaponEntityNames[warmupWeaponIndex]), 100);
	}

	// Set wand model.
	else if(warmupWeapon == -2)
	{
		setWandModels(index);
	}

	// Add random weapon.
	else if(warmupWeapon == -3)
	{
		randomWarmupWeapon(index);
	}
}

// Remove quotes from message.
getChatMessageArguments(message[], length)
{
	// Get message arguments.
	read_args(message, length);

	// Get rid of quotes.
	remove_quotes(message);
}

getFirstArgument(word[], wordLength, string[], stringLength)
{
	if(string[0] == '^"')
	{
		// Handle message different if it has quotes in it.	
		strtok(string[1], word, wordLength, string, stringLength, '^"');

		// Get rid of white-chars.
		trim(string);
	}
	else
	{
		strtok(string, word, wordLength, string, stringLength);
	}
}

bool:isHeGrenade(entity)
{
	// Return if entity is invalid.
	if(!pev_valid(entity))
	{
		return false;
	}

	new classname[9];

	// Get classname of entity.
	pev(entity, pev_classname, classname, charsmax(classname));

	// Return if classname is not grenade.
	if(!equal(classname, "grenade") || get_pdata_int(entity, 96) & 1 << 8)
	{
		return false;
	}

	// Return if grenade type is not HE.
	if(!(get_pdata_int(entity, 114) & 1 << 1))
	{
		return false;
	}

	return true;
}

setWandModels(index)
{
	// Set V and P wand models.
	set_pev(index, pev_viewmodel2, wandModels[0]);
	set_pev(index, pev_weaponmodel2, wandModels[1]);
}

setWeaponAnimation(index, animation)
{
	// Set weapon animation.
	set_pev(index, pev_weaponanim, animation);

	// Display animation.
	message_begin(1, 35, _, index);
	write_byte(animation);
	write_byte(pev(index, pev_body));
	message_end();
}

removeWeaponsOffGround()
{
	new entity;

	// Remove all weapons off the ground.
	ForArray(i, droppedWeaponsClassnames)
	{
		while((entity = find_ent_by_class(entity, droppedWeaponsClassnames[i])))
		{
			remove_entity(entity);
		}
	}
}

showPlayerInfo(index, target)
{
	if(is_user_connected(target))
	{
		ColorChat(
			index,
			RED,
			"%s^x01 Gracz ^x04%n^x01 jest na poziomie^x04 %i^x01 [^x04%s^x01 - ^x04%i^x01/^x04%i^x01]. Wygral ^x04%i^x01 razy. Status uslugi:^x04 %s^x01.",
			chatPrefix,
			target,
			userLevel[target] + 1,
			isOnLastLevel(target) ? (wandEnabled ? "Rozdzka" : customWeaponNames[userLevel[target]]) : customWeaponNames[userLevel[target]],
			userKills[target],
			weaponsData[userLevel[target]][weaponKills],
			userWins[target],
			get_user_flags(target) & VIP_FLAG ? "VIP" : "Brak");
	}
	else
	{
		ColorChat(
			index,
			RED,
			"%s^x01 %s",
			chatPrefix,
			target == -1 ? "Wiecej niz jeden gracz pasuje do podanego nicku." : " Gracz o tym nicku nie zostal znaleziony.");
	}
}

playSound(index, soundType, soundIndex, bool:emitSound)
{
	// Sound index is set to random?
	if(soundIndex < 0)
	{
		// Create dynamic array to store valid sound indexes.
		new Array:soundIndexes = ArrayCreate(1, 1);

		// Iterate through sounds array to find valid sounds, then add them to dynamic array.
		ForRange(j, 0, maxSounds - 1)
		{
			if(strlen(soundsData[soundType][j]))
			{
				ArrayPushCell(soundIndexes, j);
			}
		}

		// Randomize valid index read from dynamic array.
		soundIndex = ArrayGetCell(soundIndexes, random_num(0, ArraySize(soundIndexes) - 1));
		
		// Get rid of array to save data space.
		ArrayDestroy(soundIndexes);
	}

	// Emit sound directly from entity? 
	if(emitSound)
	{
		emit_sound(index, CHAN_AUTO, soundsData[soundType][soundIndex], soundsVolumeData[soundType][soundIndex], ATTN_NORM, (1 << 8), PITCH_NORM);
	}
	else
	{
		client_cmd(index, "%s ^"%s^"", defaultSoundCommand, soundsData[soundType][soundIndex]);
	}
}

toggleWarmup(bool:status)
{
	setWarmupHud(status);

	warmupEnabled = status;

	// Warmup set to disabled?
	if(!warmupEnabled)
	{
		// Get warmup winner based on kills.
		new winner = getWarmupWinner(true);

		// Set task to reward winner after game restart.
		if(is_user_connected(winner))
		{
			set_task(2.0, "rewardWarmupWinner", winner + TASK_REWARDWINNER);
		}
		
		// Restart the game.
		set_cvar_num("sv_restartround", 1);

		// Play gungame start sound.
		playSound(0, soundGameStart, -1, false);
	}
	else
	{
		// Disable freezetime.
		set_cvar_num("mp_freezetime", 0);

		// Make sure that freezetime is disabled, set to 0 if not.
		if(get_cvar_num("mp_freezetime"))
		{
			server_cmd("amx_cvar mp_freezetime 0");
		}

		// Remove hud tasks.
		ForPlayers(i)
		{
			if(is_user_connected(i) && task_exists(i + TASK_DISPLAYHUD))
			{
				remove_task(i + TASK_DISPLAYHUD);
			}
		}

		// Get random weapon, only if its not a knife.
		warmupWeaponIndex = random_num(0, sizeof customWeaponNames - 2);

		// Play warmup start sound.
		playSound(0, soundWarmup, -1, true);
	}
}

// Set timer HUD task.
setWarmupHud(bool:status)
{
	if(status)
	{
		set_task(1.0, "displayWarmupTimer");

		warmupTimer = warmupDuration;
	}
}

toggleSpawnProtection(index, bool:status)
{
	// Toggle spawn protection on index.
	userSpawnProtection[index] = status;

	// Set glowshell to indicate spawn protection. Disable any rendering if status is false.
	if(status)
	{
		set_user_rendering(index, kRenderFxGlowShell, spawnProtectionColors[0], spawnProtectionColors[1], spawnProtectionColors[2], kRenderGlow, spawnProtectionShell);
	}
	else
	{
		set_user_rendering(index);
	}
}

// Set hud display task.
showHud(index)
{
	set_task(hudDisplayInterval, "displayHud", index + TASK_DISPLAYHUD, .flags = "b");
}

// Remove hud display task.
removeHud(index)
{
	if(task_exists(index + TASK_DISPLAYHUD))
	{
		remove_task(index + TASK_DISPLAYHUD);
	}
}

respawnPlayer(index, Float:time)
{
	// Player already respawned?
	if(is_user_alive(index))
	{
		return;
	}

	new clientTeam = get_user_team(index);

	// Not interested in spectator and unassigned players.
	if(clientTeam != 1 && clientTeam != 2)
	{
		return;
	}

	// Get respawn time to int.
	new intTime = floatround(time, floatround_round);

	// Set user respawn time to integer value.
	userTimeToRespawn[index] = intTime;

	// Set tasks to notify about timeleft to respawn.
	ForRange(i, 0, intTime - 1)
	{
		set_task(float(i), "respawnNotify", index + TASK_NOTIFY);
	}

	// Set an actuall respawn function delayed.
	set_task(time, "clientRespawn", index + TASK_RESPAWN);
}

incrementUserWeaponKills(index, value)
{
	// Set kills required and killstreak.
	userCombo[index] += value;
	userKills[index] += value;

	// Levelup player if weapon kills are greater than reqiured for his current level.
	while(userKills[index] >= weaponsData[userLevel[index]][weaponKills])
	{
		incrementUserLevel(index, 1, true);
	}
}

// Decrement weapon kills, take care of leveldown.
decrementUserWeaponKills(index, value, bool:levelLose)
{
	if(levelLose && userKills[index] - value < 0)
	{
		decrementUserLevel(index, 1);
	}
}

incrementUserLevel(index, value, bool:notify)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	userKills[index] -= weaponsData[userLevel[index]][weaponKills];
	userLevel[index] = (userLevel[index] + value > maxLevel ? maxLevel : userLevel[index] + value);

	// Levelup effect.
	displayLevelupSprite(index);

	// Make sure player's kills are positive.
	if(userKills[index] < 0)
	{
		userKills[index] = 0;
	}

	// Add weapons for player's current level.
	giveWeapons(index);

	if(notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Gracz^x04 %s^x01 awansowal na poziom^x04 %i^x01 ::^x04 %s^x01.", chatPrefix, printName(index), userLevel[index] + 1, userLevel[index] == maxLevel ? (wandEnabled ? "Rozdzka" : customWeaponNames[userLevel[index]]) : customWeaponNames[userLevel[index]]);
		
		// Play levelup sound.
		playSound(index, soundLevelUp, -1, false);
	}
}

displayLevelupSprite(index)
{
	new Float:userOrigin[3];

	pev(index, pev_origin, userOrigin);

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, userOrigin, 0);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, userOrigin[0]);
	engfunc(EngFunc_WriteCoord, userOrigin[1]);
	engfunc(EngFunc_WriteCoord, userOrigin[2]);
	engfunc(EngFunc_WriteCoord, userOrigin[0]);
	engfunc(EngFunc_WriteCoord, userOrigin[1]);
	engfunc(EngFunc_WriteCoord, userOrigin[2] + spriteLevelupZaxis);
	write_short(spriteLevelupIndex);
	write_byte(0);
	write_byte(0);
	write_byte(spriteLevelupLife);
	write_byte(spriteLevelupWidth);
	write_byte(0);
	write_byte(spriteLevelupRGB[0]);
	write_byte(spriteLevelupRGB[1]);
	write_byte(spriteLevelupRGB[2]);
	write_byte(spriteLevelupBrightness);
	write_byte(0);
	message_end();
}

decrementUserLevel(index, value)
{
	// Decrement user level, make sure his level is not negative.
	userLevel[index] = (userLevel[index] - value < 0 ? 0 : userLevel[index] - value);
	userKills[index] = 0;

	// Play leveldown sound.
	playSound(index, soundLevelDown, -1, false);
}

endGunGame(winner)
{
	// Mark gungame as ended.
	gungameEnded = true;

	// Remove hud, and tasks if they exist.
	ForPlayers(i)
	{
		if(!is_user_alive(i) && task_exists(i + TASK_RESPAWN))
		{
			remove_task(i + TASK_RESPAWN);

			if(task_exists(i + TASK_NOTIFY))
			{
				remove_task(i + TASK_NOTIFY);
			}
		}

		removeHud(i);
	}

	new winMessage[MAX_CHARS * 8],
		tempMessage[MAX_CHARS * 3],
		topPlayers[topPlayersDisplayed + 1],
		index;

	// Set black screen.
	setBlackScreenFade(2);

	// Recursevly set black screen every second so player has it colored no matter what.
	set_task(1.0, "setBlackScreenOn");

	// Get top players.
	getPlayerByTopLevel(topPlayers, charsmax(topPlayers));

	// Reward winner.
	userWins[winner]++;

	// Save winner to database.
	saveWinsData(winner);

	// Format win message.
	formatex(winMessage, charsmax(winMessage), "%s^nTopowi gracze:^n^n^n^n", chatPrefix);

	// Format top players message.
	ForArray(i, topPlayers)
	{
		index = topPlayers[i];

		if(!is_user_connected(index) || is_user_hltv(index))
		{
			continue;
		}

		formatex(tempMessage, charsmax(tempMessage), "^n^n%i. %s (%i lvl - %s [%i fragow] [wygranych: %i])", i + 1, userShortName[index], userLevel[index] + 1, customWeaponNames[userLevel[index]], get_user_frags(index), userWins[index]);

		add(winMessage, charsmax(winMessage), tempMessage, charsmax(tempMessage));
	}

	// Play game win sound to winner.
	playSound(winner, soundAnnounceWinner, -1, false);

	// Display formated win message.
	set_hudmessage(255, 255, 255, -1.0, -1.0, 0, 6.0, blackScreenTimer, 0.0, 0.0);
	ShowSyncHudMsg(0, hudObjects[hudObjectDefault], winMessage);

	// Vote for next map.
	showMapVoteMenu();
}

giveWeapons(index)
{
	if(!is_user_alive(index))
	{
		return;
	}

	// We dont want players to have armor.
	set_user_armor(index, defaultArmorLevel);

	// Strip weapons.
	removePlayerWeapons(index);

	// Add knife.
	give_item(index, "weapon_knife");

	// Add wand if player is on last level and such option is enabled.
	if(userLevel[index] != maxLevel)
	{
		// Add weapon couple of times to make sure backpack ammo is right.
		if(userLevel[index] != maxLevel)
		{
			new csw = get_weaponid(weaponEntityNames[userLevel[index]]);

			give_item(index, weaponEntityNames[userLevel[index]]);

			cs_set_user_bpammo(index, csw, 100);
		}

		// Add two flashes if player is on last level.
		else if(!wandEnabled)
		{
			if(flashesEnabled)
			{
				ForRange(i, 0, 1)
				{
					give_item(index, "weapon_flashbang");
				}
			}
		}

		// Deploy primary weapon.
		engclient_cmd(index, weaponEntityNames[userLevel[index]]);
	}
	else 
	{
		// Set wand model.
		if(wandEnabled)
		{
			setWandModels(index);
		}
	}
}

getWarmupWinner(bool:announce)
{
	// Return if warmup reward is none.
	if(warmupLevelReward < 2)
	{
		return 0;
	}

	new winner;

	// Get player with most kills.
	ForPlayers(i)
	{
		if(!is_user_connected(i) || get_user_frags(i) < get_user_frags(winner))
		{
			continue;
		}

		winner = i;
	}

	// Print win-message couple times in chat.
	if(announce && is_user_connected(winner))
	{
		ForRange(i, 0, 2)
		{
			ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode zaczyna GunGame z poziomem^x04 %i^x01!", chatPrefix, winner, warmupLevelReward);
		}
	}

	return winner;
}

getWeaponsName(iterator, weaponIndex, string[], length)
{
	// Get weapon classname.
	get_weaponname(weaponIndex, weaponEntityNames[iterator], charsmax(weaponEntityNames[]));

	// Get rid of "weapon_" prefix.
	copy(weaponTempName, charsmax(weaponTempName), weaponEntityNames[iterator][7]);
	
	// Get weapon name to upper case.
	strtoupper(weaponTempName);

	// Copy weapon name to original output.
	copy(string, length, weaponTempName);
}

getGameLeader()
{
	new highest;

	// Loop through all players, get one with highest level and kills.
	ForPlayers(i)
	{
		if(!is_user_connected(i))
		{
			continue;
		}
		
		if(userLevel[i] > userLevel[highest])
		{
			highest = i;
		}

		else if(userLevel[i] == userLevel[highest])
		{
			if(userKills[i] > userKills[highest])
			{
				highest = i;
			}
		}
	}

	return highest;
}

getCurrentLowestLevel()
{
	// Just return 0 if there are less than 3 players, no need for a loop.
	if(get_playersnum() < 3)
	{
		return 0;
	}

	new lowest;

	// Loop through all players and get lowest level.
	ForPlayers(i)
	{
		if(!is_user_connected(i) || userLevel[i] > lowest)
		{
			continue;
		}

		lowest = userLevel[i];
	}

	return lowest;
}

getPlayerByName(name[])
{
	// Get rid of white spaces.
	trim(name);

	// Return error value if name was not specified.
	if(!strlen(name))
	{
		// Throw error to server console.
		#if defined DEBUG_MODE
		
		log_amx("Function: getPlayerByName ^"name^" argument's length is %i.", name, strlen(name));
		
		#endif

		return -2;
	}

	new foundPlayerIndex,
		playersFound;

	// Loop through players, get index if names are matching.
	ForPlayers(i)
	{
		if(!is_user_connected(i) || containi(userName[i], name) == -1)
		{
			continue;
		}
		
		playersFound++;
			
		foundPlayerIndex = i;
	}

	// Return -1 if found more than one guy.
	if(playersFound > 1)
	{
		return -1;
	}

	return foundPlayerIndex;
}

getPlayerByTopLevel(array[], count)
{
	new highestLevels[MAX_PLAYERS + 1],
		counter,
		clientLevel;

	ForPlayers(index)
	{
		if(!is_user_connected(index))
		{
			continue;
		}

		clientLevel = userLevel[index] + 1;

		for(new i = count - 1; i >= 0; i--)
		{
			if(highestLevels[i] < clientLevel && i)
			{
				continue;
			}

			if(highestLevels[i] >= clientLevel && i < count - 1)
			{
				counter = i + 1;
			}

			else if(!i)
			{
				counter = 0;
			}

			else 
			{
				break;
			}

			for(new j = count - 2; j >= counter; j--)
			{
				highestLevels[j + 1] = highestLevels[j];

				array[j + 1] = array[j];
			}

			highestLevels[counter] = clientLevel;
			array[counter] = index;
		}
	}
}

getWarmupWeaponName()
{
	// Return if warmup weapon is static.
	if(warmupWeaponName > -1)
	{
		return;
	}

	// Loop through all weapons, find one with same ID as warmup weapon.
	ForArray(i, weaponsData)
	{
		if(warmupWeapon == weaponsData[i][weaponCSW])
		{
			warmupWeaponName = i;

			break;
		}
	}
}

refillAmmo(index)
{
	// Return if player is not alive or gungame has ended.
	if(!is_user_alive(index) || gungameEnded)
	{
		return;
	}

	new userWeapon = get_user_weapon(index);

	// Return if for some reason player has no weapon.
	if(!userWeapon)
	{
		return;
	}

	new weaponClassname[MAX_CHARS - 1],
		weaponEntity;

	// Get weapon classname.
	get_weaponname(userWeapon, weaponClassname, charsmax(weaponClassname));

	// Get entity index of player's weapon.
	weaponEntity = find_ent_by_owner(-1, weaponClassname, index);

	// Return if weapon index is invalid.
	if(!weaponEntity)
	{
		return;
	}

	// Refill weapon ammo.
	cs_set_weapon_ammo(weaponEntity, ammoAmounts[userWeapon]);
}

randomWarmupWeapon(index)
{
	// Return if player is not alive or warmup is not enabled.
	if(!is_user_alive(index) || !warmupEnabled)
	{
		return;
	}

	new csw,
		weaponClassname[MAX_CHARS - 1],
		weaponsArrayIndex = random_num(0, sizeof weaponsData - 2);

	// Get random index from weaponsData array.
	csw = weaponsData[weaponsArrayIndex][0];

	// Get classname of randomized weapon.
	get_weaponname(csw, weaponClassname, charsmax(weaponClassname));

	// Add weapon to player.
	give_item(index, weaponClassname);

	// Set weapon bp ammo to 100.
	cs_set_user_bpammo(index, csw, 100);

	userWarmupWeapon[index] = csw;
	userWarmupCustomWeaponIndex[index] = weaponsArrayIndex;
}

// Clamp down user name if its length is greater than "value" argument.
clampDownClientName(index, output[], length, const value, const token[])
{
	if(strlen(userName[index]) > value)
	{
		format(output, value, userName[index]);

		add(output, length, token);
	}
	else
	{
		// Just copy his original name instead.
		copy(userShortName[index], charsmax(userShortName[]), userName[index]);
	}
}

wandAttack(index, weapon)
{
	// Block attack if player is not alive, wand is not enabled, not holding a knife, not on last level or wand is not set as warmup weapon.
	if(!is_user_alive(index) || !wandEnabled || weapon != CSW_KNIFE || !isOnLastLevel(index) || warmupEnabled && warmupWeapon != -2)
	{
		return PLUGIN_HANDLED;
	}

	// Set punchangle whenever player attacks.
	set_pev(index, pev_punchangle, Float:{ -1.5, 0.0, 0.0 });

	// Block shooting if cooldown is still on.
	if(wandLastAttack[index] + wandAttackInterval > get_gametime())
	{
		return PLUGIN_HANDLED;
	}

	new endOrigin[3],
		startOrigin[3];

	// Get player position and end position.
	get_user_origin(index, startOrigin, 0);
	get_user_origin(index, endOrigin, 3);

	// Block shooting if distance is too high.
	if(get_distance(startOrigin, endOrigin) > wandAttackMaxDistance)
	{
		return PLUGIN_HANDLED;
	}

	// Animate attacking.
	setWeaponAnimation(index, 1);

	// Play attack sound.
	emit_sound(index, CHAN_AUTO, wandSounds[wandSoundShoot], 1.0, 0.80, SND_SPAWNING, 100);

	static victim, bodyPart;

	// Animate attacking.
	set_pev(index, pev_weaponanim, 5);

	message_begin(8, 35, _, index);
	write_byte(5);
	write_byte(0);
	message_end();

	// Animate shooting.
	message_begin(0, 23);
	write_byte(1);
	write_short(index | 0x1000);
	write_coord(endOrigin[0]);
	write_coord(endOrigin[1]);
	write_coord(endOrigin[2]);
	write_short(wandSpritesIndexes[wandSpriteAttack]);
	write_byte(0);
	write_byte(5);
	write_byte(wandAttackSpriteLife);
	write_byte(30);
	write_byte(40);
	write_byte(wandAttackSpriteColor[0]);
	write_byte(wandAttackSpriteColor[1]);
	write_byte(wandAttackSpriteColor[2]);
	write_byte(wandAttackSpriteBrightness);
	write_byte(0);
	message_end();

	// Animate explosion on hit.
	message_begin(0, 23);
	write_byte(3);
	write_coord(endOrigin[0]);
	write_coord(endOrigin[1]);
	write_coord(endOrigin[2]);
	write_short(wandSpritesIndexes[wandSpriteExplodeOnHit]);
	write_byte(10);	
	write_byte(15);
	write_byte(4);
	message_end();

	// Get index of player that index is aiming at.
	get_user_aiming(index, victim, bodyPart);

	// Block attacking if they are in the same team.
	if(get_user_team(index) == get_user_team(victim))
	{
		return PLUGIN_HANDLED;
	}

	// Log last attack.
	wandLastAttack[index] = floatround(get_gametime());

	// Create temp. entity.
	new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	static Float:victimOrigin[3];

	// Get end point vector.
	IVecFVec(endOrigin, victimOrigin);

	// Set temp. entity's origin.
	set_pev(entity, pev_origin, victimOrigin);

	// Remove temp. entity.
	engfunc(EngFunc_RemoveEntity, entity);

	if(!is_user_alive(victim))
	{
		return PLUGIN_HANDLED;
	}

	static Float:victimVelocity[3];
	pev(victim, pev_velocity, victimVelocity);

	victimVelocity[0] *= 0.7;
	victimVelocity[1] *= 0.7;
	victimVelocity[2] *= 0.7;

	// Set victim's velocity.
	set_pev(victim, pev_velocity, victimVelocity);

	new hitDamage,
		bloodScale,
		attackerHealth = pev(victim, pev_health);

	// Calculate damage and blood scale.
	hitDamage = wandDamageEffects[bodyPart][0];
	bloodScale = wandDamageEffects[bodyPart][1];

	// Execute damage.
	ExecuteHamB(Ham_TakeDamage, victim, 0, index, float(hitDamage), (1<<1));

	if(attackerHealth > hitDamage)
	{
		static Float:vicOrigin[3];
		pev(victim, pev_origin, vicOrigin);

		message_begin(0, 23);
		write_byte(115);
		write_coord(floatround(vicOrigin[0] + random_num(-20, 20)));
		write_coord(floatround(vicOrigin[1] + random_num(-20, 20)));
		write_coord(floatround(vicOrigin[2] + random_num(-20, 20)));
		write_short(wandSpritesIndexes[wandSpriteBlood]);
		write_short(wandSpritesIndexes[wandSpriteBlood]);
		write_byte(248);
		write_byte(bloodScale);
		message_end();

		message_begin(8, 71, _, victim);
		write_byte(0);
		write_byte(0);
		write_long(1 << 16);
		write_coord(0);
		write_coord(0);
		write_coord(0);
		message_end();

		message_begin(8, 98, _, victim);
		write_short(1 << 13);
		write_short(1 << 14);
		write_short(0x0000);
		write_byte(0);
		write_byte(255);
		write_byte(0);
		write_byte(100);
		message_end();

		message_begin(1, 97, _, victim);
		write_short(0xFFFF);
		write_short(1 << 13);
		write_short(0xFFFF);
		message_end();

		static Float:victimOrigin[3];
		pev(victim, pev_origin, victimOrigin);

		message_begin(0, 23);
		write_byte(15);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 200.0);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 20.0);
		write_short(wandSpritesIndexes[wandSpritePostHit]);
		write_byte(15);
		write_byte(random_num(27, 30));
		write_byte(2);
		write_byte(random_num(30, 70));
		write_byte(40);
		message_end();
	}
	else if(attackerHealth <= hitDamage)
	{
		static Float:victimOrigin[3];
		pev(victim, pev_origin, victimOrigin);

		message_begin(0, 23);
		write_byte(15);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 200.0);
		engfunc(EngFunc_WriteCoord, victimOrigin[0]);
		engfunc(EngFunc_WriteCoord, victimOrigin[1]);
		engfunc(EngFunc_WriteCoord, victimOrigin[2] + 20.0);
		write_short(wandSpritesIndexes[wandSpritePostHit]);
		write_byte(15);
		write_byte(random_num(27, 30));
		write_byte(2);
		write_byte(random_num(30, 70));
		write_byte(40);
		message_end();
	}

	return PLUGIN_CONTINUE;
}


stock registerCommands(const array[][], arraySize, function[])
{
	#if !defined ForRange

		#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

	#endif

	#if AMXX_VERSION_NUM < 183
	
	ForRange(i, 0, arraySize - 1)
	{
		ForRange(j, 0, 1)
		{
			register_clcmd(fmt("%s %s", !j ? "say" : "say_team", array[i]), function);
		}
	}

	#else

	new newCommand[33];

	ForRange(i, 0, arraySize - 1)
	{
		ForRange(j, 0, 1)
		{
			formatex(newCommand, charsmax(newCommand), "%s %s", !j ? "say" : "say_team", array[i]);
			register_clcmd(newCommand, function);
		}
	}

	#endif
}

public blockCommandUsage(index)
{
	return PLUGIN_HANDLED_MAIN;
}

public setBlackScreenOn()
{
	setBlackScreenFade(1);
}

setBlackScreenFade(fade)
{
	new time,
		hold,
		flags;

	static iMsgScreenFade;

	if(!iMsgScreenFade)
	{
		iMsgScreenFade = get_user_msgid("ScreenFade");
	}
	
	switch (fade)
	{
		case 1:
		{
			time = 1;
			hold = 1;
			flags = 4;
		}

		case 2:
		{
			time = 4096;
			hold = 1024;
			flags = 1;
		}
		
		default:
		{
			time = 4096;
			hold = 1024;
			flags = 2;
		}
	}

	message_begin(MSG_BROADCAST, iMsgScreenFade);
	write_short(time);
	write_short(hold);
	write_short(flags);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	message_end();
}

stock removePlayerWeapons(index)
{
	static entity;

	entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "player_weaponstrip"));

	if(!pev_valid(entity))
	{
		return;
	}
	
	dllfunc(DLLFunc_Spawn, entity);
	dllfunc(DLLFunc_Use, entity, index);
	engfunc(EngFunc_RemoveEntity, entity);
}

#if defined TEST_MODE

public setMaxLevel(index)
{
	userLevel[index] = sizeof weaponsData - 3;

	incrementUserLevel(index, 1, true);
}

public addLevel(index)
{
	incrementUserLevel(index, 1, true);
}

public addKills(index)
{
	incrementUserWeaponKills(index, 1);
}

public addFrag(index)
{
	set_user_frags(index, get_user_frags(index) + 2);
}

public testWinMessage(index)
{
	endGunGame(index);
}

public warmupFunction(index)
{
	toggleWarmup(!warmupEnabled);

	client_print(0, print_chat, "Warmup = %s", warmupEnabled ? "ON" : "OFF");
}

#endif

/*
		[ CHANGELOG ]

DATE:				ACTIONS:

2018-12-(03-04)		Baisc stuff; client variables (name, kills, level etc.), arrays with weapon data, arrays with weapon names, basic actions / functions; leveling up, getting weapon kills, showing basic info,
					HUD, setting up weapons-data arrays properly, weapons-data list menu, gungame start & end + proper chat/hud info, damage and kills management, first fixes, properly setitng up custom
					weapon names array, first tests. Work time: about 4 hours.

2018-12-04			More specified HUD info, fixed user and weapon leveling, added chat & hud leveling-up info, created a propper gungame ending, first optimalistaions, cleaning up code, further tests,
					screen fade, getting gungame winner, managing player's data (kills, level, name), managing client_connect/client_disconccnect data, further optimalisation improves etc. Work time: about 3 hours.

2018-12-(05-06)		Much better over-all plugin perfomance, optimalising, setting up const variables, setting up plugin setup part with const variables, managing greande messages, chat, prefxes, managing HE, knife
					and every other special-treatement weapon to work properly, added a fuck ton of tasks with proper task-indexing, player-indexing and time-based operations, created a propper ending message with
					saving data to nvault, reading data from nvault, fixed leveling-system, fixed self-kill bug, added a fuck ton of optimalisations (including short-name-variables, functions speeding up whole HUD,
					and other frequently-used algorythms, created a propper database key based on player's name), and many other - smaller changes. Work time: around 8 hours.

2018-12-09			User combo + its management, fixed nvault data-save algorythm, optimalised every variable with static easy-to-change define of max players, kill info (killer's health and name), take damage hud
					management + current damage given info, saved user short name in other way to avoid perfomance issues, many small changes. Work time: 2 hours.

2018-12-14			Removed bomb on spawn, blocked weapon drop on death, further optimalisations, created tested and debugged /info {name} command, changes to death-events, changed names of many variables to
					easier to read ones, replaced static Ham events registering with ForRange loops /w const variables. Code is no longer scrambled, every section has its place and every function/public/task has been
					assigned to it's section. Further fixes and code management. Whole code is now easy to set on the upper part of code. Sound management + precache + def. sounds. Work time: 8 hours.

2018-12-15			Added onTeamAssign event and player respawn management after joining server/choosing team. Small fixes/optimalisations. Fixed spawn-kill protection. Fixed damage system. Work time: 1 hour.

2018-12-16			Fixed sounds management, added defaultSoundCommand const and changed playSound function's code a bit to cooporate with one of two commands. Work time: 30 minutes.

2018-12-19			Optimalised code a bit, a lot of stuff is now easy-to-change and automated. Made some memory optimalisations. Fixed bugged timerTick sound, when timer was 0 or lower. Fixed user rendering.
					Fixed warmup weapons bugging with tasks, and did a recheck of if statements wherever it was necessary. Improved top-players menu. Further small fixes. Fixed disappearing when set_user_rendering
					was applied to player, that was spawned a second ago. Work time: 2 hours.

2018-12-20			Fixed multi chat message when using /info command. Fixed grenades handling (now it cannot be bugged anymore). Further code improvements + refactoring code a bit to clamp down file size a bit.
					Major code refactoring and cleaning up. Work time: 3 hours.

2018-12-21			Changed database type from nvault to mysql. Optimalised code a ton. Dead & alive can now chat (to prevent player sending message right after death). First VIP code. Created top players command,
					fixed database requests, created top players mysql requests and motd. Work time: 5 hours.

2019-01-03			Added natives support, got rid of multiple variables, added macrodefinition TEST_MODE and it's handling, added removing weapons off the ground, cleaned up multiple functions, added missing comments,
					fixed onTeamAssign forward, handled natives properly, added weapon damage system. Work time: --.

2019-01-(05-6)		Added wand, tested it, added/fixed multiple code comments, small fixes, cleaned up code, multiple smaller changes, assigned multiple smaller functions, handled grenade time changes, cleaned up consts
					did re-check of literlly every funciton on server, play-tested mode on 3 maps. Work time: --.

2019-01-29			Recoded some parts of engine to move to AMXX 1.9, added multiple comments, added multiple functions, changed most of functions to private, fixed smaller bugs. Work time: 40 minutes.

2019-02-02			Recoded most of engine to be compatibile with AMXX 1.9, cleaned up code a bit, fixed message arguments function, added weapon bp ammo on warmup and propper GG, added optional weapon-ammo refill,
					added optional no-falldamage, fixed hud display when warmup weapon mode == -3 or -2, fixed weapon class names, cleaned up plugin_init. Work time: 1 hour.

2019-02-26			Added parenthases in every if/for/while etc. statement, fixed some minor bugs/typos.

		[ TO DO LIST ]

	VIP

		[ KNOWN BUGS ]

*/