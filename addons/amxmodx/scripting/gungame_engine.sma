#include <amxmodx>
#include <colorchat>
#include <hamsandwich>
#include <fakemeta_util>
#include <cstrike>
#include <engine>
#include <sqlx>
#include <fun>
#include <gungame_vip>

// Do not change that, thank you
#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/ | Ogen Dogen  - amxx.pl/user/21503-ogen-dogen/"

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

#define ForTeam(%1,%2) for(new %1 = 1; %1 <= MAX_PLAYERS; %1++) if (is_user_connected(%1) && get_user_team(%1) == %2)
#define ForDynamicArray(%1,%2) for(new %1 = 0; %1 < ArraySize(%2); %1++)
#define ForPlayers(%1) for(new %1 = 1; %1 <= MAX_PLAYERS; %1++)
#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof(%2); %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

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
	weaponTeamKills
};

// Main data array. [0] is weapon CSW_ index. [1] is kills required to level-up. [2] is kills required to level-up as a team.
new const weaponsData[][] =
{
	{ CSW_GLOCK18, 2, 15 },
	{ CSW_USP, 2, 15 },
	{ CSW_P228, 2, 15 },

	{ CSW_FIVESEVEN, 2, 15 },
	{ CSW_DEAGLE, 2, 15 },
	{ CSW_ELITE, 2, 15 },
	
	{ CSW_M3, 3, 15 },
	{ CSW_XM1014, 3, 15 },
	{ CSW_TMP, 3, 15 },
	
	{ CSW_MAC10, 3, 15 },
	{ CSW_UMP45, 3, 15 },
	{ CSW_MP5NAVY, 3, 15 },
	
	{ CSW_P90, 4, 15 },
	{ CSW_GALIL, 4, 15 },
	{ CSW_FAMAS, 3, 15 },
	
	{ CSW_AK47, 4, 15 },
	{ CSW_SCOUT, 2, 15 },
	{ CSW_M4A1, 4, 15 },

	{ CSW_SG552, 4, 15 },
	{ CSW_AUG, 4, 15 },
	{ CSW_AWP, 4, 15 },

	{ CSW_G3SG1, 2, 15 },
	{ CSW_SG550, 2, 15 },
	{ CSW_M249, 2, 15 },

	{ CSW_HEGRENADE, 3, 3 },
	{ CSW_KNIFE, 1, 5 }
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
	"kill",

	"radio1",
	"radio2",
	"radio3",
	"report",
	"coverme",
	"takepoint",
	"holdpos",
	"regroup",
	"followme",
	"takingfire",
	"go",
	"fallback",
	"sticktog",
	"getinpos",
	"stormfront",
	"roger",
	"enemyspot",
	"needbackup",
	"sectorclear",
	"inposition",
	"reportingin",
	"getout",
	"negative",
	"enemydown"
};

// RGB of colored shell (set_user_rendering) when in spawn protection.
new const spawnProtectionColors[] = { 80, 0, 0 };

// Shell thickness.
new const spawnProtectionShell = 100;


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


// RGB colors of warmup HUD.
new const warmupHudColors[] = { 255, 255, 255 };


// Ammo indexes.
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


// Set that really high, so we dont have to worry about screen getting back to non-colored.
const Float:blackScreenTimer = 50.0;


// Base weapon_* for wand.
new const wandBaseEntity[] = "weapon_knife";

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
	"gungame/wandShoot.wav"
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
	{ "gungame/levelup.wav", "" },
	{ "gungame/leveldown.wav", "" },
	{ "gungame/timertick4.wav", "" },

	{ "gungame/warmup.wav", "" },
	{ "gungame/announcewinner.wav", "" },
	{ "gungame/gungamestart.wav", "gungame/gungamestart2.wav" }
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


// Determines number of top-players that will be shown in game-ending message.
const topPlayersDisplayed = 10;

// Top players motd HTML code.
new const topPlayersMotdHTML[][] =
{
	"<style> body{ background: #202020 } tr{ text-align: left } table{ font-size: 12px; color: #ffffff; padding: 0px } h1{ color: #FFF; font-family: Verdana }</style><body>",
	"<table width = 100%% border = 0 align = center cellpadding = 0 cellspacing = 2>",
	"<tr>\
		<th>\
			<h3>Pozycja</h3>\
		</th>\
		\
		<th>\
			<h3>Nazwa gracza</h3>\
		</th>\
		\
		<th>\
			<h3>Wygrane gry</h3>\
		</th>\
		\
		<th>\
		\
			<h3>Zabicia nozem</h3>\
		</th>\
		\
		<th>\
			<h3>%% HS</h3>\
		</th>\
	</tr>"
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
	{ "gg_set_user_level", "native_SetUserLevel" },
	{ "gg_get_user_level", "native_GetUserLevel" },

	{ "gg_set_team_level", "native_SetTeamLevel" },
	{ "gg_get_team_level", "native_GetTeamLevel" },
	
	{ "gg_get_max_level", "native_GetMaxLevel" },
	
	{ "gg_respawn_player", "native_RespawnPlayer" },
	
	{ "gg_get_user_weapon", "native_GetUserWeapon" },
	{ "gg_get_weapons_data", "native_GetWeaponsData" },

	{ "gg_get_user_wins", "native_GetUserWins" },
	{ "gg_get_user_combo", "native_GetUserCombo" }
};

enum (+= 1)
{
	cvar_spawn_protection_time,

	cvar_respawn_interval,

	cvar_flashes_enabled,

	cvar_give_back_he_interval,
	cvar_give_back_flash_interval,

	cvar_warmup_duration,
	cvar_warmup_level_reward,
	cvar_warmup_health,
	cvar_warmup_weapon,
	cvar_warump_respawn_interval,

	cvar_fall_damage_enabled,

	cvar_refill_weapon_ammo,
	cvar_refill_weapon_ammo_teamplay,

	cvar_idle_check_interval,
	cvar_idle_slap_power,
	cvar_idle_max_strikes,
	cvar_idle_max_distance,

	cvar_default_armor_level,

	cvar_knife_kill_instant_levelup,
	cvar_knife_kill_level_down_teamplay,
	cvar_knife_kill_reward,

	cvar_wand_enabled,
	cvar_wand_attack_sprite_brightness,
	cvar_wand_attack_sprite_life,
	cvar_wand_attack_max_distance,
	cvar_wand_attack_interval,

	cvar_take_damage_hud_time,
	
	cvar_remove_weapons_off_the_ground,
	
	cvar_normal_friendly_fire,
	cvar_teamplay_friendly_fire,

	cvar_spawn_protection_type
};

new const ggCvarsData[][][] =
{
	{ "gg_spawn_protection_time", "1.5" }, // Time in which player CAN get killed, but the killer will not be granted any weapon kills if victim is in spawn protection.
	
	{ "gg_respawn_interval", "3.0" }, // Respawn time during GunGame.
	
	{ "gg_flashes_enabled", "1" }, // Determines wether to enable flashes on last level. Does not support wand.
	
	{ "gg_give_back_he_interval", "1.8" }, // Time between giving a player next HE grenade (during warmup & on HE weapon level).
	{ "gg_give_back_flash_interval", "4.5" }, // Time between giving a player next Flash grenade.
	
	{ "gg_warmup_duration", "10" }, // Time of warmup in seconds
	{ "gg_warmup_level_reward", "3" }, // Level that will be set to warmup winner. Value < 1 will disable notifications and picking warmup winner.
	{ "gg_warmup_health", "50" }, // Health that players will be set to during warmup.
	{ "gg_warmup_weapon", "-2" }, // Set that to CSW_ index, -1 to get random weapon, -2 to get wands (ignoring gg_wandEnabled value) or -3 to get random weapon for every player.
	{ "gg_warump_respawn_interval", "2.0" }, // Time to respawn player during warmup.
	
	{ "gg_fall_damage_enabled", "0" }, // Enable falldamage?
	
	{ "gg_refill_weapon_ammo", "1" }, // Refill weapon clip on kill? 0 - disabled, 1 - enabled to everyone, 2 - only vips
	{ "gg_refill_weapon_ammo_teamplay", "1" }, // Enabled on teamplay? 0 - disabled, 1 - enabled, refill whole team ammo, 2 - personal refill, 3 - only vips
	
	{ "gg_idle_check_interval", "6.0" }, // Determines interval between AFK checks.
	{ "gg_idle_slap_power", "5" }, // Hit power of a slap when player is 'AFK'.
	{ "gg_idle_max_strikes", "3" }, // Determines max strikes that player can have before slaps start occuring.
	{ "gg_idle_max_distance", "30" }, // Distance that resets camping-player idle strikes.
	
	{ "gg_default_armor_level", "0" }, // Armor level for every player.
	
	{ "gg_knife_kill_instant_levelup", "0" }, // If that's set to true, knife will instantly give you gg_knifeKillReward levels. Otherwise gg_knifeKillReward means weapon kills.
	{ "gg_knife_kill_level_down_teamplay", "1" }, // Allow to level down when knifed in teamplay?
	{ "gg_knife_kill_reward", "2" }, // Knife kill reward value based on cvar_knife_kill_instant_levelup var.
	
	{ "gg_wand_enabled", "1" }, // Determines whether you want last level weapon to be knife (false) or wand (true).
	{ "gg_wand_attack_sprite_brightness", "255" }, // Wand primary attack sprite brightness.
	{ "gg_wand_attack_sprite_life", "4" }, // Wand primary attack sprite life.
	{ "gg_wand_attack_max_distance", "550" }, // Wand primary attack max distance.
	{ "gg_wand_attack_interval", "2.2" }, // Wand primary attack interval.
	
	{ "gg_take_damage_hud_time", "1.2" }, // Take damage hud hold-time.
	
	{ "gg_remove_weapons_off_the_ground", "1" }, // Remove weapons off the ground when loading map?

	{ "gg_normal_friendly_fire", "0" }, // Enable friendly fire in normal mode?
	{ "gg_teamplay_friendly_fire", "0" }, // Enable friendly fire in teamplay mode?

	{ "gg_spawn_protection_type", "0" } // Spawn protection effect: 0 - godmode, 1 - no points granted to killer if victim is on spawn protection.
};

new const forwardsNames[][] =
{
	"gg_level_up",
	"gg_level_down",
	"gg_game_end",
	"gg_game_beginning",
	"gg_player_spawned",
	"gg_combo_streak",
	"gg_game_mode_chosen"
};

enum forwardsEnum (+= 1)
{
	forwardLevelUp,
	forwardLevelDown,
	forwardGameEnd,
	forwardGameBeginning,
	forwardPlayerSpawned,
	forwardComboStreak,
	forwardGameModeChosen
};

new const gameModes[][] =
{
	"Normalny",
	"Teamowy"
};

enum (+= 1)
{
	modeNormal,
	modeTeamplay
};

new const teamNames[][] =
{
	"TT",
	"CT"
};

enum userDataEnumerator
{
	dataLevel,
	dataWeaponKills,
	dataName[MAX_CHARS],
	dataShortName[MAX_CHARS],
	dataSafeName[MAX_CHARS],
	dataTimeToRespawn,
	bool:dataSpawnProtection,
	dataCombo,
	dataLastOrigin[3],
	dataIdleStrikes,
	bool:dataFalling,
	dataWarmupWeapon,
	dataWarmupCustomWeaponIndex,
	dataAllowedWeapons,
	dataWins,
	dataKills,
	dataKnifeKills,
	dataHeadshots,
	dataWandLastAttack
};

enum topPlayersEnumerator
{
	topNames[MAX_CHARS],
	topWins,
	topKills,
	topKnifeKills,
	topHeadshots
};

enum topInfo
{
	bool:topDataLoaded,
	topMotdCode[MAX_CHARS * 50],
	topMotdLength,
	topMotdName,
	bool:topMotdCreated
};

enum warmupEnumerator
{
	bool:warmupEnabled,
	warmupTimer,
	warmupWeaponIndex,
	warmupWeaponNameIndex
};

enum teamplayEnumerator
{
	tpTeamLevel[2],
	tpTeamKills[2],
	bool:tpEnabled
};

enum dbEnumerator
{
	// These 4 need to be first.
	dbHost[MAX_CHARS * 2],
	dbUser[MAX_CHARS * 2],
	dbPass[MAX_CHARS * 2],
	dbDbase[MAX_CHARS * 2],
	// These 4 need to be first.

	Handle:sqlHandle,
	bool:sqlLoaded,
	bool:sqlConfigFound
};

enum dcDataEnumerator
{
	Array:dcDataLevel,
	Array:dcDataName,
	Array:dcDataWeaponKills
};

new userData[MAX_PLAYERS + 1][userDataEnumerator],

	warmupData[warmupEnumerator],

	topPlayers[topPlayersDisplayed + 1][topPlayersEnumerator],
	topData[topInfo],

	tpData[teamplayEnumerator],

	dbData[dbEnumerator],

	cvarsData[sizeof(ggCvarsData)],

	weaponNames[sizeof(weaponsData)][MAX_CHARS - 1],
	weaponEntityNames[sizeof(weaponsData)][MAX_CHARS],
	weaponTempName[MAX_CHARS],

	bool:gungameEnded,

	maxLevel,
	halfMaxLevel,

	hudObjects[3],

	spriteLevelupIndex,

	forwardHandles[sizeof(forwardsNames)],
	forwardReturnDummy,

	wandSpritesIndexes[sizeof(wandSprites)],

	gameVotes[sizeof(gameModes)],
	bool:gameVoteEnabled,
	gameMode = -1,

	disconnectedPlayersData[dcDataEnumerator];


public plugin_init()
{
	register_plugin("GunGame", "v2.5", AUTHOR);

	// Register cvars.
	ForArray(i, ggCvarsData)
	{
		cvarsData[i] = register_cvar(ggCvarsData[i][0], ggCvarsData[i][1]);
	}

	// Register Death and team assign events.
	register_event("DeathMsg", "playerDeathEvent", "a");
	register_event("TeamInfo", "onTeamAssign", "a");

	// Remove weapons off the ground if enabled.
	if (get_pcvar_num(cvarsData[cvar_remove_weapons_off_the_ground]))
	{
		removeWeaponsOffGround();
		
		register_event("HLTV", "roundStart", "a", "1=0", "2=0");
	}

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
	if (heGrenadeExplodeTime != defaultExplodeTime)
	{
		RegisterHam(Ham_Think, "grenade", "heGrenadeThink");
	}

	// Register knife deployement for model-changes if wand is enabled.
	if (get_pcvar_num(cvarsData[cvar_wand_enabled]))
	{
		RegisterHam(Ham_Item_Deploy, wandBaseEntity, "knifeDeploy", true);
	}

	new weaponClassname[24];
	new const excludedWeapons = (CSW_KNIFE | CSW_C4);

	ForRange(i, 1, 30)
	{
		if (!(excludedWeapons & 1 << i) && get_weaponname(i, weaponClassname, charsmax(weaponClassname)))
		{
			RegisterHam(Ham_Item_Deploy, weaponClassname, "weaponDeploy");
		}
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
	registerCommands(blockedCommands, sizeof(blockedCommands), "blockCommandUsage");

	// Register weapon list commands.
	registerCommands(listWeaponsCommands, sizeof(listWeaponsCommands), "listWeaponsMenu");

	// Register top player menu commands.
	registerCommands(topPlayersMotdCommands, sizeof(topPlayersMotdCommands), "topPlayersMotdHandler");
	
	// Create hud objects.
	ForRange(i, 0, charsmax(hudObjects))
	{
		hudObjects[i] = CreateHudSyncObj();
	}

	// Hook 'say' client command to create custom lookup command.
	register_clcmd("say", "sayCustomCommandHandle");

	// Get gungame max level.
	maxLevel = sizeof(weaponsData) - 1;

	// Get half of max gungame level rounded, so we can limit level on freshly-joined players.
	halfMaxLevel = floatround(float(maxLevel) / 2, floatround_round);

	// Create forwards.
	forwardHandles[forwardLevelUp] = CreateMultiForward(forwardsNames[0], ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // Level up (3)
	forwardHandles[forwardLevelDown] = CreateMultiForward(forwardsNames[1], ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // Level down (3)
	forwardHandles[forwardGameEnd] = CreateMultiForward(forwardsNames[2], ET_IGNORE, FP_CELL); // Game end (1)
	forwardHandles[forwardGameBeginning] = CreateMultiForward(forwardsNames[3], ET_IGNORE, FP_CELL); // Game beginning (1)
	forwardHandles[forwardPlayerSpawned] = CreateMultiForward(forwardsNames[4], ET_IGNORE, FP_CELL); // Player spawn (1)
	forwardHandles[forwardComboStreak] = CreateMultiForward(forwardsNames[5], ET_IGNORE, FP_CELL, FP_CELL); // Combo streak (2)
	forwardHandles[forwardGameModeChosen] = CreateMultiForward(forwardsNames[6], ET_IGNORE, FP_CELL); // Game mode chosen (1)

	// Toggle warmup a bit delayed from plugin start.
	set_task(1.0, "delayed_toggleWarmup");

	// Load info required to connect to database.
	loadSqlConfig();

	// Load cvars.
	loadGameCvars();

	// Connect do mysql database.
	connectDatabase();

	// Initialize dynamic arrays.
	disconnectedPlayersData[dcDataLevel] = ArrayCreate(1, 1);
	disconnectedPlayersData[dcDataName] = ArrayCreate(32, 1);
	disconnectedPlayersData[dcDataWeaponKills] = ArrayCreate(1, 1);

	// Load top players from MySQL.
	loadTopPlayers();
	#if defined TEST_MODE

		// Test commands.
		register_clcmd("say /lvl", "setMaxLevel");
		register_clcmd("say /addlvl", "addLevel");
		register_clcmd("say /kills", "addKills");
		register_clcmd("say /addkill", "addFrag");
		register_clcmd("say /winmessage", "testWinMessage");
		register_clcmd("say /warmup", "warmupFunction");
		register_clcmd("say /knife", "addKnifeKill");
		register_clcmd("say /headshot", "addHeadshot");
		register_clcmd("say /kill", "addKill");
		register_clcmd("say /win", "addWin");
		register_clcmd("say /weapon", "addWeapon");

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
	if (params != 2)
	{
		return nativesErrorValue;
	}

	// Get targeted player index.
	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Get level to be set.
	new level = get_param(2);

	// Log to console and return if level is too high/low.
	if (0 > level > maxLevel)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Level value incorrect (%i) [min. %i | max. %i].", nativesLogPrefix, level, 0, maxLevel);
		
		#endif

		return nativesErrorValue;
	}

	// Set level.
	userData[index][dataLevel] = level;

	return 1;
}

public native_GetUserLevel(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	// Get targeted player index.
	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Return user level.
	return userData[index][dataLevel];
}

public native_SetTeamLevel(plugin, params)
{
	if (params != 3)
	{
		return false;
	}

	new team = get_param(1);

	// Return false if team is invalid.
	if (team < 1 || team > 2)
	{
		return false;
	}

	new level = get_param(2);

	// Return false if level is invalid.
	if (level < 0 || level > sizeof(weaponsData) - 1)
	{
		return false;
	}

	new bool:includeMembers = bool:get_param(3);

	tpData[tpTeamLevel][team - 1] = level;

	if (includeMembers)
	{
		ForTeam(i, team)
		{
			userData[i][dataLevel] = level;
		}
	}

	return true;
}

public native_GetTeamLevel(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	new team = get_param(1);

	// Return -1 if team is invalid.
	if (team < 1 || team > 2)
	{
		return -1;
	}

	return tpData[tpTeamLevel][team - 1];
}

public native_GetUserWeaponKills(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Return weapon kills.
	return userData[index][dataWeaponKills];
}

// Return max level.
public native_GetMaxLevel(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	return maxLevel;
}

public native_RespawnPlayer(plugin, params)
{
	if (params != 2)
	{
		return nativesErrorValue;
	}


	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	new Float:time = get_param_f(2);

	// Log to console and return if respawn time is too low.
	if (time < 0.0)
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
	if (params != 1)
	{
		return nativesErrorValue;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	// Return user current weapon.
	return weaponsData[userData[index][dataLevel]][0];
}

public native_GetWeaponsData(plugin, params)
{
	if (params != 2)
	{
		return nativesErrorValue;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	new value = get_param(2),
		min = 0,
		max = 2;

	// Log to console and return if data index is too high/low.
	if (min > value > max)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Weapons data array is too %s (%i [Min. %i | Max. %i]).", nativesLogPrefix, 0 > value ? "low" : "high", value, min, max);
		
		#endif

		return nativesErrorValue;
	}

	// Return weapons data.
	return weaponsData[userData[index][dataLevel]][value];
}

public native_GetUserWins(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	return userData[index][dataWins];
}

public native_GetUserCombo(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	new index = get_param(1);

	if (isPlayerConnected(index) == nativesErrorValue)
	{
		return nativesErrorValue;
	}

	return userData[index][dataCombo];
}

/*
		[ Forwards & menus & unassigned publics ]
*/

public plugin_end()
{
	ArrayDestroy(disconnectedPlayersData[dcDataName]);
	ArrayDestroy(disconnectedPlayersData[dcDataLevel]);
	ArrayDestroy(disconnectedPlayersData[dcDataWeaponKills]);
}

public plugin_precache()
{
	new filePath[MAX_CHARS * 3];

	// Loop through sounds data array and precache sounds.
	ForArray(i, soundsData)
	{
		ForRange(j, 0, maxSounds - 1)
		{
			// Continue if currently processed soundsData cell length is 0.
			if (!strlen(soundsData[i][j]))
			{
				continue;
			}

			// Add 'sound/' to downloaded file path.
			formatex(filePath, charsmax(filePath), "%s%s", containi(soundsData[i][j], "sound/") == -1 ? "sound/" : "", soundsData[i][j]);

			if (!file_exists(filePath))
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
	userData[index][dataWarmupWeapon] = -1;
	userData[index][dataWarmupCustomWeaponIndex] = -1;

	// Do nothing if user is a hltv.
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Get name-related data.
	getUserNameData(index);

	// Load mysql data.
	getUserData(index);

	// Preset user level to 0.
	userData[index][dataLevel] = 0;
	userData[index][dataWeaponKills] = 0;

	// Reconnected?
	getOnConnect(index);

	// Dont calculate level if gungame has ended or player has reconnected.
	if (gungameEnded || userData[index][dataLevel])
	{
		return;
	}

	new lowestLevel = getCurrentLowestLevel(),
		newLevel = (lowestLevel > 0 ? lowestLevel : 0 > halfMaxLevel ? halfMaxLevel : newLevel);

	// Set user level to current lowest or half of max level if current lowest is greater than half.
	userData[index][dataLevel] = newLevel;
	userData[index][dataWeaponKills] = 0;
}

public client_putinserver(index)
{
	// Respawn player.
	set_task(2.0, "respawnPlayerOnJoin", index + TASK_RESPAWN_ON_JOIN);
	set_task(3.0, "showGameVoteMenu", index);
}

// Remove hud tasks on disconnect.
public client_disconnect(index)
{
	removeHud(index);
	updateUserData(index);
	saveOnDisconnect(index);
}

// Get user's name again when changed.
public clientInfoChanged(index)
{
	// Update name-related data.
	getUserNameData(index);
}

// Prevent picking up weapons of off the ground.
public onPlayerWeaponTouch(weapon, index)
{
	return is_user_connected(index) ? HAM_SUPERCEDE : HAM_IGNORED;
}

public setEntityModel(entity, model[])
{
	// Return if this model is too short to work with.
	if (strlen(model) < 8)
	{
		return;
	}

	// Clamp down matches a bit.
	if (!equal(model[7], "w_", 2))
	{
		return;
	}

	// Get damage time of grenade.
	static Float:damageTime;
	pev(entity, pev_dmgtime, damageTime);

	// Return if grenade was not yet thrown.
	if (!damageTime)
	{
		return;
	}

	new owner = pev(entity, pev_owner);

	// Return if grenade owner is not present.
	if (!is_user_connected(owner))
	{
		return;
	}
			
	// Set tasks to give grenade back after it has exploded. 
	if (equal(model[9], "he", 2))
	{
		if (weaponsData[userData[owner][dataLevel]][weaponCSW] == CSW_HEGRENADE || get_pcvar_num(cvarsData[cvar_warmup_weapon]) == CSW_HEGRENADE && warmupData[warmupEnabled])
		{
			set_task(get_pcvar_float(cvarsData[cvar_give_back_he_interval]), "giveHeGrenade", owner + TASK_GIVEGRENADE);
		}

		if (heGrenadeExplodeTime != defaultExplodeTime)
		{
			set_pev(entity, pev_dmgtime, get_gametime() + heGrenadeExplodeTime);
		}
	}
	else if (equal(model[9], "fl", 2) && weaponsData[userData[owner][dataLevel]][weaponCSW] == CSW_KNIFE)
	{
		set_task(get_pcvar_float(cvarsData[cvar_give_back_flash_interval]), "giveFlashGrenade", owner + TASK_GIVEGRENADE);
	}
}

public primaryAttack(entity)
{
	new index = get_pdata_cbase(entity, 41, 4);

	// Block attacking if gungame has ended.
	if (gungameEnded && is_user_alive(index))
	{
		return HAM_IGNORED;
	}

	// Cooldown on.
	if (userData[index][dataWandLastAttack] + get_pcvar_float(cvarsData[cvar_wand_attack_interval]) > get_gametime())
	{
		return HAM_SUPERCEDE;
	}

	new weaponIndex = cs_get_weapon_id(entity);

	// Handle wand attacking.
	wandAttack(index, weaponIndex);

	return HAM_IGNORED;
}

public onAddItemToPlayer(index, weaponEntity)
{
	new csw = cs_get_weapon_id(weaponEntity);

	// Skip kevlar.
	if (csw == CSW_VEST || csw == CSW_VESTHELM)
	{
		return HAM_IGNORED;
	}

	// User is allowed to carry that weapon?
	if (userData[index][dataAllowedWeapons] & (1 << csw))
	{
		return HAM_IGNORED;
	}

	if (csw == CSW_C4)
	{
		// Disable player's planting ability.
		cs_set_user_plant(index, false, false);

		// Reset body model to get rid of bomb on the back.
		set_pev(index, pev_body, false);		
	}

	// Kill weapon entity.
	ExecuteHam(Ham_Item_Kill, weaponEntity);

	SetHamReturnInteger(false);

	return HAM_SUPERCEDE;
}

public client_PreThink(index)
{
	// Return if player is not alive, is hltv or a bot.
	if (!get_pcvar_num(cvarsData[cvar_fall_damage_enabled]) || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Set falling status based on current velocity.
	userData[index][dataFalling] = bool:(entity_get_float(index, EV_FL_flFallVelocity) > 350.00);
}

public client_PostThink(index)
{
	// Return if player is not alive, is hltv, is bot or is not falling.
	if (!get_pcvar_num(cvarsData[cvar_fall_damage_enabled]) || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index) || !userData[index][dataFalling])
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
	if (is_user_alive(index))
	{
		return;
	}

	new userTeam = get_user_team(index);

	// Narrow matches a bit.
	if (0 >= userTeam > 2)
	{
		return;
	}

	// Remove respawn task if present.
	if (task_exists(index + TASK_RESPAWN))
	{
		remove_task(index + TASK_RESPAWN);
	}

	// Remove respawn info task if present.
	if (task_exists(index + TASK_NOTIFY))
	{
		remove_task(index + TASK_NOTIFY);
	}

	// Respawn player shortly after joining team.
	set_task(2.0, "respawnPlayerOnJoin", index + TASK_RESPAWN_ON_JOIN);
}

public roundStart()
{
	removeWeaponsOffGround();
}

public takeDamage(victim, idinflictor, attacker, Float:damage, damagebits)
{
	// Return if attacker isnt alive, self damage, no damage or players are on the same team.
	if (!is_user_alive(attacker) || victim == attacker || !damage || !is_user_alive(victim))
	{
		return HAM_IGNORED;
	}

	// Return if gungame has ended.
	if (gungameEnded)
	{
		return HAM_SUPERCEDE;
	}

	if (get_user_team(attacker) == get_user_team(victim))
	{
		if (gameMode == modeNormal && !get_pcvar_num(cvarsData[cvar_normal_friendly_fire]))
		{
			return HAM_SUPERCEDE;
		}
		else if (gameMode == modeTeamplay && !get_pcvar_num(cvarsData[cvar_teamplay_friendly_fire]))
		{
			return HAM_SUPERCEDE;
		}
	}

	if (userData[victim][dataSpawnProtection] && !get_pcvar_num(cvarsData[cvar_spawn_protection_type]))
	{
		return HAM_SUPERCEDE;
	}

	if (get_pcvar_num(cvarsData[cvar_wand_enabled]))
	{
		if (isOnLastLevel(attacker) || get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -2)
		{
			return HAM_SUPERCEDE;
		}
	}

	// Show damage info in hud.
	set_hudmessage(takeDamageHudColor[0], takeDamageHudColor[1], takeDamageHudColor[2], 0.8, 0.4, 0, 6.0, get_pcvar_float(cvarsData[cvar_take_damage_hud_time]), 0.0, 0.0);
	ShowSyncHudMsg(attacker, hudObjects[hudObjectDamage], "%i^n", floatround(damage, floatround_round));

	return HAM_IGNORED;
}

public heGrenadeThink(entity)
{
	// Return if invalid entity or grenade is not HE.
	if (!pev_valid(entity) || !isHeGrenade(entity))
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

	if (!is_user_connected(index) || is_user_bot(index))
	{
		return;
	}

	// We dont want to mess with the knife, all players should have it at all times.
	if (weapon == CSW_KNIFE)
	{
		return;
	}

	// Check if player is holding weapon he shouldnt have.
	if (!((1 << weapon) & userData[index][dataAllowedWeapons]))
	{
		// Take away the weapon.
		strip_user_weapon(index, weapon);
		
		return;
	}
}

public knifeDeploy(entity)
{
	new index = pev(entity, pev_owner);

	// Block if somehow the player is dead.
	if (!is_user_alive(index))
	{
		return;
	}

	// Block if player is not on last level or its not a warmup.
	if (!warmupData[warmupEnabled] || userData[index][dataLevel] != maxLevel)
	{
		return;
	}

	// Block if warmup weapon is not a wand.
	if (warmupData[warmupEnabled] && get_pcvar_num(cvarsData[cvar_warmup_weapon]) != -2)
	{
		return;
	}

	// Block if wands are disabled.
	if (!get_pcvar_num(cvarsData[cvar_wand_enabled]))
	{
		return;
	}
	
	// Set the wand model.
	setWandModels(index);
	setWeaponAnimation(index, 3);
}

public playerDeathEvent()
{
	new victim = read_data(2);

	// Return if victim is a bot or hltv.
	if (is_user_bot(victim) || is_user_hltv(victim))
	{
		return;
	}

	// Prevent weapon-drop to the floor.
	removePlayerWeapons(victim);

	if (gungameEnded)
	{
		removeIdleCheck(victim);

		return;
	}

	// Respawn player.
	if (warmupData[warmupEnabled])
	{
		respawnPlayer(victim, get_pcvar_float(cvarsData[cvar_warump_respawn_interval]));
	}
	else
	{
		respawnPlayer(victim, get_pcvar_float(cvarsData[cvar_respawn_interval]));
	}

	// Remove grenade task if present.
	if (task_exists(victim + TASK_GIVEGRENADE))
	{
		remove_task(victim + TASK_GIVEGRENADE);
	}

	removeHud(victim);
	
	userData[victim][dataCombo] = 0;
	userData[victim][dataAllowedWeapons] = 0;

	new killer = read_data(1),
		weapon[12],
		killerTeam = get_user_team(killer),
		victimTeam = get_user_team(victim);

	read_data(4, weapon, charsmax(weapon));

	// Handle suicide.
	if (killer == victim)
	{
		new oldLevel;

		switch(gameMode)
		{
			case modeNormal:
			{
				oldLevel = userData[victim][dataLevel];

				decrementUserWeaponKills(victim, 1, true);

				if (userData[victim][dataLevel] < oldLevel)
				{
					ColorChat(0, RED, "%s^x01 Gracz^x04 %n^x01 popelnil samobojstwo i spadl do poziomu^x04 %i (%s)^x01.",
						chatPrefix,
						victim,
						userData[victim][dataLevel],
						customWeaponNames[userData[victim][dataLevel]]);
				}
			}
			
			case modeTeamplay:
			{
				oldLevel = tpData[tpTeamLevel][victimTeam - 1];

				decrementTeamWeaponKills(victimTeam, 1, true);

				if (tpData[tpTeamLevel][victimTeam - 1] < oldLevel)
				{
					ColorChat(0, RED, "%s^x01 Przez samobojstwo gracza^x04 %n^x01 druzyna^x04 %s^x01 spadla do poziomu^x04 %i (%s)^x01.",
						chatPrefix,
						victim,
						teamNames[victimTeam - 1],
						tpData[tpTeamLevel][victimTeam - 1],
						customWeaponNames[tpData[tpTeamLevel][victimTeam - 1]]);
				}
			}
		}
		
		return;
	}

	// End gungame if user/team has reached max level.
	if (gameMode == modeNormal && userData[killer][dataLevel] == maxLevel)
	{
		endGunGame(killer);
		
		return;
	}
	else if (gameMode == modeTeamplay)
	{
		if (tpData[tpTeamLevel][0] == maxLevel || tpData[tpTeamLevel][1] == maxLevel)
		{
			endGunGame(killer);

			return;
		}
	}

	// Handle killing on spawn protection.
	if (get_pcvar_num(cvarsData[cvar_spawn_protection_type]))
	{
		if (userData[victim][dataSpawnProtection])
		{
			// Remove protection task if present.
			if (task_exists(victim + TASK_SPAWNPROTECTION))
			{
				remove_task(victim + TASK_SPAWNPROTECTION);
			}

			// Toggle off respawn protection.
			toggleSpawnProtection(victim, false);

			return;
		}
	}
	
	if (equal(weapon, "knife"))
	{
		// Block leveling up if player is on HE level and killed someone with a knife.
		if (weaponsData[userData[killer][dataLevel]][weaponCSW] == CSW_HEGRENADE)
		{
			return;
		}
		
		// Update stats.
		userData[killer][dataKnifeKills]++;

		if (userData[victim][dataLevel])
		{
			switch(gameMode)
			{
				case modeNormal: decrementUserLevel(victim, 1);
				case modeTeamplay:
				{
					if (get_pcvar_num(cvarsData[cvar_knife_kill_level_down_teamplay]))
					{
						decrementTeamLevel(victimTeam, 1);
					}
				}
			}

			ColorChat(victim, RED, "%s^x01 Zostales zabity z kosy przez^x04 %n^x01. %s spadl do^x04 %i^x01.",
				chatPrefix,
				killer,
				gameMode == modeNormal ? "Twoj poziom" : "Poziom Twojej druzyny",
				tpData[tpTeamLevel][victimTeam]);
		}

		// Handle instant-level-up when killing with knife.
		if (get_pcvar_num(cvarsData[cvar_knife_kill_instant_levelup]))
		{
			switch(gameMode)
			{
				case modeNormal: incrementUserLevel(killer, get_pcvar_num(cvarsData[cvar_knife_kill_reward]), true);
				case modeTeamplay: incrementTeamLevel(killerTeam, get_pcvar_num(cvarsData[cvar_knife_kill_reward]), true);
			}
		}
		else
		{
			switch(gameMode)
			{
				case modeNormal: incrementUserWeaponKills(killer, get_pcvar_num(cvarsData[cvar_knife_kill_reward]));
				case modeTeamplay: incrementTeamWeaponKills(killerTeam, get_pcvar_num(cvarsData[cvar_knife_kill_reward]));
			}
		}
	}
	else
	{
		switch(gameMode)
		{
			case modeNormal: incrementUserWeaponKills(killer, 1);
			case modeTeamplay: incrementTeamWeaponKills(killerTeam, 1);
		}

		// Notify about killer's health left.
		ColorChat(victim, RED, "%s^x01 Zabity przez^x04 %n^x01 (^x04%i^x01 HP)", chatPrefix, killer, get_user_health(killer));
	}

	// Update stats.
	if (read_data(3))
	{
		userData[killer][dataHeadshots]++;
	}
	
	userData[killer][dataKills]++;

	// Handle ammo refill.
	switch(gameMode)
	{
		case modeNormal:
		{
			switch(get_pcvar_num(cvarsData[cvar_refill_weapon_ammo]))
			{
				case 1: refillAmmo(killer); // Killer
				case 2: // Vips only
				{
					if (gg_get_user_vip(killer))
					{
						refillAmmo(killer);
					}
				}
			}
		}

		case modeTeamplay:
		{
			switch (get_pcvar_num(cvarsData[cvar_refill_weapon_ammo_teamplay]))
			{
				case 1: refillAmmo(killerTeam, true); // Whole team
				case 2: refillAmmo(killer); // Just the killer
				case 3: // Vips only
				{
					if (gg_get_user_vip(killer))
					{
						refillAmmo(killer);
					}
				}
			}
		}
	}
}

public playerSpawn(index)
{
	// Return if gungame has ended or player isnt alive.
	if (!is_user_alive(index) || gungameEnded)
	{
		return;
	}

	if (warmupData[warmupEnabled])
	{
		// Give weapons to player.
		giveWarmupWeapons(index);

		set_user_health(index, get_pcvar_num(cvarsData[cvar_warmup_health]));
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
		set_task(get_pcvar_float(cvarsData[cvar_spawn_protection_time]), "spawnProtectionOff", index + TASK_SPAWNPROTECTION);

		// Set task to chcek if player is AFK.
		set_task(get_pcvar_float(cvarsData[cvar_idle_check_interval]), "checkIdle", index + TASK_IDLECHECK, .flags = "b");

		ExecuteForward(forwardHandles[forwardPlayerSpawned], forwardReturnDummy, index);
	}
}

public sayHandle(msgId, msgDest, msgEnt)
{
	new index = get_msg_arg_int(1);

	// Return if sender is not connected anymore.
	if (!is_user_connected(index))
	{
		return PLUGIN_CONTINUE;
	}

	new chatString[2][192],
		weaponName[33];

	// Get message arguments.
	get_msg_arg_string(2, chatString[0], charsmax(chatString[]));

	// Replace "knife" with "wand".
	formatex(weaponName, charsmax(weaponName), (userData[index][dataLevel] == maxLevel && get_pcvar_num(cvarsData[cvar_wand_enabled])) ? "Rozdzka" : customWeaponNames[userData[index][dataLevel]]);

	if (equal(chatString[0], "#Cstrike_Chat_All"))
	{
		// Get message arguments.
		get_msg_arg_string(4, chatString[0], charsmax(chatString[]));
		
		// Set argument to empty string.
		set_msg_arg_string(4, "");

		// Format new message to be sent.
		if (gameMode == modeNormal)
		{
			formatex(chatString[1], charsmax(chatString[]), "^x04[%i Lvl (%s)]^x03 %n^x01 :  %s", userData[index][dataLevel] + 1, weaponName, index, chatString[0]);
		}
		else
		{
			formatex(chatString[1], charsmax(chatString[]), "^x04[%s]^x03 %n^x01 :  %s", weaponName, index, chatString[0]);
		}
	}
	else // Format new message to be sent.
	{
		if (gameMode == modeNormal)
		{
			formatex(chatString[1], charsmax(chatString[]), "^x04[%i Lvl (%s)]^x01 %s", userData[index][dataLevel] + 1, weaponName, chatString[0]);
		}
		else
		{
			formatex(chatString[1], charsmax(chatString[]), "^x04[%s]^x01 %s", weaponName, chatString[0]);
		}
	}

	// Send new message.
	set_msg_arg_string(2, chatString[1]);

	return PLUGIN_CONTINUE;
}

public sayCustomCommandHandle(index)
{
	new message[MAX_CHARS],
		command[MAX_CHARS];

	// Remove quotes from message.
	getChatMessageArguments(message, charsmax(message));
	
	// Retrieve command from message.
	getFirstArgument(command, charsmax(command), message, charsmax(message));

	// Show player info if commands are matching.
	if (containi(command, lookupCommand) > -1)
	{
		showPlayerInfo(index, getPlayerByName(message));
	}

	return PLUGIN_CONTINUE;
}

public textGrenadeMessage(msgid, dest, id)
{
	// Return if text is not the one we are looking for.
	if (get_msg_args() != 5 || get_msg_argtype(5) != ARG_STRING)
	{
		return PLUGIN_CONTINUE;
	}

	static argumentText[MAX_CHARS - 1];

	// Get message argument.
	get_msg_arg_string(5, argumentText, charsmax(argumentText));

	// Return if it is not the one we are looking for.
	if (!equal(argumentText, "#Fire_in_the_hole"))
	{
		return PLUGIN_CONTINUE;
	}

	// Get message argument.
	get_msg_arg_string(2, argumentText, charsmax(argumentText));

	// Return if player is not alive.
	if (!is_user_alive(str_to_num(argumentText)))
	{
		return PLUGIN_CONTINUE;
	}

	// Block message.
	return PLUGIN_HANDLED;
}

public audioGrenadeMessage()
{
	// Return if this sound is not the one we are interesed in.
	if (get_msg_args() != 3 || get_msg_argtype(2) != ARG_STRING)
	{
		return PLUGIN_CONTINUE;
	}

	new argumentText[MAX_CHARS - 10];

	// Get message arguments.
	get_msg_arg_string(2, argumentText, charsmax(argumentText));

	// Return if it is not the one we are looking for.
	if (!equal(argumentText[1], "!MRAD_FIREINHOLE"))
	{
		return PLUGIN_CONTINUE;
	}

	// Block sending audio message.
	return PLUGIN_HANDLED;
}

public displayWarmupTimer()
{
	// Return if warmup has ended.
	if (!warmupData[warmupEnabled])
	{
		return;
	}

	// Decrement warmup timer.
	warmupData[warmupTimer]--;

	if (warmupData[warmupTimer] >= 0)
	{
		// Play timer tick sound.
		playSound(0, soundTimerTick, -1, false);

		// Get warmup weapon name index if not done so yet.
		if (warmupData[warmupWeaponNameIndex] == -1)
		{
			getWarmupWeaponName();
		}
		
		// Display warmup hud.
		set_hudmessage(warmupHudColors[0], warmupHudColors[1], warmupHudColors[2], -1.0, 0.1, 0, 6.0, 0.6, 0.2, 0.2);
		
		if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -3)
		{
			ForPlayers(i)
			{
				if (!is_user_alive(i) || is_user_hltv(i) || is_user_bot(i) || userData[i][dataWarmupWeapon] == -1)
				{
					continue;
				}

				ShowSyncHudMsg(i, hudObjects[hudObjectWarmup], "[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]",
					warmupData[warmupTimer],
					customWeaponNames[userData[i][dataWarmupCustomWeaponIndex]]);
			}
		}
		else
		{
			new weaponName[MAX_CHARS];

			// Warmup weapon is a wand?
			if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -2)
			{
				formatex(weaponName, charsmax(weaponName), "Rozdzki");
			}
			else
			{
				if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -1)
				{
					copy(weaponName, charsmax(weaponName), customWeaponNames[warmupData[warmupWeaponIndex]]);
				}
				else
				{
					copy(weaponName, charsmax(weaponName), customWeaponNames[warmupData[warmupWeaponNameIndex]]);
				}
			}

			ShowSyncHudMsg(0, hudObjects[hudObjectWarmup], "[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]", warmupData[warmupTimer], weaponName);
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
	new menuIndex = menu_create("Lista broni:^n[Bron ^t-^tpoziom  ^t-^t ilosc wymaganych zabojstw]", "listWeaponsMenu_handler"),
		menuItem[MAX_CHARS * 3],
		weaponName[MAX_CHARS];

	ForArray(i, weaponsData)
	{
		if (i == maxLevel && get_pcvar_num(cvarsData[cvar_wand_enabled]))
		{
			formatex(weaponName, charsmax(weaponName), "Rozdzka");
		}
		else
		{
			copy(weaponName, charsmax(weaponName), customWeaponNames[i]);
		}

		formatex(menuItem, charsmax(menuItem), "[%s - %i lv. - %i (%i)]", weaponName, i + 1, weaponsData[i][weaponKills], weaponsData[i][weaponTeamKills]);

		// Add item to menu.
		menu_additem(menuIndex, menuItem);
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
	if (!is_user_connected(index))
	{
		return PLUGIN_HANDLED;
	}

	// Return if top players data was not loaded yet.
	if (!topData[topDataLoaded])
	{
		ColorChat(index, RED, "%s^x01 Topka nie zostala jeszcze zaladowana.", chatPrefix);
		return PLUGIN_CONTINUE;
	}

	// Create top players motd if this is the first time someone has used command on this map.
	if (!topData[topMotdCreated])
	{
		createTopPlayersMotd();
	}

	// Display motd.
	show_motd(index, topData[topMotdCode], topData[topMotdName]);

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
	if (!is_user_connected(winner) || userData[winner][dataLevel] >= get_pcvar_num(cvarsData[cvar_warmup_level_reward]))
	{
		return;
	}

	// For regular players add VIP for this map, for VIPs add 3 levels.
	if (gg_get_user_vip(winner))
	{
		incrementUserLevel(winner, get_pcvar_num(cvarsData[cvar_warmup_level_reward]) - userData[winner][dataLevel] - 1, false);
	}
	else
	{
		gg_set_user_vip(winner, true);
	}
}

public giveHeGrenade(taskIndex)
{
	new index = taskIndex - TASK_GIVEGRENADE;

	// Return if player is not alive or this type of grenade is none of his weapons.
	if (!is_user_alive(index) || !warmupData[warmupEnabled] && weaponsData[userData[index][dataLevel]][weaponCSW] != CSW_HEGRENADE || warmupData[warmupEnabled] && warmupData[warmupWeaponIndex] == CSW_HEGRENADE)
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
	if (!is_user_alive(index) || weaponsData[userData[index][dataLevel]][weaponCSW] != CSW_KNIFE)
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
	if (!is_user_alive(index))
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
	if (!is_user_alive(index))
	{
		return;
	}

	new currentOrigin[3];

	// Get user position.
	get_user_origin(index, currentOrigin);

	if (!userData[index][dataLastOrigin][0] && !userData[index][dataLastOrigin][1] && !userData[index][dataLastOrigin][2])
	{
		// Handle position update.
		ForRange(i, 0, 2)
		{
			userData[index][dataLastOrigin][i] = currentOrigin[i];
		}

		return;
	}

	// Get distance from last position to current position.
	new lastOrigin[3];
	copy(lastOrigin, sizeof(lastOrigin), userData[index][dataLastOrigin]); // Workaround with const argument in get_distance.

	new distance = get_distance(lastOrigin, currentOrigin);

	// Handle position update.
	ForRange(i, 0, 2)
	{
		userData[index][dataLastOrigin][i] = currentOrigin[i];
	}

	if (distance < get_pcvar_num(cvarsData[cvar_idle_max_distance]))
	{
		// Slap player if he's camping, make sure not to kill him.
		if (++userData[index][dataIdleStrikes] >= get_pcvar_num(cvarsData[cvar_idle_max_strikes]))
		{
			ForRange(i, 0, 1)
			{
				user_slap(index, !i ? (get_user_health(index) > get_pcvar_num(cvarsData[cvar_idle_slap_power]) ? get_pcvar_num(cvarsData[cvar_idle_slap_power]) : 0) : 0);
			}
		}
	}
	else
	{
		// Set user strikes back to 0.
		userData[index][dataIdleStrikes] = 0;
		
		// Set user last position to 0.
		ForRange(i, 0, 2)
		{
			userData[index][dataLastOrigin][i] = 0;
		}
	}
}

public clientRespawn(taskIndex)
{
	new index = taskIndex - TASK_RESPAWN;

	// Return if player is not connected anymore.
	if (!is_user_connected(index))
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
	if (!is_user_connected(index) || gungameEnded)
	{
		return;
	}

	// Remove tasks if they exists somehow.
	if (is_user_alive(index))
	{
		if (task_exists(index + TASK_RESPAWN))
		{
			remove_task(index + TASK_RESPAWN);
		}

		if (task_exists(index + TASK_NOTIFY))
		{
			remove_task(index + TASK_NOTIFY);
		}

		return;
	}

	// Print respawn-time info.
	client_print(index, print_center, "Odrodzenie za: %i", userData[index][dataTimeToRespawn]);

	// Decrease respawn time.
	userData[index][dataTimeToRespawn]--;
}

public displayHud(taskIndex)
{
	new index = taskIndex - TASK_DISPLAYHUD;

	if (!is_user_alive(index))
	{
		return;
	}

	new leader = getGameLeader(),
		leaderData[MAX_CHARS * 3],
		nextWeapon[25];

	// Format leader's data if available.
	if (leader <= 0)
	{
		formatex(leaderData, charsmax(leaderData), "^nLider: Brak");
	}
	else
	{
		// We dont talk about that. Ever.
		if (gameMode == modeNormal)
		{
			formatex(leaderData, charsmax(leaderData), "^nLider: %n :: %i poziom [%s - %i/%i]",
					leader,
					userData[leader][dataLevel] + 1,
					userData[leader][dataLevel] == maxLevel ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[leader][dataLevel]]) : customWeaponNames[userData[leader][dataLevel]],
					userData[leader][dataWeaponKills],
					weaponsData[userData[leader][dataLevel]][weaponKills]);
		}
		else
		{
			formatex(leaderData, charsmax(leaderData), "^nLider: %s :: %i poziom [%s - %i/%i]",
					teamNames[leader],
					userData[leader][dataLevel] + 1,
					userData[leader][dataLevel] == maxLevel ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[leader][dataLevel]]) : customWeaponNames[userData[leader][dataLevel]],
					userData[leader][dataWeaponKills],
					weaponsData[userData[leader][dataLevel]][weaponTeamKills]);
		}
	}

	// Format next weapon name if available, change knife to wand if enabled so.
	if (userData[index][dataLevel] == sizeof(weaponsData) - 2)
	{
		formatex(nextWeapon, charsmax(nextWeapon), get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[index][dataLevel] + 1]);
	}
	else
	{
		formatex(nextWeapon, charsmax(nextWeapon), isOnLastLevel(index) ? "Brak" : customWeaponNames[userData[index][dataLevel] + 1]);
	}

	// Display hud.
	set_hudmessage(hudColors[0], hudColors[1], hudColors[2], -1.0, 0.02, 0, 6.0, hudDisplayInterval + 0.1, 0.0, 0.0);
	
	if (gameMode == modeNormal)
	{
		ShowSyncHudMsg(index, hudObjects[hudObjectDefault], "Poziom: %i/%i [%s - %i/%i] :: Zabic z rzedu: %i^nNastepna bron: %s%s",
			userData[index][dataLevel] + 1,
			sizeof(weaponsData),
			isOnLastLevel(index) ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[leader][dataLevel]]) : customWeaponNames[userData[index][dataLevel]],
			userData[index][dataWeaponKills],
			weaponsData[userData[index][dataLevel]][weaponKills],
			userData[index][dataCombo],
			nextWeapon,
			leaderData);
	}
	else
	{
		new team = get_user_team(index) - 1;

		ShowSyncHudMsg(index, hudObjects[hudObjectDefault], "Poziom: %i/%i [%s - %i/%i]^nNastepna bron: %s%s",
			tpData[tpTeamLevel][team] + 1,
			sizeof(weaponsData),
			isOnLastLevel(index) ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[leader][dataLevel]]) : customWeaponNames[userData[index][dataLevel]],
			tpData[tpTeamKills][team],
			weaponsData[userData[index][dataLevel]][weaponTeamKills],
			nextWeapon,
			leaderData);
	}
}

// Respawn player.
public respawnPlayerOnJoin(taskIndex)
{
	new index = taskIndex - TASK_RESPAWN_ON_JOIN;

	respawnPlayer(index, 0.1);
}

/*
		[ Database ]
*/

connectDatabase()
{
	new mysqlRequest[MAX_CHARS * 10];

	// Create mysql tuple.
	dbData[sqlHandle] = SQL_MakeDbTuple(dbData[dbHost], dbData[dbUser], dbData[dbPass], dbData[dbDbase]);

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest),
		"CREATE TABLE IF NOT EXISTS `gungame` \
			(`name` VARCHAR(35) NOT NULL, \
			`wins` INT(6) NOT NULL DEFAULT 0, \
			`knife_kills` INT(6) NOT NULL DEFAULT 0, \
			`kills` INT(6) NOT NULL DEFAULT 0, \
			`headshot_kills` INT(6) NOT NULL DEFAULT 0, \
		PRIMARY KEY (`name`));");

	// Send request to database.
	SQL_ThreadQuery(dbData[sqlHandle], "connectDatabaseHandler", mysqlRequest);
}

public connectDatabaseHandler(failState, Handle:query, error[], errorNumber, data[], dataSize)
{
	// Connection has succeded?
	dbData[sqlLoaded] = bool:(failState == TQUERY_SUCCESS);

	// Throw log to server's console if error occured.
	if (!dbData[sqlLoaded])
	{
		log_amx("Database connection status: Not connected. Error (%i): %s", errorNumber, error);
	}

	return PLUGIN_CONTINUE;
}

getUserData(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysqlRequest[MAX_CHARS * 3],
		data[2];

	data[0] = index;

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest), "SELECT * FROM `gungame` WHERE `name` = '%s';", userData[index][dataSafeName]);

	// Send request to database.
	SQL_ThreadQuery(dbData[sqlHandle], "getUserInfoDataHandler", mysqlRequest, data, charsmax(data));
}

// Read user wins from database.
public getUserInfoDataHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	new index = data[0];

	if (SQL_NumRows(query))
	{
		userData[index][dataWins] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		userData[index][dataKnifeKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "knife_kills"));
		userData[index][dataHeadshots] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "headshot_kills"));
		userData[index][dataKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
	}
	else
	{
		insertUserData(index);
	}
}

insertUserData(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysqlRequest[MAX_CHARS * 10];

	// Format request.
	formatex(mysqlRequest, charsmax(mysqlRequest),
		"INSERT INTO `gungame` \
			(`name`, `wins`, `knife_kills`, `kills`, `headshot_kills`) \
		VALUES \
			('%s', %i, %i, %i, %i);", userData[index][dataSafeName], userData[index][dataWins], userData[index][dataKnifeKills], userData[index][dataKills], userData[index][dataHeadshots]);

	// Send request.
	SQL_ThreadQuery(dbData[sqlHandle], "ignoreHandle", mysqlRequest);
}

updateUserData(index)
{
	if (!is_user_connected(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysqlRequest[MAX_CHARS * 10];

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest),
		"UPDATE `gungame` SET \
			`name` = '%s',\
			`wins` = %i,\
			`knife_kills` = %i,\
			`kills` = %i,\
			`headshot_kills` = %i \
		WHERE \
			`name` = '%s';", userData[index][dataSafeName], userData[index][dataWins], userData[index][dataKnifeKills], userData[index][dataKills], userData[index][dataHeadshots], userData[index][dataSafeName]);

	// Send request.
	SQL_ThreadQuery(dbData[sqlHandle], "ignoreHandle", mysqlRequest);
}

// Pretty much ignore any data that database sends back.
public ignoreHandle(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	return PLUGIN_CONTINUE;
}

loadTopPlayers()
{
	new mysqlRequest[MAX_CHARS * 3];

	// Format mysql request.
	formatex(mysqlRequest, charsmax(mysqlRequest), "SELECT * FROM `gungame` ORDER BY `wins` DESC LIMIT %i;", topPlayersDisplayed + 1);

	// Send request to database.
	SQL_ThreadQuery(dbData[sqlHandle], "loadTopPlayersHandler", mysqlRequest);
}

public loadTopPlayersHandler(failState, Handle:query, error[], errorNumber, data[], dataSize)
{
	new iterator;

	// Load top players while there are any.
	while (SQL_MoreResults(query))
	{
		// Get top player name.
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), topPlayers[iterator][topNames], MAX_CHARS - 1);
		
		// Assign his info to variables.
		topPlayers[iterator][topWins] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		topPlayers[iterator][topKnifeKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "knife_kills"));
		topPlayers[iterator][topHeadshots] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "headshot_kills"));
		topPlayers[iterator][topKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));

		// Iterate loop.
		iterator++;

		// Go to next result.
		SQL_NextRow(query);
	}

	// Database laoded successfully.
	topData[topDataLoaded] = true;

	// Create motd.
	createTopPlayersMotd();
}

/*
		[ FUNCTIONS ]
*/

saveOnDisconnect(index)
{
	ArrayPushCell(disconnectedPlayersData[dcDataLevel], userData[index][dataLevel]);
	ArrayPushCell(disconnectedPlayersData[dcDataWeaponKills], userData[index][dataWeaponKills]);
	ArrayPushString(disconnectedPlayersData[dcDataName], userData[index][dataName]);
}

getOnConnect(index)
{
	static name[MAX_CHARS];

	ForDynamicArray(i, disconnectedPlayersData[dcDataName])
	{
		ArrayGetString(disconnectedPlayersData[dcDataName], i, name, charsmax(name));

		// Not our guy.
		if (!equal(name, userData[index][dataName]))
		{
			continue;
		}

		// Set new level and weapon kills.
		userData[index][dataLevel] = ArrayGetCell(disconnectedPlayersData[dcDataLevel], i);
		userData[index][dataWeaponKills] = ArrayGetCell(disconnectedPlayersData[dcDataWeaponKills], i);

		// Delete data from dynamic arrays.
		ArrayDeleteItem(disconnectedPlayersData[dcDataLevel], i);
		ArrayDeleteItem(disconnectedPlayersData[dcDataWeaponKills], i);
		ArrayDeleteItem(disconnectedPlayersData[dcDataName], i);

		break;
	}
}

getUserNameData(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Get player's name once, so we dont do that every time we need that data.
	get_user_name(index, userData[index][dataName], MAX_CHARS - 1);

	// Clamp down player's name so we can use that to prevent char-overflow in HUD etc.
	clampDownClientName(index, userData[index][dataShortName], MAX_CHARS - 1, maxNicknameLength, nicknameReplaceToken);

	// Get player's name to mysql-request-safe state.
	escapeString(userData[index][dataName], userData[index][dataSafeName], MAX_CHARS * 2);
}

escapeString(const source[], output[], length)
{
	copy(output, length, source);

	replace_all(output, length, "\\", "\\\\");
	replace_all(output, length, "\0", "\\0");
	replace_all(output, length, "\n", "\\n");
	replace_all(output, length, "\r", "\\r");
	replace_all(output, length, "\x1a", "\Z");
	replace_all(output, length, "'", "\'");
	replace_all(output, length, "`", "\`");
	replace_all(output, length, "^"", "\^"");
}

loadSqlConfig()
{
	new const sqlConfigPath[] = "addons/amxmodx/configs/gg_sql.cfg";

	new const sqlConfigLabels[][] =
	{
		"gg_sql_host",
		"gg_sql_user",
		"gg_sql_pass",
		"gg_sql_db"
	};

	if (!file_exists(sqlConfigPath))
	{
		dbData[sqlConfigFound] = false;

		return;
	}

	new fileHandle = fopen(sqlConfigPath, "r"),
		lineContent[MAX_CHARS * 10],
		key[MAX_CHARS * 5],
		value[MAX_CHARS * 5],
		entries;

	while (fileHandle && !feof(fileHandle) && entries < sizeof(sqlConfigLabels))
	{
		// Read one line at a time.
		fgets(fileHandle, lineContent, charsmax(lineContent));
		
		// Replace newlines with a null character.
		replace(lineContent, charsmax(lineContent), "^n", "");
		
		// Blank line or comment.
		if (!lineContent[0] || lineContent[0] == ';')
		{
			continue;
		}
		
		// Get key and value.
		strtok(lineContent, key, charsmax(key), value, charsmax(value), '=');
		
		// Trim spaces.
		trim(key);
		trim(value);

		remove_quotes(value);

		ForArray(i, sqlConfigLabels)
		{
			if (!equal(key, sqlConfigLabels[i]))
			{
				continue;
			}

			switch(entries)
			{
				case 0: copy(dbData[dbHost], MAX_CHARS * 2, value);
				case 1: copy(dbData[dbUser], MAX_CHARS * 2, value);
				case 2: copy(dbData[dbPass], MAX_CHARS * 2, value);
				case 3: copy(dbData[dbDbase], MAX_CHARS * 2, value);
			}

			entries++;
		
			break;
		}
	}

	dbData[sqlConfigFound] = true;
}

loadGameCvars()
{
	ForArray(i, gameCvars)
	{
		set_cvar_num(gameCvars[i][0], str_to_num(gameCvars[i][1]));
	}
}

bool:isOnLastLevel(index)
{
	return bool:(userData[index][dataLevel] == maxLevel);
}

// To be used in natives only.
isPlayerConnected(index)
{
	// Throw error and return error value if player is not connected.
	if (!is_user_connected(index))
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
		topData[topMotdLength] += formatex(topData[topMotdCode][topData[topMotdLength]], charsmax(topData[topMotdCode]), topPlayersMotdHTML[i]);
	}

	ForRange(i, 0, topPlayersDisplayed - 1)
	{
		// Continue if player has no wins at all.
		if (!topPlayers[i][topWins])
		{
			continue;
		}

		// Add HTML to motd.
		topData[topMotdLength] += formatex(topData[topMotdCode][topData[topMotdLength]], charsmax(topData[topMotdCode]),
			"<tr>\
				<td>\
					<b>\
						<h4>%d</h4>\
					</b>\
				<td>\
				\
				<h4>%s</h4>\
				\
				<td>\
					<h4>%d</h4>\
				<td>\
				\
				<td>\
					<h4>%d</h4>\
				</td>\
				\
				<td>\
					<h4>%d</h4>\
				</td>\
			</tr>",
			i + 1, topPlayers[i][topNames], topPlayers[i][topWins], topPlayers[i][topKnifeKills], floatround(topPlayers[i][topHeadshots] / topPlayers[i][topKills] * 100.0));

		playersDisplayed++;
	}

	// Format motd title.
	formatex(topData[topMotdName], charsmax(topData[topMotdName]), "Top %i graczy GunGame", playersDisplayed);

	topData[topMotdCreated] = true;
}

removeIdleCheck(index)
{
	// AFK-check task exists?
	if (task_exists(index + TASK_IDLECHECK))
	{
		// Remove AFK-check task.
		remove_task(index + TASK_IDLECHECK);
		
		// Set last user position to 0 to prevent bugs with respawning close to death-place.
		ForRange(i, 0, 2)
		{
			userData[index][dataLastOrigin][i] = 0;
		}
	
		// Set AFK-strikes to zero.
		userData[index][dataIdleStrikes] = 0;
	}
}

giveWarmupWeapons(index)
{
	// Return if player is not alive.
	if (!is_user_alive(index))
	{
		return;
	}

	// Strip weapons.
	removePlayerWeapons(index);

	userData[index][dataAllowedWeapons] = (1 << CSW_KNIFE);

	// Give knife as a default weapon.
	give_item(index, "weapon_knife");
	
	if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) > -1)
	{
		new weaponName[MAX_CHARS - 1],
			weapon = get_pcvar_num(cvarsData[cvar_warmup_weapon]);
	
		userData[index][dataAllowedWeapons] |= (1 << weapon);

		// Get warmup weapon entity classname.
		get_weaponname(weapon, weaponName, charsmax(weaponName));

		// Set weapon backpack ammo to 100.
		cs_set_user_bpammo(index, weapon, 100);
	}

	// Add random warmup weapon multiple times.
	else if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -1)
	{
		new weapon = get_weaponid(weaponEntityNames[warmupData[warmupWeaponIndex]]);

		userData[index][dataAllowedWeapons] |= (1 << weapon);

		// Add weapon.
		give_item(index, weaponEntityNames[warmupData[warmupWeaponIndex]]);

		// Set weapon bp ammo to 100.
		cs_set_user_bpammo(index, weapon, 100);
	}

	// Set wand model.
	else if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -2)
	{
		setWandModels(index);
	}

	// Add random weapon.
	else if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == -3)
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
	if (string[0] == '^"')
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
	if (!pev_valid(entity))
	{
		return false;
	}

	new classname[9];

	// Get classname of entity.
	pev(entity, pev_classname, classname, charsmax(classname));

	// Return if classname is not grenade.
	if (!equal(classname, "grenade") || get_pdata_int(entity, 96) & 1 << 8)
	{
		return false;
	}

	// Return if grenade type is not HE.
	if (!(get_pdata_int(entity, 114) & 1 << 1))
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
		while ((entity = find_ent_by_class(entity, droppedWeaponsClassnames[i])))
		{
			remove_entity(entity);
		}
	}
}

showPlayerInfo(index, target)
{
	if (is_user_connected(target))
	{
		ColorChat(index, RED, "%s^x01 Gracz ^x04%n^x01 jest na poziomie^x04 %i^x01 [^x04%s^x01 - ^x04%i^x01/^x04%i^x01]. Wygral ^x04%i^x01 razy. Status uslugi:^x04 %s^x01.",
			chatPrefix,
			target,
			userData[target][dataLevel] + 1,
			isOnLastLevel(target) ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[target][dataLevel]]) : customWeaponNames[userData[target][dataLevel]],
			userData[target][dataWeaponKills],
			weaponsData[userData[target][dataLevel]][gameMode == modeNormal ? weaponKills : weaponTeamKills],
			userData[target][dataWins],
			gg_get_user_vip(target) ? "VIP" : "Brak");
	}
	else
	{
		ColorChat(index, RED, "%s^x01 %s", chatPrefix, target == -1 ? "Wiecej niz jeden gracz pasuje do podanego nicku." : " Gracz o tym nicku nie zostal znaleziony.");
	}
}

randomizeSoundIndex(soundType)
{
	// Create dynamic array to store valid sound indexes.
	new Array:soundIndexes = ArrayCreate(1, 1);

	// Iterate through sounds array to find valid sounds, then add them to dynamic array.
	ForRange(j, 0, maxSounds - 1)
	{
		if (strlen(soundsData[soundType][j]))
		{
			ArrayPushCell(soundIndexes, j);
		}
	}

	// Randomize valid index read from dynamic array.
	new soundIndex = ArrayGetCell(soundIndexes, random_num(0, ArraySize(soundIndexes) - 1));
	
	// Get rid of array to save data space.
	ArrayDestroy(soundIndexes);

	return soundIndex;
}

playSound(index, soundType, soundIndex, bool:emitSound)
{
	// Sound index is set to random?
	if (soundIndex < 0)
	{
		soundIndex = randomizeSoundIndex(soundType);
	}

	// Emit sound directly from entity?
	if (emitSound)
	{
		emit_sound(index, CHAN_AUTO, soundsData[soundType][soundIndex], soundsVolumeData[soundType][soundIndex], ATTN_NORM, (1 << 8), PITCH_NORM);
	}
	else
	{
		client_cmd(index, "%s ^"%s^"", defaultSoundCommand, soundsData[soundType][soundIndex]);
	}
}

playSoundForTeam(team, soundType, soundIndex, bool:emitSound)
{
	// Sound index is set to random?
	if (soundIndex < 0)
	{
		soundIndex = randomizeSoundIndex(soundType);
	}

	// Emit sound directly from entity?
	if (emitSound)
	{
		ForTeam(i, team)
		{
			emit_sound(i, CHAN_AUTO, soundsData[soundType][soundIndex], soundsVolumeData[soundType][soundIndex], ATTN_NORM, (1 << 8), PITCH_NORM);
		}
	}
	else
	{
		ForTeam(i, team)
		{
			client_cmd(i, "%s ^"%s^"", defaultSoundCommand, soundsData[soundType][soundIndex]);
		}
	}
}

toggleWarmup(bool:status)
{
	warmupData[warmupWeaponNameIndex] = -1;
	warmupData[warmupEnabled] = status;

	setWarmupHud(status);

	// Warmup set to disabled?
	if (!warmupData[warmupEnabled])
	{
		finishGameVote();

		if (gameMode == modeNormal)
		{
			// Get warmup winner based on kills.
			new winner = getWarmupWinner();

			// Set task to reward winner after game restart.
			if (is_user_connected(winner))
			{
				set_task(2.0, "rewardWarmupWinner", winner + TASK_REWARDWINNER);
			}

			ExecuteForward(forwardHandles[forwardGameBeginning], forwardReturnDummy, winner);
		}
		else
		{
			ExecuteForward(forwardHandles[forwardGameBeginning], forwardReturnDummy, -1);
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
		if (get_cvar_num("mp_freezetime"))
		{
			server_cmd("amx_cvar mp_freezetime 0");
		}

		// Remove hud tasks.
		ForPlayers(i)
		{
			if (!is_user_connected(i) || task_exists(i + TASK_DISPLAYHUD))
			{
				continue;
			}
			
			remove_task(i + TASK_DISPLAYHUD);
		}

		// Get random weapon, only if its not a knife.
		warmupData[warmupWeaponIndex] = random_num(0, sizeof(customWeaponNames) - 2);

		// Play warmup start sound.
		playSound(0, soundWarmup, -1, true);

		setGameVote();
	}
}

// Set timer HUD task.
setWarmupHud(bool:status)
{
	if (status)
	{
		set_task(1.0, "displayWarmupTimer");

		warmupData[warmupTimer] = get_pcvar_num(cvarsData[cvar_warmup_duration]);
	}
}

toggleSpawnProtection(index, bool:status)
{
	// Toggle spawn protection on index.
	userData[index][dataSpawnProtection] = status;

	// Toggle godmode.
	if (get_pcvar_num(cvarsData[cvar_spawn_protection_type]))
	{
		set_user_godmode(index, status);
	}

	// Set glowshell to indicate spawn protection. Disable any rendering if status is false.
	if (status)
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
	if (task_exists(index + TASK_DISPLAYHUD))
	{
		remove_task(index + TASK_DISPLAYHUD);
	}
}

respawnPlayer(index, Float:time)
{
	// Player already respawned?
	if (is_user_alive(index))
	{
		return;
	}

	new clientTeam = get_user_team(index);

	// Not interested in spectator and unassigned players.
	if (clientTeam != 1 && clientTeam != 2)
	{
		return;
	}

	// Get respawn time to int.
	new intTime = floatround(time, floatround_round);

	// Set user respawn time to integer value.
	userData[index][dataTimeToRespawn] = intTime;

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
	userData[index][dataCombo] += value;
	userData[index][dataWeaponKills] += value;

	ExecuteForward(forwardHandles[forwardComboStreak], forwardReturnDummy, index, userData[index][dataCombo]);

	// Levelup player if weapon kills are greater than reqiured for his current level.
	while (userData[index][dataWeaponKills] >= weaponsData[userData[index][dataLevel]][weaponKills])
	{
		incrementUserLevel(index, 1, true);
	}
}

incrementTeamWeaponKills(team, value)
{
	tpData[tpTeamKills][team - 1] += value;

	while (tpData[tpTeamKills][team - 1] >= weaponsData[tpData[tpTeamLevel][team - 1]][weaponTeamKills])
	{
		incrementTeamLevel(team, 1, true);
	}
}

// Decrement weapon kills, take care of leveldown.
decrementUserWeaponKills(index, value, bool:levelLose)
{
	userData[index][dataWeaponKills] -= value;

	if (levelLose && userData[index][dataWeaponKills] < 0)
	{
		decrementUserLevel(index, 1);
	}

	if (userData[index][dataWeaponKills] < 0)
	{
		userData[index][dataWeaponKills] = 0;
	}
}

// Decrement weapon kills, take care of leveldown.
decrementTeamWeaponKills(team, value, bool:levelLose)
{
	tpData[tpTeamKills][team - 1] -= value;

	if (tpData[tpTeamKills][team - 1] < 0)
	{
		tpData[tpTeamKills][team - 1] = 0;
	}

	ForTeam(i, team)
	{
		userData[i][dataWeaponKills] = tpData[tpTeamKills][team - 1];
	}

	if (!levelLose)
	{
		return;
	}

	decrementTeamLevel(team, 1);
}

incrementUserLevel(index, value, bool:notify)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	userData[index][dataWeaponKills] -= weaponsData[userData[index][dataLevel]][weaponKills];
	userData[index][dataLevel] = (userData[index][dataLevel] + value > maxLevel ? maxLevel : userData[index][dataLevel] + value);

	// Levelup effect.
	displayLevelupSprite(index);

	// Make sure player's kills are positive.
	if (userData[index][dataWeaponKills] < 0)
	{
		userData[index][dataWeaponKills] = 0;
	}

	// Add weapons for player's current level.
	giveWeapons(index);

	ExecuteForward(forwardHandles[forwardLevelUp], forwardReturnDummy, index, userData[index][dataLevel], -1);

	if (notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Gracz^x04 %n^x01 awansowal na poziom^x04 %i^x01 ::^x04 %s^x01.",
			chatPrefix,
			index,
			userData[index][dataLevel] + 1,
			userData[index][dataLevel] == maxLevel ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[userData[index][dataLevel]]) : customWeaponNames[userData[index][dataLevel]]);
		
		// Play levelup sound.
		playSound(index, soundLevelUp, -1, false);
	}
}

incrementTeamLevel(team, value, bool:notify)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	tpData[tpTeamKills][team - 1] = 0;
	tpData[tpTeamLevel][team - 1] = (tpData[tpTeamLevel][team - 1] + value > maxLevel ? maxLevel : tpData[tpTeamLevel][team - 1] + value);

	ForTeam(i, team)
	{
		userData[i][dataLevel] = tpData[tpTeamLevel][team - 1];
		userData[i][dataWeaponKills] = tpData[tpTeamKills][team - 1];

		// Levelup effect.
		displayLevelupSprite(i);

		// Add weapons.
		giveWeapons(i);
	
		ExecuteForward(forwardHandles[forwardLevelUp], forwardReturnDummy, i, tpData[tpTeamLevel][team - 1], team);
	}

	if (notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Druzyna^x04 %s^x01 awansowala na poziom^x04 %i^x01 ::^x04 %s^x01.",
			chatPrefix,
			teamNames[team - 1],
			tpData[tpTeamLevel][team - 1] + 1,
			tpData[tpTeamLevel][team - 1] == maxLevel ? (get_pcvar_num(cvarsData[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[tpData[tpTeamLevel][team - 1]]) : customWeaponNames[tpData[tpTeamLevel][team - 1]]);
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
	userData[index][dataLevel] = (userData[index][dataLevel] - value < 0 ? 0 : userData[index][dataLevel] - value);
	userData[index][dataWeaponKills] = 0;

	// Play leveldown sound.
	playSound(index, soundLevelDown, -1, false);

	ExecuteForward(forwardHandles[forwardLevelDown], forwardReturnDummy, index, userData[index][dataLevel], -1);
}

decrementTeamLevel(team, value)
{
	// Decrement team level and kills, make sure level is not negative.
	tpData[tpTeamLevel][team - 1] = (tpData[tpTeamLevel][team - 1] - value < 0 ? 0 : tpData[tpTeamLevel][team - 1] - value);
	tpData[tpTeamKills][team - 1] = 0;

	// Update level and kills of players in the team.
	ForTeam(i, team)
	{
		userData[i][dataLevel] = tpData[tpTeamLevel][team - 1];
		userData[i][dataWeaponKills] = tpData[tpTeamKills][team - 1];
	
		ExecuteForward(forwardHandles[forwardLevelDown], forwardReturnDummy, i, tpData[tpTeamLevel][team - 1], team);
	}

	// Play leveldown sound.
	playSoundForTeam(team, soundLevelDown, -1, false);
}

endGunGame(winner)
{
	// Mark gungame as ended.
	gungameEnded = true;

	ExecuteForward(forwardHandles[forwardGameEnd], forwardReturnDummy, winner);

	// Remove hud, and tasks if they exist.
	ForPlayers(i)
	{
		if (!is_user_alive(i) && task_exists(i + TASK_RESPAWN))
		{
			remove_task(i + TASK_RESPAWN);

			if (task_exists(i + TASK_NOTIFY))
			{
				remove_task(i + TASK_NOTIFY);
			}
		}

		removeHud(i);
		updateUserData(i);
	}

	new winMessage[MAX_CHARS * 10],
		tempMessage[MAX_CHARS * 5],
		topPlayers[topPlayersDisplayed + 1],
		index;

	// Set black screen.
	setBlackScreenFade(2);

	// Recursevly set black screen every second so player has it colored no matter what.
	set_task(1.0, "setBlackScreenOn");

	// Update top players.
	loadTopPlayers();

	// Get top players.
	getPlayerByTopLevel(topPlayers, charsmax(topPlayers));

	// Reward winner.
	userData[winner][dataWins]++;

	// Format win message.
	formatex(winMessage, charsmax(winMessage), "%s^nTopowi gracze:^n^n^n^n", chatPrefix);

	// Format top players message.
	ForArray(i, topPlayers)
	{
		index = topPlayers[i];

		if (!is_user_connected(index) || is_user_hltv(index))
		{
			continue;
		}

		formatex(tempMessage, charsmax(tempMessage), "^n^n%i. %s (%i lvl - %s [%i fragow] [wygranych: %i])",
			i + 1,
			userData[index][dataShortName],
			userData[index][dataLevel] + 1,
			customWeaponNames[userData[index][dataLevel]],
			get_user_frags(index),
			userData[index][dataWins]);

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
	if (!is_user_alive(index))
	{
		return;
	}

	// We dont want players to have armor.
	set_user_armor(index, get_pcvar_num(cvarsData[cvar_default_armor_level]));

	// Strip weapons.
	removePlayerWeapons(index);

	// Reset player allowed weapons and add knife.
	userData[index][dataAllowedWeapons] = (1 << CSW_KNIFE);

	// Add wand if player is on last level and such option is enabled.
	if (userData[index][dataLevel] != maxLevel)
	{
		// Add weapon couple of times to make sure backpack ammo is right.
		new csw = get_weaponid(weaponEntityNames[userData[index][dataLevel]]);

		// Add weapon to allowed to carry by player.
		userData[index][dataAllowedWeapons] |= (1 << weaponsData[userData[index][dataLevel]][weaponCSW]);

		give_item(index, weaponEntityNames[userData[index][dataLevel]]);

		if (csw != CSW_HEGRENADE && csw != CSW_KNIFE && csw != CSW_FLASHBANG)
		{
			cs_set_user_bpammo(index, csw, 100);
		}

		// Deploy primary weapon.
		engclient_cmd(index, weaponEntityNames[userData[index][dataLevel]]);

		// Add knife last so the primary weapon gets drawn out (dont switch to powerful weapon fix).
		give_item(index, "weapon_knife");
	}
	else
	{
		// Add knife first, so the models can be set.
		give_item(index, "weapon_knife");

		// Set wand model.
		if (get_pcvar_num(cvarsData[cvar_wand_enabled]))
		{
			setWandModels(index);
		}
		else
		{
			// Add two flashes.
			if (get_pcvar_num(cvarsData[cvar_flashes_enabled]))
			{
				userData[index][dataAllowedWeapons] |= (1 << CSW_FLASHBANG);

				ForRange(i, 0, 1)
				{
					give_item(index, "weapon_flashbang");
				}
			}
		}
	}
}

getWarmupWinner()
{
	// Return if warmup reward is none.
	if (get_pcvar_num(cvarsData[cvar_warmup_level_reward]) < 2)
	{
		return 0;
	}

	new winner;
	new Array:candidates = ArrayCreate(2, 32);

	// Collect all players data
	ForPlayers(i)
	{
		if (is_user_connected(i) && !is_user_hltv(i))
		{
			new dataSet[4];
			dataSet[0] = i; // id
			dataSet[1] = get_user_frags(i); // frags
			dataSet[2] = get_user_deaths(i); // deaths

			ArrayPushArray(candidates, dataSet);
		}
	}

	ArraySortEx(candidates, "sortPlayersByKills");

	new candidatesAmount = ArraySize(candidates);
	if (candidatesAmount == 0)
	{
		// There is no winner, no real players on server
		return 0;
	}
	// Check if top player is best by frags only
	
	// Only one player
	if (candidatesAmount == 1)
	{
		new player[4];
		ArrayGetArray(candidates, 0, player);
		winner = player[0];
		announceWarmUpWinner(winner);
		
		ArrayDestroy(candidates);
		return winner;
	}
	// More players
	else if (candidatesAmount >= 2)
	{
		new top1Player[4], top2Player[4];
		ArrayGetArray(candidates, 0, top1Player);
		ArrayGetArray(candidates, 1, top2Player);

		if (top1Player[1] > top2Player[1])
		{
			winner = top1Player[0];
			ArrayDestroy(candidates);
			
			announceWarmUpWinner(winner);
			return winner;
		}
		else if (top1Player[1] < top2Player[1])
		{
			winner = top2Player[0];
			ArrayDestroy(candidates);

			announceWarmUpWinner(winner);
			return winner;
		}
		// Else top players are ex aequo, let's choose by kills and deaths difference
	}

	ArraySortEx(candidates, "sortPlayersByKillsDeathsDifference");

	// Get only players with best score
	new Array:bestPlayers = ArrayCreate(2, 32);
	new candidateData[3];
	ArrayGetArray(candidates, 0, candidateData);

	new maximum = candidateData[1] + candidateData[2]; // Get top player
	new topFrags = candidateData[1];
	if (topFrags > 0) // Best player has killed someone = not everybody has 0:0 stats
	{
		ForDynamicArray(i, candidates)
		{
			ArrayGetArray(candidates, i, candidateData);
			if (candidateData[1] < maximum)
			{
				break;
			}
			ArrayPushArray(bestPlayers, candidateData);
		}

		// Only player with top score, he's the winner
		new bestPlayersAmount = ArraySize(bestPlayers);
		if (bestPlayersAmount == 1)
		{
			ArrayGetArray(bestPlayers, 0, candidateData);
			winner = candidateData[0];
		}
		else // There are more players with top score, let's randomly choose one
		{
			new choosen = random_num(0, bestPlayersAmount - 1);
			ArrayGetArray(bestPlayers, choosen, candidateData);
			winner = candidateData[0];
		}

		announceWarmUpWinner(winner);
	}
	else if (topFrags == 0) // No one got killed
	{
		winner = 0;
	}

	ArrayDestroy(candidates);
	ArrayDestroy(bestPlayers);

	return winner;
}

announceWarmUpWinner(winner)
{
	// Print win-message couple times in chat.
	if (is_user_connected(winner))
	{
		ForRange(i, 0, 2)
		{
			if (gg_get_user_vip(winner))
			{
				ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode zaczyna GunGame z poziomem^x04 %i^x01!", chatPrefix, winner, get_pcvar_num(cvarsData[cvar_warmup_level_reward]));
			}
			else
			{
				ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode otrzymuje VIPA do konca mapy!", chatPrefix, winner);
			}
		}
	}
}

public sortPlayersByKills(Array:array, elem1[], elem2[], const data[], data_size)
{
	new p1Kills = elem1[1];
	new p2Kills = elem2[1];

	if (p1Kills > p2Kills)
	{
		return -1;
	}
	else if (p1Kills < p2Kills)
	{
		return 1;
	}
	return 0;
}

public sortPlayersByKillsDeathsDifference(Array:array, elem1[], elem2[], const data[], data_size)
{
	new p1Kills = elem1[1];
	new p1Deaths = elem1[2];

	new p2Kills = elem2[1];
	new p2Deaths = elem2[2];

	new p1Difference = p1Kills - p1Deaths;
	new p2Difference = p2Kills - p2Deaths;

	if (p1Difference > p2Difference)
	{
		return -1;
	}
	else if (p1Difference < p2Difference)
	{
		return 1;
	}
	return 0;
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
	
	if (gameMode == modeNormal)
	{
		highest = 0;

		// Loop through all players, get one with highest level and kills.
		ForPlayers(i)
		{
			if (!is_user_connected(i))
			{
				continue;
			}
			
			if (userData[i][dataLevel] > userData[highest][dataLevel])
			{
				highest = i;
			}

			else if (userData[i][dataLevel] == userData[highest][dataLevel])
			{
				if (userData[i][dataWeaponKills] > userData[highest][dataWeaponKills])
				{
					highest = i;
				}
			}
		}
	}
	else if (gameMode == modeTeamplay)
	{
		highest = tpData[tpTeamLevel][0] == tpData[tpTeamLevel][1] ? -1 : (tpData[tpTeamLevel][1] > tpData[tpTeamLevel][0] ? 1 : 0);

		if (highest == -1)
		{
			highest = tpData[tpTeamKills][0] == tpData[tpTeamKills][1] ? -1 : (tpData[tpTeamKills][1] > tpData[tpTeamKills][0] ? 1 : 0);
		}
	}

	return highest;
}

getCurrentLowestLevel()
{
	// Just return 0 if there are less than 3 players, no need for a loop.
	if (get_playersnum() < 3)
	{
		return 0;
	}

	new lowest;

	// Loop through all players and get lowest level.
	ForPlayers(i)
	{
		if (!is_user_connected(i) || userData[i][dataLevel] > lowest)
		{
			continue;
		}

		lowest = userData[i][dataLevel];
	}

	return lowest;
}

getPlayerByName(name[])
{
	// Get rid of white spaces.
	trim(name);

	// Return error value if name was not specified.
	if (!strlen(name))
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
		if (!is_user_connected(i) || containi(userData[i][dataName], name) == -1)
		{
			continue;
		}
		
		playersFound++;
			
		foundPlayerIndex = i;
	}

	// Return -1 if found more than one guy.
	if (playersFound > 1)
	{
		return -1;
	}

	return foundPlayerIndex;
}

getPlayerByTopLevel(array[], count)
{
	new highestLevels[MAX_PLAYERS + 1],
		counter;

	ForPlayers(index)
	{
		if (!is_user_connected(index))
		{
			continue;
		}

		for (new i = count - 1; i >= 0; i--)
		{
			if (highestLevels[i] < userData[index][dataLevel] + 1 && i)
			{
				continue;
			}

			if (highestLevels[i] >= userData[index][dataLevel] + 1 && i < count - 1)
			{
				counter = i + 1;
			}

			else if (!i)
			{
				counter = 0;
			}

			else 
			{
				break;
			}

			for (new j = count - 2; j >= counter; j--)
			{
				highestLevels[j + 1] = highestLevels[j];

				array[j + 1] = array[j];
			}

			highestLevels[counter] = userData[index][dataLevel] + 1;
			array[counter] = index;
		}
	}
}

getWarmupWeaponName()
{
	// Return if warmup weapon is static.
	if (warmupData[warmupWeaponNameIndex] > -1)
	{
		return;
	}

	// Loop through all weapons, find one with same ID as warmup weapon.
	ForArray(i, weaponsData)
	{
		if (get_pcvar_num(cvarsData[cvar_warmup_weapon]) == weaponsData[i][weaponCSW])
		{
			warmupData[warmupWeaponNameIndex] = i;

			break;
		}
	}
}

refillAmmo(index, bool:team = false)
{
	// Return if player is not alive or gungame has ended.
	if (gungameEnded)
	{
		return;
	}

	static userWeapon,
		weaponClassname[MAX_CHARS - 1],
		weaponEntity;

	if (team)
	{
		ForTeam(i, index)
		{
			if (!is_user_alive(i))
			{
				continue;
			}
			
			userWeapon = get_user_weapon(i);

			// Continue if for some reason player has no weapon.
			if (!userWeapon)
			{
				continue;
			}

			// Get weapon classname.
			get_weaponname(userWeapon, weaponClassname, charsmax(weaponClassname));

			// Get entity index of player's weapon.
			weaponEntity = find_ent_by_owner(-1, weaponClassname, i);

			// Continue if weapon index is invalid.
			if (!weaponEntity)
			{
				continue;
			}

			// Refill weapon ammo.
			cs_set_weapon_ammo(weaponEntity, ammoAmounts[userWeapon]);
		}
	}
	else
	{
		userWeapon = get_user_weapon(index);

		// Return if for some reason player has no weapon.
		if (!userWeapon)
		{
			return;
		}
		
		// Get weapon classname.
		get_weaponname(userWeapon, weaponClassname, charsmax(weaponClassname));

		// Get entity index of player's weapon.
		weaponEntity = find_ent_by_owner(-1, weaponClassname, index);

		// Return if weapon index is invalid.
		if (!weaponEntity)
		{
			return;
		}

		// Refill weapon ammo.
		cs_set_weapon_ammo(weaponEntity, ammoAmounts[userWeapon]);
	}
}

randomWarmupWeapon(index)
{
	// Return if player is not alive or warmup is not enabled.
	if (!is_user_alive(index) || !warmupData[warmupEnabled])
	{
		return;
	}

	new csw,
		weaponClassname[MAX_CHARS - 1],
		weaponsArrayIndex = random_num(0, sizeof(weaponsData) - 2);

	// Get random index from weaponsData array.
	csw = weaponsData[weaponsArrayIndex][0];

	// Get classname of randomized weapon.
	get_weaponname(csw, weaponClassname, charsmax(weaponClassname));

	userData[index][dataAllowedWeapons] |= (1 << csw);

	// Add weapon to player.
	give_item(index, weaponClassname);

	// Set weapon bp ammo to 100.
	cs_set_user_bpammo(index, csw, 100);

	userData[index][dataWarmupWeapon] = csw;
	userData[index][dataWarmupCustomWeaponIndex] = weaponsArrayIndex;
}

// Clamp down user name if its length is greater than "value" argument.
clampDownClientName(index, output[], length, const value, const token[])
{
	if (strlen(userData[index][dataName]) > value)
	{
		format(output, value, userData[index][dataName]);

		add(output, length, token);
	}
	else
	{
		// Just copy his original name instead.
		copy(userData[index][dataShortName], MAX_CHARS - 1, userData[index][dataName]);
	}
}

wandAttack(index, weapon)
{
	// He ded >.<
	if (!is_user_alive(index))
	{
		return PLUGIN_HANDLED;
	}

	// Wand enabled?
	if (!get_pcvar_num(cvarsData[cvar_wand_enabled]))
	{
		return PLUGIN_HANDLED;
	}

	if (weapon != CSW_KNIFE)
	{
		return PLUGIN_HANDLED;
	}
	
	// Not on last level & not a warmup.
	if (!warmupData[warmupEnabled] && !isOnLastLevel(index))
	{
		return PLUGIN_HANDLED;
	}

	// Warmup weapon is not wand.
	if (warmupData[warmupEnabled] && get_pcvar_num(cvarsData[cvar_warmup_weapon]) != -2)
	{
		return PLUGIN_HANDLED;
	}

	// Cooldown is still on.
	if (userData[index][dataWandLastAttack] + get_pcvar_float(cvarsData[cvar_wand_attack_interval]) > get_gametime())
	{
		return PLUGIN_HANDLED;
	}

	new endOrigin[3],
		startOrigin[3];

	// Get player position and end position.
	get_user_origin(index, startOrigin, 0);
	get_user_origin(index, endOrigin, 3);

	// Block shooting if distance is too high.
	if (get_distance(startOrigin, endOrigin) > get_pcvar_num(cvarsData[cvar_wand_attack_max_distance]))
	{
		return PLUGIN_HANDLED;
	}

	// Animate attacking.
	setWeaponAnimation(index, 1);

	// Show progress bar
	static barMessageHandle;
	
	if (!barMessageHandle)
	{
		barMessageHandle = get_user_msgid("BarTime2");
	}
	
	message_begin(index ? MSG_ONE : MSG_ALL, barMessageHandle, _, index);
	write_short(floatround(get_pcvar_float(cvarsData[cvar_wand_attack_interval])));
	write_short(0);
	message_end();

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
	write_byte(get_pcvar_num(cvarsData[cvar_wand_attack_sprite_life]));
	write_byte(30);
	write_byte(40);
	write_byte(wandAttackSpriteColor[0]);
	write_byte(wandAttackSpriteColor[1]);
	write_byte(wandAttackSpriteColor[2]);
	write_byte(get_pcvar_num(cvarsData[cvar_wand_attack_sprite_brightness]));
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
	if (get_user_team(index) == get_user_team(victim))
	{
		return PLUGIN_HANDLED;
	}

	// Set punchangle whenever player attacks.
	set_pev(index, pev_punchangle, Float:{ -1.5, 0.0, 0.0 });

	// Log last attack.
	userData[index][dataWandLastAttack] = floatround(get_gametime());

	// Create temp. entity.
	new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	static Float:victimOrigin[3];

	// Get end point vector.
	IVecFVec(endOrigin, victimOrigin);

	// Set temp. entity's origin.
	set_pev(entity, pev_origin, victimOrigin);

	// Remove temp. entity.
	engfunc(EngFunc_RemoveEntity, entity);

	if (!is_user_alive(victim))
	{
		return PLUGIN_HANDLED;
	}

	static Float:victimVelocity[3];
	pev(victim, pev_velocity, victimVelocity);

	// Slow down victim.
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

	if (attackerHealth > hitDamage)
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
	else if (attackerHealth <= hitDamage)
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

stock strip_user_weapon(index, weaponCsw, weaponSlot = 0, bool:switchWeapon = true)
{
	if (!weaponSlot)
	{
		static const weaponsSlots[] = { -1, 2, -1, 1, 4, 1, 5, 1, 1, 4, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 4, 2, 1, 1, 3, 1 };
		
		weaponSlot = weaponsSlots[weaponCsw];
	}

	const XTRA_OFS_PLAYER = 5;
	const m_rgpPlayerItems_Slot0 = 367;
	const XTRA_OFS_WEAPON = 4;
	const m_pNext = 42;
	const m_iId = 43;
	const m_pActiveItem = 373;

	new weapon = get_pdata_cbase(index, m_rgpPlayerItems_Slot0 + weaponSlot, XTRA_OFS_PLAYER);

	while (weapon)
	{
		// Break if we got the weapon right away.
		if (get_pdata_int(weapon, m_iId, XTRA_OFS_WEAPON) == weaponCsw)
		{
			break;
		}

		// Assign new entity.
		weapon = get_pdata_cbase(weapon, m_pNext, XTRA_OFS_WEAPON);
	}

	if (weapon)
	{
		if (switchWeapon && get_pdata_cbase(index, m_pActiveItem, XTRA_OFS_PLAYER) == weapon)
		{
			ExecuteHamB(Ham_Weapon_RetireWeapon, weapon);
		}

		if (ExecuteHamB(Ham_RemovePlayerItem, index, weapon))
		{
			// Honestly dont know what is the point of this one.
			user_has_weapon(index, weaponCsw, 0);

			// Kill weapon entity.
			ExecuteHamB(Ham_Item_Kill, weapon);

			// Weapon removed successfully.
			return true;
		}
	}

	// Weapon not found.
	return false;
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

	if (!iMsgScreenFade)
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

	if (!pev_valid(entity))
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
	if (gameMode == modeNormal)
	{
		userData[index][dataLevel] = sizeof(weaponsData) - 3;
		
		incrementUserLevel(index, 1, true);
	}
	else
	{
		new team = get_user_team(index);

		tpData[tpTeamLevel][team - 1] = sizeof(weaponsData) - 3;

		incrementTeamLevel(team, 1, true);
	}
}

public addLevel(index)
{
	if (gameMode == modeNormal)
	{
		incrementUserLevel(index, 1, true);
	}
	else
	{
		incrementTeamLevel(get_user_team(index), 1, true);
	}
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
	toggleWarmup(!warmupData[warmupEnabled]);

	client_print(0, print_chat, "Warmup = %s", warmupData[warmupEnabled] ? "ON" : "OFF");
}

public addKnifeKill(index)
{
	userData[index][dataKnifeKills]++;
	client_print(0, print_chat, "%i", userData[index][dataKnifeKills]);
}

public addHeadshot(index)
{
	userData[index][dataHeadshots]++;
	client_print(0, print_chat, "%i", userData[index][dataHeadshots]);
}

public addKill(index)
{
	userData[index][dataKills]++;
	client_print(0, print_chat, "%i", userData[index][dataKills]);
}

public addWin(index)
{
	userData[index][dataWins]++;
	client_print(0, print_chat, "%i", userData[index][dataWins]);
}

public addWeapon(index)
{
	give_item(index, "weapon_m4a1");
}

#endif

/*
		[ Game mode ]
*/

public showGameVoteMenu(index)
{
	if (!gameVoteEnabled || !is_user_connected(index))
	{
		return PLUGIN_HANDLED;
	}

	new menuIndex = menu_create("Wybierz tryb gry:", "showGameVoteMenu_handler");

	// Add game mode names to the menu.
	ForArray(i, gameModes)
	{
		menu_additem(menuIndex, gameModes[i]);
	}

	// Disable exit option.
	menu_setprop(menuIndex, MPROP_EXIT, MEXIT_NEVER);

	menu_display(index, menuIndex);
	
	return PLUGIN_HANDLED;
}

public showGameVoteMenu_handler(index, menuIndex, item)
{
	menu_destroy(menuIndex);
	
	// Block player's vote if voting is not enabled.
	if (item == MENU_EXIT || !gameVoteEnabled)
	{
		return PLUGIN_HANDLED;
	}

	// Add vote.
	gameVotes[item]++;

	ColorChat(index, RED, "%s^x01 Wybrales tryb:^x04 %s^x01.", chatPrefix, gameModes[item]);

	return PLUGIN_HANDLED;
}

setGameVote()
{
	// Set votes to zero.
	ForArray(i, gameModes)
	{
		gameVotes[i] = 0;
	}

	gameVoteEnabled = true;

	// Show game mode vote menu to all players.
	ForPlayers(i)
	{
		if (!is_user_connected(i))
		{
			continue;
		}

		showGameVoteMenu(i);
	}
}

public finishGameVote()
{
	gameVoteEnabled = false;
	gameMode = 0;

	new bool:tie,
		sumOfVotes = gameVotes[0] + gameVotes[1];

	// Handle game mode votes.
	if (gameVotes[0] == gameVotes[1])
	{
		tie = true;
	}
	else
	{
		if (gameVotes[0] > gameVotes[1])
		{
			gameMode = 0;
		}
		else
		{
			gameMode = 1;
		}
	}

	// If there is no definitive winner, get one randomly.
	if (tie || !sumOfVotes)
	{
		gameMode = random_num(0, sizeof(gameModes) - 1);

		tpData[tpEnabled] = bool:(gameMode == modeTeamplay);
	}

	if (get_playersnum())
	{
		new message[191];

		ForPlayers(i)
		{
			if (!is_user_connected(i))
			{
				continue;
			}
			
			formatex(message, charsmax(message), "%s^x01 %sygral tryb:^x04 %s.", chatPrefix, tie ? "Droga losowania w" : "W", gameModes[gameMode]);

			if (sumOfVotes)
			{
				format(message, charsmax(message), "%s ^x01Zdobyl^x04 %i procent^x01 glosow.", message, floatround(float(gameVotes[gameMode]) / float(sumOfVotes) * 100.0));
			}

			ColorChat(i, RED, message);	
		}
	}

	ExecuteForward(forwardHandles[forwardGameModeChosen], forwardReturnDummy, gameMode);
}