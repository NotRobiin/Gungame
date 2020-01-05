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

// Commands to be blocked (using PLUGIN_HANDLED).
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
	1, 30, 100,
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
	//"sprites/gungame/wand_attack.spr",
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
	{ "gg_set_user_level", "native_set_user_level" },
	{ "gg_get_user_level", "native_get_user_level" },

	{ "gg_set_team_level", "native_set_team_level" },
	{ "gg_get_team_level", "native_get_team_level" },
	
	{ "gg_get_max_level", "native_get_max_level" },
	
	{ "gg_respawn_player", "native_respawn_player" },
	
	{ "gg_get_user_weapon", "native_get_user_weapon" },
	{ "gg_get_weapons_data", "native_get_weapons_data" },

	{ "gg_get_user_wins", "native_get_user_wins" },
	{ "gg_get_user_combo", "native_get_user_combo" }
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
	forward_level_up,
	forward_level_down,
	forward_game_end,
	forward_game_beginning,
	forward_player_spawned,
	forward_combo_streak,
	forward_game_mode_chosen
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

new user_data[MAX_PLAYERS + 1][userDataEnumerator],

	warmup_data[warmupEnumerator],

	top_players[topPlayersDisplayed + 1][topPlayersEnumerator],
	top_data[topInfo],

	tp_data[teamplayEnumerator],

	db_data[dbEnumerator],

	cvars_data[sizeof(ggCvarsData)],

	weapon_names[sizeof(weaponsData)][MAX_CHARS - 1],
	weapon_entity_names[sizeof(weaponsData)][MAX_CHARS],
	weapon_temp_name[MAX_CHARS],

	bool:gungame_ended,

	max_level,
	half_max_level,

	hud_objects[3],

	sprite_levelup_index,

	forward_handles[sizeof(forwardsNames)],
	forward_return_dummy,

	wand_sprites_indexes[sizeof(wandSprites)],

	game_votes[sizeof(gameModes)],
	bool:game_vote_enabled,
	game_mode = -1,

	disconnected_players_data[dcDataEnumerator];


public plugin_init()
{
	register_plugin("GunGame", "v2.5", AUTHOR);

	// Register cvars.
	ForArray(i, ggCvarsData)
	{
		cvars_data[i] = register_cvar(ggCvarsData[i][0], ggCvarsData[i][1]);
	}

	// Register Death and team assign events.
	register_event("DeathMsg", "playerDeathEvent", "a");
	register_event("TeamInfo", "onTeamAssign", "a");

	// Remove weapons off the ground if enabled.
	if (get_pcvar_num(cvars_data[cvar_remove_weapons_off_the_ground]))
	{
		remove_weapons_off_ground();
		
		register_event("HLTV", "roundStart", "a", "1=0", "2=0");
	}

	// CurWeapon for AWP reloading
	register_event("CurWeapon", "eventCurWeapon", "be", "1=1");

	// Register info change and model set events.
	register_forward(FM_ClientUserInfoChanged, "clientInfoChanged");
	register_forward(FM_SetModel, "setEntityModel");

	// Register message events (say, TextMsg and radio message).
	register_message(get_user_msgid("SayText"), "sayHandle");
	register_message(get_user_msgid("TextMsg"), "textGrenadeMessage");
	register_message(get_user_msgid("SendAudio"), "audioGrenadeMessage");

	RegisterHam(Ham_Spawn, "player", "playerSpawn", true);
	RegisterHam(Ham_TakeDamage, "player", "takeDamage", false);
	RegisterHam(Ham_AddPlayerItem, "player", "onAddItemToPlayer");

	// Register greande think forward if HE explode time differs from default.
	if (heGrenadeExplodeTime != defaultExplodeTime)
	{
		RegisterHam(Ham_Think, "grenade", "heGrenadeThink");
	}

	// Register knife deployement for model-changes if wand is enabled.
	if (get_pcvar_num(cvars_data[cvar_wand_enabled]))
	{
		RegisterHam(Ham_Item_Deploy, wandBaseEntity, "knifeDeploy", true);
	}

	new weapon_classname[24];
	new const excluded_weapons = (CSW_KNIFE | CSW_C4);

	ForRange(i, 1, 30)
	{
		if (!(excluded_weapons & 1 << i) && get_weaponname(i, weapon_classname, charsmax(weapon_classname)))
		{
			RegisterHam(Ham_Item_Deploy, weapon_classname, "weaponDeploy");
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
		get_weapons_name(i, weaponsData[i][weaponCSW], weapon_names[i], charsmax(weapon_names[]));
	}

	// Register primary attack with weapons registered in gungame.
	ForArray(i, weaponsData)
	{
		RegisterHam(Ham_Weapon_PrimaryAttack, weapon_entity_names[i], "primaryAttack");
	}

	// Block some commands.
	register_commands(blockedCommands, sizeof(blockedCommands), "block_command_usage", false);

	// Register weapon list commands.
	register_commands(listWeaponsCommands, sizeof(listWeaponsCommands), "listWeaponsMenu");

	// Register top player menu commands.
	register_commands(topPlayersMotdCommands, sizeof(topPlayersMotdCommands), "topPlayersMotdHandler");
	
	// Create hud objects.
	ForRange(i, 0, charsmax(hud_objects))
	{
		hud_objects[i] = CreateHudSyncObj();
	}

	// Hook 'say' client command to create custom lookup command.
	register_clcmd("say", "sayCustomCommandHandle");

	// Get gungame max level.
	max_level = sizeof(weaponsData) - 1;

	// Get half of max gungame level rounded, so we can limit level on freshly-joined players.
	half_max_level = floatround(float(max_level) / 2, floatround_round);

	// Create forwards.
	forward_handles[forward_level_up] = CreateMultiForward(forwardsNames[0], ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // Level up (3)
	forward_handles[forward_level_down] = CreateMultiForward(forwardsNames[1], ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // Level down (3)
	forward_handles[forward_game_end] = CreateMultiForward(forwardsNames[2], ET_IGNORE, FP_CELL); // Game end (1)
	forward_handles[forward_game_beginning] = CreateMultiForward(forwardsNames[3], ET_IGNORE, FP_CELL); // Game beginning (1)
	forward_handles[forward_player_spawned] = CreateMultiForward(forwardsNames[4], ET_IGNORE, FP_CELL); // Player spawn (1)
	forward_handles[forward_combo_streak] = CreateMultiForward(forwardsNames[5], ET_IGNORE, FP_CELL, FP_CELL); // Combo streak (2)
	forward_handles[forward_game_mode_chosen] = CreateMultiForward(forwardsNames[6], ET_IGNORE, FP_CELL); // Game mode chosen (1)

	// Toggle warmup a bit delayed from plugin start.
	set_task(1.0, "delayed_toggleWarmup");

	// Load info required to connect to database.
	load_sql_config();

	// Load cvars.
	load_game_cvars();

	// Connect do mysql database.
	connectDatabase();

	// Initialize dynamic arrays.
	disconnected_players_data[dcDataLevel] = ArrayCreate(1, 1);
	disconnected_players_data[dcDataName] = ArrayCreate(32, 1);
	disconnected_players_data[dcDataWeaponKills] = ArrayCreate(1, 1);

	// Load top players from MySQL.
	loadTopPlayers();
	#if defined TEST_MODE

		// Test commands.
		register_clcmd("say /lvl", "setMaxLevel");
		register_clcmd("say /addlvl", "addLevel");
		register_clcmd("say /awp", "setAWPLevel");
		register_clcmd("say /godoff", "godmodOff");
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

public native_set_user_level(plugin, params)
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
	if (0 > level > max_level)
	{
		#if defined DEBUG_MODE
		
		log_amx("%s Level value incorrect (%i) [min. %i | max. %i].", nativesLogPrefix, level, 0, max_level);
		
		#endif

		return nativesErrorValue;
	}

	// Set level.
	user_data[index][dataLevel] = level;

	return 1;
}

public native_get_user_level(plugin, params)
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
	return user_data[index][dataLevel];
}

public native_set_team_level(plugin, params)
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

	new bool:include_members = bool:get_param(3);

	tp_data[tpTeamLevel][team - 1] = level;

	if (include_members)
	{
		ForTeam(i, team)
		{
			user_data[i][dataLevel] = level;
		}
	}

	return true;
}

public native_get_team_level(plugin, params)
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

	return tp_data[tpTeamLevel][team - 1];
}

public native_get_user_weapon_kills(plugin, params)
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
	return user_data[index][dataWeaponKills];
}

// Return max level.
public native_get_max_level(plugin, params)
{
	if (params != 1)
	{
		return nativesErrorValue;
	}

	return max_level;
}

public native_respawn_player(plugin, params)
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
	respawn_player(index, time);

	return 1;
}

public native_get_user_weapon(plugin, params)
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
	return weaponsData[user_data[index][dataLevel]][0];
}

public native_get_weapons_data(plugin, params)
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
	return weaponsData[user_data[index][dataLevel]][value];
}

public native_get_user_wins(plugin, params)
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

	return user_data[index][dataWins];
}

public native_get_user_combo(plugin, params)
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

	return user_data[index][dataCombo];
}

/*
		[ Forwards & menus & unassigned publics ]
*/

public plugin_end()
{
	ArrayDestroy(disconnected_players_data[dcDataName]);
	ArrayDestroy(disconnected_players_data[dcDataLevel]);
	ArrayDestroy(disconnected_players_data[dcDataWeaponKills]);
}

public plugin_precache()
{
	new file_path[MAX_CHARS * 3];

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
			formatex(file_path, charsmax(file_path), "%s%s", containi(soundsData[i][j], "sound/") == -1 ? "sound/" : "", soundsData[i][j]);

			if (!file_exists(file_path))
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
	sprite_levelup_index = engfunc(EngFunc_PrecacheModel, spritesData[spriteLevelup]);

	// Precache wand models.
	ForArray(i, wandModels)
	{
		engfunc(EngFunc_PrecacheModel, wandModels[i]);
	}

	// Precache wand sprites.
	ForArray(i, wandSprites)
	{
		wand_sprites_indexes[i] = engfunc(EngFunc_PrecacheModel, wandSprites[i]);
	}

	// Precache wand sounds.
	ForArray(i, wandSounds)
	{
		precache_sound(wandSounds[i]);
	}
}

public client_authorized(index)
{
	user_data[index][dataWarmupWeapon] = -1;
	user_data[index][dataWarmupCustomWeaponIndex] = -1;

	// Do nothing if user is a hltv.
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Get name-related data.
	get_user_name_data(index);

	// Load mysql data.
	getUserData(index);

	// Preset user level to 0.
	user_data[index][dataLevel] = 0;
	user_data[index][dataWeaponKills] = 0;

	// Reconnected?
	get_on_connect(index);

	// Dont calculate level if gungame has ended or player has reconnected.
	if (gungame_ended || user_data[index][dataLevel])
	{
		return;
	}

	new lowest_level = get_current_lowest_level(),
		new_level = (lowest_level > 0 ? lowest_level : 0 > half_max_level ? half_max_level : new_level);

	// Set user level to current lowest or half of max level if current lowest is greater than half.
	user_data[index][dataLevel] = new_level;
	user_data[index][dataWeaponKills] = 0;
}

public client_putinserver(index)
{
	// Respawn player.
	set_task(2.0, "respawnPlayerOnJoin", index + TASK_RESPAWN_ON_JOIN);
	set_task(3.0, "show_game_vote_menu", index);
}

// Remove hud tasks on disconnect.
public client_disconnect(index)
{
	remove_hud(index);
	updateUserData(index);
	save_on_disconnect(index);
}

// Get user's name again when changed.
public clientInfoChanged(index)
{
	// Update name-related data.
	get_user_name_data(index);
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
		if (weaponsData[user_data[owner][dataLevel]][weaponCSW] == CSW_HEGRENADE || get_pcvar_num(cvars_data[cvar_warmup_weapon]) == CSW_HEGRENADE && warmup_data[warmupEnabled])
		{
			set_task(get_pcvar_float(cvars_data[cvar_give_back_he_interval]), "giveHeGrenade", owner + TASK_GIVEGRENADE);
		}

		if (heGrenadeExplodeTime != defaultExplodeTime)
		{
			set_pev(entity, pev_dmgtime, get_gametime() + heGrenadeExplodeTime);
		}
	}
	else if (equal(model[9], "fl", 2) && weaponsData[user_data[owner][dataLevel]][weaponCSW] == CSW_KNIFE)
	{
		set_task(get_pcvar_float(cvars_data[cvar_give_back_flash_interval]), "giveFlashGrenade", owner + TASK_GIVEGRENADE);
	}
}

public primaryAttack(entity)
{
	new index = get_pdata_cbase(entity, 41, 4);

	// Block attacking if gungame has ended.
	if (gungame_ended && is_user_alive(index))
	{
		return HAM_IGNORED;
	}

	// Cooldown on.
	if (user_data[index][dataWandLastAttack] + get_pcvar_float(cvars_data[cvar_wand_attack_interval]) > get_gametime())
	{
		return HAM_SUPERCEDE;
	}

	new weapon_index = cs_get_weapon_id(entity);

	// Handle wand attacking.
	wand_attack(index, weapon_index);

	return HAM_IGNORED;
}

public onAddItemToPlayer(index, weapon_entity)
{
	new csw = cs_get_weapon_id(weapon_entity);

	// Skip kevlar.
	if (csw == CSW_VEST || csw == CSW_VESTHELM)
	{
		return HAM_IGNORED;
	}

	// User is allowed to carry that weapon?
	if (user_data[index][dataAllowedWeapons] & (1 << csw))
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
	ExecuteHam(Ham_Item_Kill, weapon_entity);

	SetHamReturnInteger(false);

	return HAM_SUPERCEDE;
}

public eventCurWeapon(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	// todo: cvar here
	if(/*get_pcvar_num(gg_awp_oneshot) &&*/ read_data(2) == CSW_AWP && read_data(3) > 1)
	{
		new wEnt = find_ent_by_owner(-1, "weapon_awp", id);
		if(pev_valid(wEnt))
		{
			cs_set_weapon_ammo(wEnt, 1);
			cs_set_user_bpammo(id, CSW_AWP, 100);
		}
	}
}

public client_PreThink(index)
{
	// Return if player is not alive, is hltv or a bot.
	if (!get_pcvar_num(cvars_data[cvar_fall_damage_enabled]) || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Set falling status based on current velocity.
	user_data[index][dataFalling] = bool:(entity_get_float(index, EV_FL_flFallVelocity) > 350.00);
}

public client_PostThink(index)
{
	// Return if player is not alive, is hltv, is bot or is not falling.
	if (!get_pcvar_num(cvars_data[cvar_fall_damage_enabled]) || !is_user_alive(index) || is_user_hltv(index) || is_user_bot(index) || !user_data[index][dataFalling])
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

	new user_team = get_user_team(index);

	// Narrow matches a bit.
	if (0 >= user_team > 2)
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
	remove_weapons_off_ground();
}

public takeDamage(victim, idinflictor, attacker, Float:damage, damagebits)
{
	// Return if attacker isnt alive, self damage, no damage or players are on the same team.
	if (!is_user_alive(attacker) || victim == attacker || !damage || !is_user_alive(victim))
	{
		return HAM_IGNORED;
	}

	// Return if gungame has ended.
	if (gungame_ended)
	{
		return HAM_SUPERCEDE;
	}

	if (get_user_team(attacker) == get_user_team(victim))
	{
		if (game_mode == modeNormal && !get_pcvar_num(cvars_data[cvar_normal_friendly_fire]))
		{
			return HAM_SUPERCEDE;
		}
		else if (game_mode == modeTeamplay && !get_pcvar_num(cvars_data[cvar_teamplay_friendly_fire]))
		{
			return HAM_SUPERCEDE;
		}
	}

	if (user_data[victim][dataSpawnProtection] && !get_pcvar_num(cvars_data[cvar_spawn_protection_type]))
	{
		return HAM_SUPERCEDE;
	}

	if (get_pcvar_num(cvars_data[cvar_wand_enabled]))
	{
		if (is_on_last_level(attacker) || get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -2)
		{
			return HAM_SUPERCEDE;
		}
	}

	// Show damage info in hud.
	set_hudmessage(takeDamageHudColor[0], takeDamageHudColor[1], takeDamageHudColor[2], 0.5, 0.4, 0, 6.0, get_pcvar_float(cvars_data[cvar_take_damage_hud_time]), 0.0, 0.0);
	ShowSyncHudMsg(attacker, hud_objects[hudObjectDamage], "%i^n", floatround(damage, floatround_round));

	return HAM_IGNORED;
}

public heGrenadeThink(entity)
{
	// Return if invalid entity or grenade is not HE.
	if (!pev_valid(entity) || !is_he_grenade(entity))
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
	if (!((1 << weapon) & user_data[index][dataAllowedWeapons]))
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
	if (!warmup_data[warmupEnabled] || user_data[index][dataLevel] != max_level)
	{
		return;
	}

	// Block if warmup weapon is not a wand.
	if (warmup_data[warmupEnabled] && get_pcvar_num(cvars_data[cvar_warmup_weapon]) != -2)
	{
		return;
	}

	// Block if wands are disabled.
	if (!get_pcvar_num(cvars_data[cvar_wand_enabled]))
	{
		return;
	}
	
	// Set the wand model.
	set_wand_models(index);
	set_weapon_animation(index, 3);
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
	remove_player_weapons(victim);

	if (gungame_ended)
	{
		remove_idle_check(victim);

		return;
	}

	// Respawn player.
	if (warmup_data[warmupEnabled])
	{
		respawn_player(victim, get_pcvar_float(cvars_data[cvar_warump_respawn_interval]));
	}
	else
	{
		respawn_player(victim, get_pcvar_float(cvars_data[cvar_respawn_interval]));
	}

	// Remove grenade task if present.
	if (task_exists(victim + TASK_GIVEGRENADE))
	{
		remove_task(victim + TASK_GIVEGRENADE);
	}

	remove_hud(victim);
	
	user_data[victim][dataCombo] = 0;
	user_data[victim][dataAllowedWeapons] = 0;

	new killer = read_data(1),
		weapon[12],
		killer_team = get_user_team(killer),
		victim_team = get_user_team(victim);

	read_data(4, weapon, charsmax(weapon));

	// Handle suicide.
	if (killer == victim)
	{
		new old_level;

		switch(game_mode)
		{
			case modeNormal:
			{
				old_level = user_data[victim][dataLevel];

				decrement_user_weapon_kills(victim, 1, true);

				if (user_data[victim][dataLevel] < old_level)
				{
					ColorChat(0, RED, "%s^x01 Gracz^x04 %n^x01 popelnil samobojstwo i spadl do poziomu^x04 %i (%s)^x01.",
						chatPrefix,
						victim,
						user_data[victim][dataLevel],
						customWeaponNames[user_data[victim][dataLevel]]);
				}
			}
			
			case modeTeamplay:
			{
				old_level = tp_data[tpTeamLevel][victim_team - 1];

				decrement_team_weapon_kills(victim_team, 1, true);

				if (tp_data[tpTeamLevel][victim_team - 1] < old_level)
				{
					ColorChat(0, RED, "%s^x01 Przez samobojstwo gracza^x04 %n^x01 druzyna^x04 %s^x01 spadla do poziomu^x04 %i (%s)^x01.",
						chatPrefix,
						victim,
						teamNames[victim_team - 1],
						tp_data[tpTeamLevel][victim_team - 1],
						customWeaponNames[tp_data[tpTeamLevel][victim_team - 1]]);
				}
			}
		}
		
		return;
	}

	// End gungame if user/team has reached max level.
	if (game_mode == modeNormal && user_data[killer][dataLevel] == max_level)
	{
		end_gungame(killer);
		
		return;
	}
	else if (game_mode == modeTeamplay)
	{
		if (tp_data[tpTeamLevel][0] == max_level || tp_data[tpTeamLevel][1] == max_level)
		{
			end_gungame(killer);

			return;
		}
	}

	// Handle killing on spawn protection.
	if (get_pcvar_num(cvars_data[cvar_spawn_protection_type]))
	{
		if (user_data[victim][dataSpawnProtection])
		{
			// Remove protection task if present.
			if (task_exists(victim + TASK_SPAWNPROTECTION))
			{
				remove_task(victim + TASK_SPAWNPROTECTION);
			}

			// Toggle off respawn protection.
			toggle_spawn_protection(victim, false);

			return;
		}
	}
	
	if (equal(weapon, "knife"))
	{
		// Block leveling up if player is on HE level and killed someone with a knife.
		if (weaponsData[user_data[killer][dataLevel]][weaponCSW] == CSW_HEGRENADE)
		{
			return;
		}
		
		// Update stats.
		user_data[killer][dataKnifeKills]++;

		if (user_data[victim][dataLevel])
		{
			switch(game_mode)
			{
				case modeNormal: decrement_user_level(victim, 1);
				case modeTeamplay:
				{
					if (get_pcvar_num(cvars_data[cvar_knife_kill_level_down_teamplay]))
					{
						decrement_team_level(victim_team, 1);
					}
				}
			}

			ColorChat(victim, RED, "%s^x01 Zostales zabity z kosy przez^x04 %n^x01. %s spadl do^x04 %i^x01.",
				chatPrefix,
				killer,
				game_mode == modeNormal ? "Twoj poziom" : "Poziom Twojej druzyny",
				tp_data[tpTeamLevel][victim_team]);
		}

		// Handle instant-level-up when killing with knife.
		if (get_pcvar_num(cvars_data[cvar_knife_kill_instant_levelup]))
		{
			switch(game_mode)
			{
				case modeNormal: increment_user_level(killer, get_pcvar_num(cvars_data[cvar_knife_kill_reward]), true);
				case modeTeamplay: increment_team_level(killer_team, get_pcvar_num(cvars_data[cvar_knife_kill_reward]), true);
			}
		}
		else
		{
			switch(game_mode)
			{
				case modeNormal: increment_user_weapon_kills(killer, get_pcvar_num(cvars_data[cvar_knife_kill_reward]));
				case modeTeamplay: increment_team_weapon_kills(killer_team, get_pcvar_num(cvars_data[cvar_knife_kill_reward]));
			}
		}
	}
	else
	{
		switch(game_mode)
		{
			case modeNormal: increment_user_weapon_kills(killer, 1);
			case modeTeamplay: increment_team_weapon_kills(killer_team, 1);
		}

		// Notify about killer's health left.
		ColorChat(victim, RED, "%s^x01 Zabity przez^x04 %n^x01 (^x04%i^x01 HP)", chatPrefix, killer, get_user_health(killer));
	}

	// Update stats.
	if (read_data(3))
	{
		user_data[killer][dataHeadshots]++;
	}
	
	user_data[killer][dataKills]++;

	// Handle ammo refill.
	switch(game_mode)
	{
		case modeNormal:
		{
			switch(get_pcvar_num(cvars_data[cvar_refill_weapon_ammo]))
			{
				case 1: refill_ammo(killer); // Killer
				case 2: // Vips only
				{
					if (gg_get_user_vip(killer))
					{
						refill_ammo(killer);
					}
				}
			}
		}

		case modeTeamplay:
		{
			switch (get_pcvar_num(cvars_data[cvar_refill_weapon_ammo_teamplay]))
			{
				case 1: refill_ammo(killer_team, true); // Whole team
				case 2: refill_ammo(killer); // Just the killer
				case 3: // Vips only
				{
					if (gg_get_user_vip(killer))
					{
						refill_ammo(killer);
					}
				}
			}
		}
	}
}

public playerSpawn(index)
{
	// Return if gungame has ended or player isnt alive.
	if (!is_user_alive(index) || gungame_ended)
	{
		return;
	}

	if (warmup_data[warmupEnabled])
	{
		// Give weapons to player.
		give_warmup_weapons(index);

		set_user_health(index, get_pcvar_num(cvars_data[cvar_warmup_health]));
	}
	else
	{
		// Enable hud.
		show_hud(index);

		// Give weapons to player.
		give_weapons(index);

		// Enbale spawn protection.
		toggle_spawn_protection(index, true);

		// Set task to disable spawn protection.
		set_task(get_pcvar_float(cvars_data[cvar_spawn_protection_time]), "spawnProtectionOff", index + TASK_SPAWNPROTECTION);

		// Set task to chcek if player is AFK.
		set_task(get_pcvar_float(cvars_data[cvar_idle_check_interval]), "checkIdle", index + TASK_IDLECHECK, .flags = "b");

		ExecuteForward(forward_handles[forward_player_spawned], forward_return_dummy, index);
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

	new chat_string[2][192],
		weapon_name[33];

	// Get message arguments.
	get_msg_arg_string(2, chat_string[0], charsmax(chat_string[]));

	// Replace "knife" with "wand".
	formatex(weapon_name, charsmax(weapon_name), (user_data[index][dataLevel] == max_level && get_pcvar_num(cvars_data[cvar_wand_enabled])) ? "Rozdzka" : customWeaponNames[user_data[index][dataLevel]]);

	if (equal(chat_string[0], "#Cstrike_Chat_All"))
	{
		// Get message arguments.
		get_msg_arg_string(4, chat_string[0], charsmax(chat_string[]));
		
		// Set argument to empty string.
		set_msg_arg_string(4, "");

		// Format new message to be sent.
		if (game_mode == modeNormal)
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%i Lvl (%s)]^x03 %n^x01 :  %s", user_data[index][dataLevel] + 1, weapon_name, index, chat_string[0]);
		}
		else
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%s]^x03 %n^x01 :  %s", weapon_name, index, chat_string[0]);
		}
	}
	else // Format new message to be sent.
	{
		if (game_mode == modeNormal)
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%i Lvl (%s)]^x01 %s", user_data[index][dataLevel] + 1, weapon_name, chat_string[0]);
		}
		else
		{
			formatex(chat_string[1], charsmax(chat_string[]), "^x04[%s]^x01 %s", weapon_name, chat_string[0]);
		}
	}

	// Send new message.
	set_msg_arg_string(2, chat_string[1]);

	return PLUGIN_CONTINUE;
}

public sayCustomCommandHandle(index)
{
	new message[MAX_CHARS],
		command[MAX_CHARS];

	// Remove quotes from message.
	get_chat_message_arguments(message, charsmax(message));
	
	// Retrieve command from message.
	get_first_argument(command, charsmax(command), message, charsmax(message));

	// Show player info if commands are matching.
	if (containi(command, lookupCommand) > -1)
	{
		show_player_info(index, get_player_by_name(message));
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

	static argument_text[MAX_CHARS - 1];

	// Get message argument.
	get_msg_arg_string(5, argument_text, charsmax(argument_text));

	// Return if it is not the one we are looking for.
	if (!equal(argument_text, "#Fire_in_the_hole"))
	{
		return PLUGIN_CONTINUE;
	}

	// Get message argument.
	get_msg_arg_string(2, argument_text, charsmax(argument_text));

	// Return if player is not alive.
	if (!is_user_alive(str_to_num(argument_text)))
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

	new argument_text[MAX_CHARS - 10];

	// Get message arguments.
	get_msg_arg_string(2, argument_text, charsmax(argument_text));

	// Return if it is not the one we are looking for.
	if (!equal(argument_text[1], "!MRAD_FIREINHOLE"))
	{
		return PLUGIN_CONTINUE;
	}

	// Block sending audio message.
	return PLUGIN_HANDLED;
}

public displayWarmupTimer()
{
	// Return if warmup has ended.
	if (!warmup_data[warmupEnabled])
	{
		return;
	}

	// Decrement warmup timer.
	warmup_data[warmupTimer]--;

	if (warmup_data[warmupTimer] >= 0)
	{
		// Play timer tick sound.
		play_sound(0, soundTimerTick, -1, false);

		// Get warmup weapon name index if not done so yet.
		if (warmup_data[warmupWeaponNameIndex] == -1)
		{
			get_warmup_weapon_name();
		}
		
		// Display warmup hud.
		set_hudmessage(warmupHudColors[0], warmupHudColors[1], warmupHudColors[2], -1.0, 0.1, 0, 6.0, 0.6, 0.2, 0.2);
		
		if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -3)
		{
			ForPlayers(i)
			{
				if (!is_user_alive(i) || is_user_hltv(i) || is_user_bot(i) || user_data[i][dataWarmupWeapon] == -1)
				{
					continue;
				}

				ShowSyncHudMsg(i, hud_objects[hudObjectWarmup], "[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]",
					warmup_data[warmupTimer],
					customWeaponNames[user_data[i][dataWarmupCustomWeaponIndex]]);
			}
		}
		else
		{
			new weapon_name[MAX_CHARS];

			// Warmup weapon is a wand?
			if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -2)
			{
				formatex(weapon_name, charsmax(weapon_name), "Rozdzki");
			}
			else
			{
				if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -1)
				{
					copy(weapon_name, charsmax(weapon_name), customWeaponNames[warmup_data[warmupWeaponIndex]]);
				}
				else
				{
					copy(weapon_name, charsmax(weapon_name), customWeaponNames[warmup_data[warmupWeaponNameIndex]]);
				}
			}

			ShowSyncHudMsg(0, hud_objects[hudObjectWarmup], "[ ROZGRZEWKA: %i sekund ]^n[ Bron na rozgrzewke: %s ]", warmup_data[warmupTimer], weapon_name);
		}

		// Set task to display hud again.
		set_task(1.2, "displayWarmupTimer");
	}
	else // Disable warmup if timer is less than 0.
	{
		toggle_warmup(false);
	}
}

public listWeaponsMenu(index)
{
	// Create menu handler.
	new menu_index = menu_create("Lista broni:^n[Bron ^t-^tpoziom  ^t-^t ilosc wymaganych zabojstw]", "listWeaponsMenu_handler"),
		menu_item[MAX_CHARS * 3],
		weapon_name[MAX_CHARS];

	ForArray(i, weaponsData)
	{
		if (i == max_level && get_pcvar_num(cvars_data[cvar_wand_enabled]))
		{
			formatex(weapon_name, charsmax(weapon_name), "Rozdzka");
		}
		else
		{
			copy(weapon_name, charsmax(weapon_name), customWeaponNames[i]);
		}

		formatex(menu_item, charsmax(menu_item), "[%s - %i lv. - %i (%i)]", weapon_name, i + 1, weaponsData[i][weaponKills], weaponsData[i][weaponTeamKills]);

		// Add item to menu.
		menu_additem(menu_index, menu_item);
	}

	// Display menu to player.
	menu_display(index, menu_index);

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
	if (!top_data[topDataLoaded])
	{
		ColorChat(index, RED, "%s^x01 Topka nie zostala jeszcze zaladowana.", chatPrefix);
		return PLUGIN_CONTINUE;
	}

	// Create top players motd if this is the first time someone has used command on this map.
	if (!top_data[topMotdCreated])
	{
		create_top_players_motd();
	}

	// Display motd.
	show_motd(index, top_data[topMotdCode], top_data[topMotdName]);

	return PLUGIN_CONTINUE;
}

/*
		[ TASKS ]
*/

public delayed_toggleWarmup()
{
	toggle_warmup(true);
}

public rewardWarmupWinner(taskIndex)
{
	new winner = taskIndex - TASK_REWARDWINNER;

	// Return if user is not connected or his level is somehow incorrect. 
	if (!is_user_connected(winner) || user_data[winner][dataLevel] >= get_pcvar_num(cvars_data[cvar_warmup_level_reward]))
	{
		return;
	}

	// For regular players add VIP for this map, for VIPs add 3 levels.
	if (gg_get_user_vip(winner))
	{
		increment_user_level(winner, get_pcvar_num(cvars_data[cvar_warmup_level_reward]) - user_data[winner][dataLevel] - 1, false);
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
	if (!is_user_alive(index) || !warmup_data[warmupEnabled] && weaponsData[user_data[index][dataLevel]][weaponCSW] != CSW_HEGRENADE || warmup_data[warmupEnabled] && warmup_data[warmupWeaponIndex] == CSW_HEGRENADE)
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
	if (!is_user_alive(index) || weaponsData[user_data[index][dataLevel]][weaponCSW] != CSW_KNIFE)
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
	toggle_spawn_protection(index, false);
}

public checkIdle(taskIndex)
{
	new index = taskIndex - TASK_IDLECHECK;

	// Return if player is not alive.
	if (!is_user_alive(index))
	{
		return;
	}

	new current_origin[3];

	// Get user position.
	get_user_origin(index, current_origin);

	if (!user_data[index][dataLastOrigin][0] && !user_data[index][dataLastOrigin][1] && !user_data[index][dataLastOrigin][2])
	{
		// Handle position update.
		ForRange(i, 0, 2)
		{
			user_data[index][dataLastOrigin][i] = current_origin[i];
		}

		return;
	}

	// Get distance from last position to current position.
	new last_origin[3];
	copy(last_origin, sizeof(last_origin), user_data[index][dataLastOrigin]); // Workaround with const argument in get_distance.

	new distance = get_distance(last_origin, current_origin);

	// Handle position update.
	ForRange(i, 0, 2)
	{
		user_data[index][dataLastOrigin][i] = current_origin[i];
	}

	if (distance < get_pcvar_num(cvars_data[cvar_idle_max_distance]))
	{
		// Slap player if he's camping, make sure not to kill him.
		if (++user_data[index][dataIdleStrikes] >= get_pcvar_num(cvars_data[cvar_idle_max_strikes]))
		{
			ForRange(i, 0, 1)
			{
				user_slap(index, !i ? (get_user_health(index) > get_pcvar_num(cvars_data[cvar_idle_slap_power]) ? get_pcvar_num(cvars_data[cvar_idle_slap_power]) : 0) : 0);
			}
		}
	}
	else
	{
		// Set user strikes back to 0.
		user_data[index][dataIdleStrikes] = 0;
		
		// Set user last position to 0.
		ForRange(i, 0, 2)
		{
			user_data[index][dataLastOrigin][i] = 0;
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
	if (!is_user_connected(index) || gungame_ended)
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
	client_print(index, print_center, "Odrodzenie za: %i", user_data[index][dataTimeToRespawn]);

	// Decrease respawn time.
	user_data[index][dataTimeToRespawn]--;
}

public displayHud(taskIndex)
{
	new index = taskIndex - TASK_DISPLAYHUD;

	if (!is_user_alive(index))
	{
		return;
	}

	new leader = get_game_leader(),
		leader_data[MAX_CHARS * 3],
		next_weapon[25];

	// Format leader's data if available.
	if (leader == -1)
	{
		formatex(leader_data, charsmax(leader_data), "^nLider: %s + %s", teamNames[0], teamNames[1]);
	}
	else
	{
		// We dont talk about that. Ever.
		if (game_mode == modeNormal)
		{
			formatex(leader_data, charsmax(leader_data), "^nLider: %n :: %i poziom [%s - %i/%i]",
					leader,
					user_data[leader][dataLevel] + 1,
					user_data[leader][dataLevel] == max_level ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[leader][dataLevel]]) : customWeaponNames[user_data[leader][dataLevel]],
					user_data[leader][dataWeaponKills],
					weaponsData[user_data[leader][dataLevel]][weaponKills]);
		}
		else
		{
			formatex(leader_data, charsmax(leader_data), "^nLider: %s :: %i poziom [%s - %i/%i]",
					teamNames[leader],
					user_data[leader][dataLevel] + 1,
					user_data[leader][dataLevel] == max_level ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[leader][dataLevel]]) : customWeaponNames[user_data[leader][dataLevel]],
					user_data[leader][dataWeaponKills],
					weaponsData[user_data[leader][dataLevel]][weaponTeamKills]);
		}
	}

	// Format next weapon name if available, change knife to wand if enabled so.
	if (user_data[index][dataLevel] == sizeof(weaponsData) - 2)
	{
		formatex(next_weapon, charsmax(next_weapon), get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[index][dataLevel] + 1]);
	}
	else
	{
		formatex(next_weapon, charsmax(next_weapon), is_on_last_level(index) ? "Brak" : customWeaponNames[user_data[index][dataLevel] + 1]);
	}

	// Display hud.
	set_hudmessage(hudColors[0], hudColors[1], hudColors[2], -1.0, 0.02, 0, 6.0, hudDisplayInterval + 0.1, 0.0, 0.0);
	
	if (game_mode == modeNormal)
	{
		ShowSyncHudMsg(index, hud_objects[hudObjectDefault], "-- Tryb normalny --^nTwoj poziom: %i/%i [%s - %i/%i] :: Zabic z rzedu: %i^nNastepna bron: %s%s",
			user_data[index][dataLevel] + 1,
			sizeof(weaponsData),
			is_on_last_level(index) ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[leader][dataLevel]]) : customWeaponNames[user_data[index][dataLevel]],
			user_data[index][dataWeaponKills],
			weaponsData[user_data[index][dataLevel]][weaponKills],
			user_data[index][dataCombo],
			next_weapon,
			leader_data);
	}
	else
	{
		new team = get_user_team(index) - 1;

		ShowSyncHudMsg(index, hud_objects[hudObjectDefault], "-- Tryb teamplay --^nPoziom druzyny: %i/%i [%s - %i/%i]^nNastepna bron: %s%s",
			tp_data[tpTeamLevel][team] + 1,
			sizeof(weaponsData),
			is_on_last_level(index) ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[leader][dataLevel]]) : customWeaponNames[user_data[index][dataLevel]],
			tp_data[tpTeamKills][team],
			weaponsData[user_data[index][dataLevel]][weaponTeamKills],
			next_weapon,
			leader_data);
	}
}

// Respawn player.
public respawnPlayerOnJoin(taskIndex)
{
	new index = taskIndex - TASK_RESPAWN_ON_JOIN;

	respawn_player(index, 0.1);
}

/*
		[ Database ]
*/

connectDatabase()
{
	new mysql_request[MAX_CHARS * 10];

	// Create mysql tuple.
	db_data[sqlHandle] = SQL_MakeDbTuple(db_data[dbHost], db_data[dbUser], db_data[dbPass], db_data[dbDbase]);

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request),
		"CREATE TABLE IF NOT EXISTS `gungame` \
			(`name` VARCHAR(35) NOT NULL, \
			`wins` INT(6) NOT NULL DEFAULT 0, \
			`knife_kills` INT(6) NOT NULL DEFAULT 0, \
			`kills` INT(6) NOT NULL DEFAULT 0, \
			`headshot_kills` INT(6) NOT NULL DEFAULT 0, \
		PRIMARY KEY (`name`));");

	// Send request to database.
	SQL_ThreadQuery(db_data[sqlHandle], "connectDatabaseHandler", mysql_request);
}

public connectDatabaseHandler(failState, Handle:query, error[], errorNumber, data[], dataSize)
{
	// Connection has succeded?
	db_data[sqlLoaded] = bool:(failState == TQUERY_SUCCESS);

	// Throw log to server's console if error occured.
	if (!db_data[sqlLoaded])
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

	new mysql_request[MAX_CHARS * 3],
		data[2];

	data[0] = index;

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request), "SELECT * FROM `gungame` WHERE `name` = '%s';", user_data[index][dataSafeName]);

	// Send request to database.
	SQL_ThreadQuery(db_data[sqlHandle], "getUserInfoDataHandler", mysql_request, data, charsmax(data));
}

// Read user wins from database.
public getUserInfoDataHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	new index = data[0];

	if (SQL_NumRows(query))
	{
		user_data[index][dataWins] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		user_data[index][dataKnifeKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "knife_kills"));
		user_data[index][dataHeadshots] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "headshot_kills"));
		user_data[index][dataKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
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

	new mysql_request[MAX_CHARS * 10];

	// Format request.
	formatex(mysql_request, charsmax(mysql_request),
		"INSERT INTO `gungame` \
			(`name`, `wins`, `knife_kills`, `kills`, `headshot_kills`) \
		VALUES \
			('%s', %i, %i, %i, %i);", user_data[index][dataSafeName], user_data[index][dataWins], user_data[index][dataKnifeKills], user_data[index][dataKills], user_data[index][dataHeadshots]);

	// Send request.
	SQL_ThreadQuery(db_data[sqlHandle], "ignoreHandle", mysql_request);
}

updateUserData(index)
{
	if (!is_user_connected(index) || is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	new mysql_request[MAX_CHARS * 10];

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request),
		"UPDATE `gungame` SET \
			`name` = '%s',\
			`wins` = %i,\
			`knife_kills` = %i,\
			`kills` = %i,\
			`headshot_kills` = %i \
		WHERE \
			`name` = '%s';", user_data[index][dataSafeName], user_data[index][dataWins], user_data[index][dataKnifeKills], user_data[index][dataKills], user_data[index][dataHeadshots], user_data[index][dataSafeName]);

	// Send request.
	SQL_ThreadQuery(db_data[sqlHandle], "ignoreHandle", mysql_request);
}

// Pretty much ignore any data that database sends back.
public ignoreHandle(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	return PLUGIN_CONTINUE;
}

loadTopPlayers()
{
	new mysql_request[MAX_CHARS * 3];

	// Format mysql request.
	formatex(mysql_request, charsmax(mysql_request), "SELECT * FROM `gungame` ORDER BY `wins` DESC LIMIT %i;", topPlayersDisplayed + 1);

	// Send request to database.
	SQL_ThreadQuery(db_data[sqlHandle], "loadTopPlayersHandler", mysql_request);
}

public loadTopPlayersHandler(failState, Handle:query, error[], errorNumber, data[], dataSize)
{
	new iterator;

	// Load top players while there are any.
	while (SQL_MoreResults(query))
	{
		// Get top player name.
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), top_players[iterator][topNames], MAX_CHARS - 1);
		
		// Assign his info to variables.
		top_players[iterator][topWins] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		top_players[iterator][topKnifeKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "knife_kills"));
		top_players[iterator][topHeadshots] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "headshot_kills"));
		top_players[iterator][topKills] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));

		// Iterate loop.
		iterator++;

		// Go to next result.
		SQL_NextRow(query);
	}

	// Database laoded successfully.
	top_data[topDataLoaded] = true;

	// Create motd.
	create_top_players_motd();
}

/*
		[ FUNCTIONS ]
*/

set_progress_bar(index, Float:time, start = 0)
{
	static barMessageHandle;
	
	if (!barMessageHandle)
	{
		barMessageHandle = get_user_msgid("BarTime2");
	}
	
	message_begin(index ? MSG_ONE : MSG_ALL, barMessageHandle, _, index);
	write_short(floatround(time));
	write_short(start);
	message_end();
}

save_on_disconnect(index)
{
	ArrayPushCell(disconnected_players_data[dcDataLevel], user_data[index][dataLevel]);
	ArrayPushCell(disconnected_players_data[dcDataWeaponKills], user_data[index][dataWeaponKills]);
	ArrayPushString(disconnected_players_data[dcDataName], user_data[index][dataName]);
}

get_on_connect(index)
{
	static name[MAX_CHARS];

	ForDynamicArray(i, disconnected_players_data[dcDataName])
	{
		ArrayGetString(disconnected_players_data[dcDataName], i, name, charsmax(name));

		// Not our guy.
		if (!equal(name, user_data[index][dataName]))
		{
			continue;
		}

		// Set new level and weapon kills.
		user_data[index][dataLevel] = ArrayGetCell(disconnected_players_data[dcDataLevel], i);
		user_data[index][dataWeaponKills] = ArrayGetCell(disconnected_players_data[dcDataWeaponKills], i);

		// Delete data from dynamic arrays.
		ArrayDeleteItem(disconnected_players_data[dcDataLevel], i);
		ArrayDeleteItem(disconnected_players_data[dcDataWeaponKills], i);
		ArrayDeleteItem(disconnected_players_data[dcDataName], i);

		break;
	}
}

get_user_name_data(index)
{
	if (is_user_hltv(index) || is_user_bot(index))
	{
		return;
	}

	// Get player's name once, so we dont do that every time we need that data.
	get_user_name(index, user_data[index][dataName], MAX_CHARS - 1);

	// Clamp down player's name so we can use that to prevent char-overflow in HUD etc.
	clamp_down_client_name(index, user_data[index][dataShortName], MAX_CHARS - 1, maxNicknameLength, nicknameReplaceToken);

	// Get player's name to mysql-request-safe state.
	escape_string(user_data[index][dataName], user_data[index][dataSafeName], MAX_CHARS * 2);
}

escape_string(const source[], output[], length)
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

load_sql_config()
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
		db_data[sqlConfigFound] = false;

		return;
	}

	new file_handle = fopen(sqlConfigPath, "r"),
		line_content[MAX_CHARS * 10],
		key[MAX_CHARS * 5],
		value[MAX_CHARS * 5],
		entries;

	while (file_handle && !feof(file_handle) && entries < sizeof(sqlConfigLabels))
	{
		// Read one line at a time.
		fgets(file_handle, line_content, charsmax(line_content));
		
		// Replace newlines with a null character.
		replace(line_content, charsmax(line_content), "^n", "");
		
		// Blank line or comment.
		if (!line_content[0] || line_content[0] == ';')
		{
			continue;
		}
		
		// Get key and value.
		strtok(line_content, key, charsmax(key), value, charsmax(value), '=');
		
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
				case 0: copy(db_data[dbHost], MAX_CHARS * 2, value);
				case 1: copy(db_data[dbUser], MAX_CHARS * 2, value);
				case 2: copy(db_data[dbPass], MAX_CHARS * 2, value);
				case 3: copy(db_data[dbDbase], MAX_CHARS * 2, value);
			}

			entries++;
		
			break;
		}
	}

	db_data[sqlConfigFound] = true;
}

load_game_cvars()
{
	ForArray(i, gameCvars)
	{
		set_cvar_num(gameCvars[i][0], str_to_num(gameCvars[i][1]));
	}
}

bool:is_on_last_level(index)
{
	return bool:(user_data[index][dataLevel] == max_level);
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

create_top_players_motd()
{
	new players_displayed;

	// Add HTML code to string in a loop.
	ForArray(i, topPlayersMotdHTML)
	{
		top_data[topMotdLength] += formatex(top_data[topMotdCode][top_data[topMotdLength]], charsmax(top_data[topMotdCode]), topPlayersMotdHTML[i]);
	}

	ForRange(i, 0, topPlayersDisplayed - 1)
	{
		// Continue if player has no wins at all.
		if (!top_players[i][topWins])
		{
			continue;
		}

		// Add HTML to motd.
		top_data[topMotdLength] += formatex(top_data[topMotdCode][top_data[topMotdLength]], charsmax(top_data[topMotdCode]),
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
			i + 1, top_players[i][topNames], top_players[i][topWins], top_players[i][topKnifeKills], floatround(top_players[i][topHeadshots] / top_players[i][topKills] * 100.0));

		players_displayed++;
	}

	// Format motd title.
	formatex(top_data[topMotdName], charsmax(top_data[topMotdName]), "Top %i graczy GunGame", players_displayed);

	top_data[topMotdCreated] = true;
}

remove_idle_check(index)
{
	// AFK-check task exists?
	if (task_exists(index + TASK_IDLECHECK))
	{
		// Remove AFK-check task.
		remove_task(index + TASK_IDLECHECK);
		
		// Set last user position to 0 to prevent bugs with respawning close to death-place.
		ForRange(i, 0, 2)
		{
			user_data[index][dataLastOrigin][i] = 0;
		}
	
		// Set AFK-strikes to zero.
		user_data[index][dataIdleStrikes] = 0;
	}
}

give_warmup_weapons(index)
{
	// Return if player is not alive.
	if (!is_user_alive(index))
	{
		return;
	}

	// Strip weapons.
	remove_player_weapons(index);

	user_data[index][dataAllowedWeapons] = (1 << CSW_KNIFE);

	// Give knife as a default weapon.
	give_item(index, "weapon_knife");
	
	if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) > -1)
	{
		new weapon_name[MAX_CHARS - 1],
			weapon = get_pcvar_num(cvars_data[cvar_warmup_weapon]),
			weapon_entity;
	
		user_data[index][dataAllowedWeapons] |= (1 << weapon);

		// Get warmup weapon entity classname.
		get_weaponname(weapon, weapon_name, charsmax(weapon_name));

		weapon_entity = give_item(index, weapon_name);

		// Set weapon backpack ammo.
		if (weapon == CSW_AWP)
		{
			cs_set_user_bpammo(index, weapon, 100);
			cs_set_weapon_ammo(weapon_entity, 1);
		}
		else
		{
			cs_set_user_bpammo(index, weapon, 100);
		}
	}

	// Add random warmup weapon multiple times.
	else if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -1)
	{
		new weapon = get_weaponid(weapon_entity_names[warmup_data[warmupWeaponIndex]]);

		user_data[index][dataAllowedWeapons] |= (1 << weapon);

		// Add weapon.
		give_item(index, weapon_entity_names[warmup_data[warmupWeaponIndex]]);

		cs_set_user_bpammo(index, weapon, 100);
		// Set weapon bp ammo.
		// if (weapon == CSW_AWP)
		// {
		// 	cs_set_user_bpammo(index, weapon, 100);
		// }
		// else
		// {
		// 	cs_set_user_bpammo(index, weapon, 100);
		// }
	}

	// Set wand model.
	else if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -2)
	{
		set_wand_models(index);
	}

	// Add random weapon.
	else if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == -3)
	{
		random_warmup_weapon(index);
	}
}

// Remove quotes from message.
get_chat_message_arguments(message[], length)
{
	// Get message arguments.
	read_args(message, length);

	// Get rid of quotes.
	remove_quotes(message);
}

get_first_argument(word[], wordLength, string[], stringLength)
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

bool:is_he_grenade(entity)
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

set_wand_models(index)
{
	// Set V and P wand models.
	set_pev(index, pev_viewmodel2, wandModels[0]);
	set_pev(index, pev_weaponmodel2, wandModels[1]);
}

set_weapon_animation(index, animation)
{
	// Set weapon animation.
	set_pev(index, pev_weaponanim, animation);

	// Display animation.
	message_begin(1, 35, _, index);
	write_byte(animation);
	write_byte(pev(index, pev_body));
	message_end();
}

remove_weapons_off_ground()
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

show_player_info(index, target)
{
	if (is_user_connected(target))
	{
		ColorChat(index, RED, "%s^x01 Gracz ^x04%n^x01 jest na poziomie^x04 %i^x01 [^x04%s^x01 - ^x04%i^x01/^x04%i^x01]. Wygral ^x04%i^x01 razy. Status uslugi:^x04 %s^x01.",
			chatPrefix,
			target,
			user_data[target][dataLevel] + 1,
			is_on_last_level(target) ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[target][dataLevel]]) : customWeaponNames[user_data[target][dataLevel]],
			user_data[target][dataWeaponKills],
			weaponsData[user_data[target][dataLevel]][game_mode == modeNormal ? weaponKills : weaponTeamKills],
			user_data[target][dataWins],
			gg_get_user_vip(target) ? "VIP" : "Brak");
	}
	else
	{
		ColorChat(index, RED, "%s^x01 %s", chatPrefix, target == -1 ? "Wiecej niz jeden gracz pasuje do podanego nicku." : " Gracz o tym nicku nie zostal znaleziony.");
	}
}

randomize_sound_index(soundType)
{
	// Create dynamic array to store valid sound indexes.
	new Array:sound_indexes = ArrayCreate(1, 1);

	// Iterate through sounds array to find valid sounds, then add them to dynamic array.
	ForRange(j, 0, maxSounds - 1)
	{
		if (strlen(soundsData[soundType][j]))
		{
			ArrayPushCell(sound_indexes, j);
		}
	}

	// Randomize valid index read from dynamic array.
	new sound_index = ArrayGetCell(sound_indexes, random_num(0, ArraySize(sound_indexes) - 1));
	
	// Get rid of array to save data space.
	ArrayDestroy(sound_indexes);

	return sound_index;
}

play_sound(index, soundType, sound_index, bool:emitSound)
{
	// Sound index is set to random?
	if (sound_index < 0)
	{
		sound_index = randomize_sound_index(soundType);
	}

	// Emit sound directly from entity?
	if (emitSound)
	{
		emit_sound(index, CHAN_AUTO, soundsData[soundType][sound_index], soundsVolumeData[soundType][sound_index], ATTN_NORM, (1 << 8), PITCH_NORM);
	}
	else
	{
		client_cmd(index, "%s ^"%s^"", defaultSoundCommand, soundsData[soundType][sound_index]);
	}
}

play_sound_for_team(team, soundType, sound_index, bool:emitSound)
{
	// Sound index is set to random?
	if (sound_index < 0)
	{
		sound_index = randomize_sound_index(soundType);
	}

	// Emit sound directly from entity?
	if (emitSound)
	{
		ForTeam(i, team)
		{
			emit_sound(i, CHAN_AUTO, soundsData[soundType][sound_index], soundsVolumeData[soundType][sound_index], ATTN_NORM, (1 << 8), PITCH_NORM);
		}
	}
	else
	{
		ForTeam(i, team)
		{
			client_cmd(i, "%s ^"%s^"", defaultSoundCommand, soundsData[soundType][sound_index]);
		}
	}
}

toggle_warmup(bool:status)
{
	warmup_data[warmupWeaponNameIndex] = -1;
	warmup_data[warmupEnabled] = status;

	set_warmup_hud(status);

	// Warmup set to disabled?
	if (!warmup_data[warmupEnabled])
	{
		finish_game_vote();

		if (game_mode == modeNormal)
		{
			// Get warmup winner based on kills.
			new winner = get_warmup_winner();

			// Set task to reward winner after game restart.
			if (is_user_connected(winner))
			{
				set_task(2.0, "rewardWarmupWinner", winner + TASK_REWARDWINNER);
			}

			ExecuteForward(forward_handles[forward_game_beginning], forward_return_dummy, winner);
		}
		else
		{
			ExecuteForward(forward_handles[forward_game_beginning], forward_return_dummy, -1);
		}

		// Restart the game.
		set_cvar_num("sv_restartround", 1);

		// Play gungame start sound.
		play_sound(0, soundGameStart, -1, false);
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
		warmup_data[warmupWeaponIndex] = random_num(0, sizeof(customWeaponNames) - 2);

		// Play warmup start sound.
		play_sound(0, soundWarmup, -1, true);

		set_game_vote();
	}
}

// Set timer HUD task.
set_warmup_hud(bool:status)
{
	if (status)
	{
		set_task(1.0, "displayWarmupTimer");

		warmup_data[warmupTimer] = get_pcvar_num(cvars_data[cvar_warmup_duration]);
	}
}

toggle_spawn_protection(index, bool:status)
{
	// Toggle spawn protection on index.
	user_data[index][dataSpawnProtection] = status;

	// Toggle godmode.
	if (get_pcvar_num(cvars_data[cvar_spawn_protection_type]))
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
show_hud(index)
{
	set_task(hudDisplayInterval, "displayHud", index + TASK_DISPLAYHUD, .flags = "b");
}

// Remove hud display task.
remove_hud(index)
{
	if (task_exists(index + TASK_DISPLAYHUD))
	{
		remove_task(index + TASK_DISPLAYHUD);
	}
}

respawn_player(index, Float:time)
{
	// Player already respawned?
	if (is_user_alive(index))
	{
		return;
	}

	new user_team = get_user_team(index);

	// Not interested in spectator and unassigned players.
	if (user_team != 1 && user_team != 2)
	{
		return;
	}

	// Get respawn time to int.
	new int_time = floatround(time, floatround_round);

	// Set user respawn time to integer value.
	user_data[index][dataTimeToRespawn] = int_time;

	// Set tasks to notify about timeleft to respawn.
	ForRange(i, 0, int_time - 1)
	{
		set_task(float(i), "respawnNotify", index + TASK_NOTIFY);
	}

	// Set an actuall respawn function delayed.
	set_task(time, "clientRespawn", index + TASK_RESPAWN);
}

increment_user_weapon_kills(index, value)
{
	// Set kills required and killstreak.
	user_data[index][dataCombo] += value;
	user_data[index][dataWeaponKills] += value;

	ExecuteForward(forward_handles[forward_combo_streak], forward_return_dummy, index, user_data[index][dataCombo]);

	// Levelup player if weapon kills are greater than reqiured for his current level.
	while (user_data[index][dataWeaponKills] >= weaponsData[user_data[index][dataLevel]][weaponKills])
	{
		increment_user_level(index, 1, true);
	}
}

increment_team_weapon_kills(team, value)
{
	tp_data[tpTeamKills][team - 1] += value;

	while (tp_data[tpTeamKills][team - 1] >= weaponsData[tp_data[tpTeamLevel][team - 1]][weaponTeamKills])
	{
		increment_team_level(team, 1, true);
	}
}

// Decrement weapon kills, take care of leveldown.
decrement_user_weapon_kills(index, value, bool:levelLose)
{
	user_data[index][dataWeaponKills] -= value;

	if (levelLose && user_data[index][dataWeaponKills] < 0)
	{
		decrement_user_level(index, 1);
	}

	if (user_data[index][dataWeaponKills] < 0)
	{
		user_data[index][dataWeaponKills] = 0;
	}
}

// Decrement weapon kills, take care of leveldown.
decrement_team_weapon_kills(team, value, bool:levelLose)
{
	tp_data[tpTeamKills][team - 1] -= value;

	if (tp_data[tpTeamKills][team - 1] < 0)
	{
		tp_data[tpTeamKills][team - 1] = 0;
	}

	ForTeam(i, team)
	{
		user_data[i][dataWeaponKills] = tp_data[tpTeamKills][team - 1];
	}

	if (!levelLose)
	{
		return;
	}

	decrement_team_level(team, 1);
}

increment_user_level(index, value, bool:notify)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	user_data[index][dataWeaponKills] -= weaponsData[user_data[index][dataLevel]][weaponKills];
	user_data[index][dataLevel] = (user_data[index][dataLevel] + value > max_level ? max_level : user_data[index][dataLevel] + value);

	// Levelup effect.
	display_levelup_sprite(index);

	// Make sure player's kills are positive.
	if (user_data[index][dataWeaponKills] < 0)
	{
		user_data[index][dataWeaponKills] = 0;
	}

	// Add weapons for player's current level.
	give_weapons(index);

	ExecuteForward(forward_handles[forward_level_up], forward_return_dummy, index, user_data[index][dataLevel], -1);

	if (notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Gracz^x04 %n^x01 awansowal na poziom^x04 %i^x01 ::^x04 %s^x01.",
			chatPrefix,
			index,
			user_data[index][dataLevel] + 1,
			user_data[index][dataLevel] == max_level ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[user_data[index][dataLevel]]) : customWeaponNames[user_data[index][dataLevel]]);
		
		// Play levelup sound.
		play_sound(index, soundLevelUp, -1, false);
	}
}

increment_team_level(team, value, bool:notify)
{
	// Set weapon kills based on current level required kills. Set new level if valid number.
	tp_data[tpTeamKills][team - 1] = 0;
	tp_data[tpTeamLevel][team - 1] = (tp_data[tpTeamLevel][team - 1] + value > max_level ? max_level : tp_data[tpTeamLevel][team - 1] + value);

	ForTeam(i, team)
	{
		user_data[i][dataLevel] = tp_data[tpTeamLevel][team - 1];
		user_data[i][dataWeaponKills] = tp_data[tpTeamKills][team - 1];

		// Levelup effect.
		display_levelup_sprite(i);

		// Add weapons.
		give_weapons(i);
	
		ExecuteForward(forward_handles[forward_level_up], forward_return_dummy, i, tp_data[tpTeamLevel][team - 1], team);
	}

	if (notify)
	{
		// Notify about levelup.
		ColorChat(0, RED, "%s^x01 Druzyna^x04 %s^x01 awansowala na poziom^x04 %i^x01 ::^x04 %s^x01.",
			chatPrefix,
			teamNames[team - 1],
			tp_data[tpTeamLevel][team - 1] + 1,
			tp_data[tpTeamLevel][team - 1] == max_level ? (get_pcvar_num(cvars_data[cvar_wand_enabled]) ? "Rozdzka" : customWeaponNames[tp_data[tpTeamLevel][team - 1]]) : customWeaponNames[tp_data[tpTeamLevel][team - 1]]);
	}
}

display_levelup_sprite(index)
{
	new Float:user_origin[3];

	pev(index, pev_origin, user_origin);

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, user_origin, 0);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, user_origin[0]);
	engfunc(EngFunc_WriteCoord, user_origin[1]);
	engfunc(EngFunc_WriteCoord, user_origin[2]);
	engfunc(EngFunc_WriteCoord, user_origin[0]);
	engfunc(EngFunc_WriteCoord, user_origin[1]);
	engfunc(EngFunc_WriteCoord, user_origin[2] + spriteLevelupZaxis);
	write_short(sprite_levelup_index);
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

decrement_user_level(index, value)
{
	// Decrement user level, make sure his level is not negative.
	user_data[index][dataLevel] = (user_data[index][dataLevel] - value < 0 ? 0 : user_data[index][dataLevel] - value);
	user_data[index][dataWeaponKills] = 0;

	// Play leveldown sound.
	play_sound(index, soundLevelDown, -1, false);

	ExecuteForward(forward_handles[forward_level_down], forward_return_dummy, index, user_data[index][dataLevel], -1);
}

decrement_team_level(team, value)
{
	// Decrement team level and kills, make sure level is not negative.
	tp_data[tpTeamLevel][team - 1] = (tp_data[tpTeamLevel][team - 1] - value < 0 ? 0 : tp_data[tpTeamLevel][team - 1] - value);
	tp_data[tpTeamKills][team - 1] = 0;

	// Update level and kills of players in the team.
	ForTeam(i, team)
	{
		user_data[i][dataLevel] = tp_data[tpTeamLevel][team - 1];
		user_data[i][dataWeaponKills] = tp_data[tpTeamKills][team - 1];
	
		ExecuteForward(forward_handles[forward_level_down], forward_return_dummy, i, tp_data[tpTeamLevel][team - 1], team);
	}

	// Play leveldown sound.
	play_sound_for_team(team, soundLevelDown, -1, false);
}

end_gungame(winner)
{
	// Mark gungame as ended.
	gungame_ended = true;

	ExecuteForward(forward_handles[forward_game_end], forward_return_dummy, winner);

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

		remove_hud(i);
		updateUserData(i);
	}

	new win_message[MAX_CHARS * 10],
		temp_message[MAX_CHARS * 5],
		top_players[topPlayersDisplayed + 1],
		index;

	// Set black screen.
	set_black_screen_fade(2);

	// Recursevly set black screen every second so player has it colored no matter what.
	set_task(1.0, "set_black_screen_on");

	// Update top players.
	loadTopPlayers();

	// Get top players.
	get_player_by_top_level(top_players, charsmax(top_players));

	// Reward winner.
	user_data[winner][dataWins]++;

	// Format win message.
	formatex(win_message, charsmax(win_message), "%s^nTopowi gracze:^n^n^n^n", chatPrefix);

	// Format top players message.
	ForArray(i, top_players)
	{
		index = top_players[i];

		if (!is_user_connected(index) || is_user_hltv(index))
		{
			continue;
		}

		formatex(temp_message, charsmax(temp_message), "^n^n%i. %s (%i lvl - %s [%i fragow] [wygranych: %i])",
			i + 1,
			user_data[index][dataShortName],
			user_data[index][dataLevel] + 1,
			customWeaponNames[user_data[index][dataLevel]],
			get_user_frags(index),
			user_data[index][dataWins]);

		add(win_message, charsmax(win_message), temp_message, charsmax(temp_message));
	}

	// Play game win sound to winner.
	play_sound(winner, soundAnnounceWinner, -1, false);

	// Display formated win message.
	set_hudmessage(255, 255, 255, -1.0, -1.0, 0, 6.0, blackScreenTimer, 0.0, 0.0);
	ShowSyncHudMsg(0, hud_objects[hudObjectDefault], win_message);

	// Vote for next map.
	showMapVoteMenu();
}

give_weapons(index)
{
	if (!is_user_alive(index))
	{
		return;
	}

	// We dont want players to have armor.
	set_user_armor(index, get_pcvar_num(cvars_data[cvar_default_armor_level]));

	// Strip weapons.
	remove_player_weapons(index);

	// Reset player allowed weapons and add knife.
	user_data[index][dataAllowedWeapons] = (1 << CSW_KNIFE);

	// Add wand if player is on last level and such option is enabled.
	if (user_data[index][dataLevel] != max_level)
	{
		// Add weapon couple of times to make sure backpack ammo is right.
		new csw = get_weaponid(weapon_entity_names[user_data[index][dataLevel]]),
			weapon_entity;

		// Add weapon to allowed to carry by player.
		user_data[index][dataAllowedWeapons] |= (1 << weaponsData[user_data[index][dataLevel]][weaponCSW]);

		weapon_entity = give_item(index, weapon_entity_names[user_data[index][dataLevel]]);

		if (csw != CSW_HEGRENADE && csw != CSW_KNIFE && csw != CSW_FLASHBANG)
		{
			if (csw == CSW_AWP)
			{
				cs_set_user_bpammo(index, csw, 100);
				cs_set_weapon_ammo(weapon_entity, 1);
			}
			else
			{
				cs_set_user_bpammo(index, csw, 100);
			}
		}

		// Deploy primary weapon.
		engclient_cmd(index, weapon_entity_names[user_data[index][dataLevel]]);

		// Add knife last so the primary weapon gets drawn out (dont switch to powerful weapon fix).
		give_item(index, "weapon_knife");
	}
	else
	{
		// Add knife first, so the models can be set.
		give_item(index, "weapon_knife");

		// Set wand model.
		if (get_pcvar_num(cvars_data[cvar_wand_enabled]))
		{
			set_wand_models(index);
		}
		else
		{
			// Add two flashes.
			if (get_pcvar_num(cvars_data[cvar_flashes_enabled]))
			{
				user_data[index][dataAllowedWeapons] |= (1 << CSW_FLASHBANG);

				ForRange(i, 0, 1)
				{
					give_item(index, "weapon_flashbang");
				}
			}
		}
	}
}

get_warmup_winner()
{
	// Return if warmup reward is none.
	if (get_pcvar_num(cvars_data[cvar_warmup_level_reward]) < 2)
	{
		return 0;
	}

	new winner,
		Array:candidates = ArrayCreate(2, 32);

	// Collect all players data
	ForPlayers(i)
	{
		if (is_user_connected(i) && !is_user_hltv(i))
		{
			new data_set[4];

			data_set[0] = i; // id
			data_set[1] = get_user_frags(i); // frags
			data_set[2] = get_user_deaths(i); // deaths

			ArrayPushArray(candidates, data_set);
		}
	}

	ArraySortEx(candidates, "sort_players_by_kills");

	new candidates_amount = ArraySize(candidates);

	if (candidates_amount == 0)
	{
		// There is no winner, no real players on server
		return 0;
	}
	// Check if top player is best by frags only
	
	// Only one player
	if (candidates_amount == 1)
	{
		new player[4];

		ArrayGetArray(candidates, 0, player);

		winner = player[0];

		announce_warmup_winner(winner);
		
		ArrayDestroy(candidates);

		return winner;
	}
	// More players
	else if (candidates_amount >= 2)
	{
		new top1_player[4],
			top2_player[4];

		ArrayGetArray(candidates, 0, top1_player);
		ArrayGetArray(candidates, 1, top2_player);

		if (top1_player[1] > top2_player[1])
		{
			winner = top1_player[0];

			ArrayDestroy(candidates);
			
			announce_warmup_winner(winner);

			return winner;
		}
		else if (top1_player[1] < top2_player[1])
		{
			winner = top2_player[0];
			
			ArrayDestroy(candidates);

			announce_warmup_winner(winner);

			return winner;
		}
		// Else top players are ex aequo, let's choose by kills and deaths difference
	}

	ArraySortEx(candidates, "sort_players_by_kills_death_difference");

	// Get only players with best score
	new Array:best_players = ArrayCreate(2, 32);
	new candidate_data[3];
	ArrayGetArray(candidates, 0, candidate_data);

	new maximum = candidate_data[1] + candidate_data[2]; // Get top player
	new top_frags = candidate_data[1];
	if (top_frags > 0) // Best player has killed someone = not everybody has 0:0 stats
	{
		ForDynamicArray(i, candidates)
		{
			ArrayGetArray(candidates, i, candidate_data);
			if (candidate_data[1] < maximum)
			{
				break;
			}
			ArrayPushArray(best_players, candidate_data);
		}

		// Only player with top score, he's the winner
		new best_players_amount = ArraySize(best_players);
		if (best_players_amount == 1)
		{
			ArrayGetArray(best_players, 0, candidate_data);
			winner = candidate_data[0];
		}
		else // There are more players with top score, let's randomly choose one
		{
			new choosen = random_num(0, best_players_amount - 1);
			ArrayGetArray(best_players, choosen, candidate_data);
			winner = candidate_data[0];
		}

		announce_warmup_winner(winner);
	}
	else if (top_frags == 0) // No one got killed
	{
		winner = 0;
	}

	ArrayDestroy(candidates);
	ArrayDestroy(best_players);

	return winner;
}

announce_warmup_winner(winner)
{
	// Print win-message couple times in chat.
	if (is_user_connected(winner))
	{
		ForRange(i, 0, 2)
		{
			if (gg_get_user_vip(winner))
			{
				ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode zaczyna GunGame z poziomem^x04 %i^x01!", chatPrefix, winner, get_pcvar_num(cvars_data[cvar_warmup_level_reward]));
			}
			else
			{
				ColorChat(0, RED, "%s^x01 Zwyciezca rozgrzewki:^x04 %n^x01! W nagrode otrzymuje VIPA do konca mapy!", chatPrefix, winner);
			}
		}
	}
}

public sort_players_by_kills(Array:array, elem1[], elem2[], const data[], data_size)
{
	new p1_kills = elem1[1];
	new p2_kills = elem2[1];

	if (p1_kills > p2_kills)
	{
		return -1;
	}
	else if (p1_kills < p2_kills)
	{
		return 1;
	}
	return 0;
}

public sort_players_by_kills_death_difference(Array:array, elem1[], elem2[], const data[], data_size)
{
	new p1_kills = elem1[1];
	new p1_deaths = elem1[2];

	new p2_kills = elem2[1];
	new p2_deaths = elem2[2];

	new p1_difference = p1_kills - p1_deaths;
	new p2_difference = p2_kills - p2_deaths;

	if (p1_difference > p2_difference)
	{
		return -1;
	}
	else if (p1_difference < p2_difference)
	{
		return 1;
	}
	return 0;
}

get_weapons_name(iterator, weaponIndex, string[], length)
{
	// Get weapon classname.
	get_weaponname(weaponIndex, weapon_entity_names[iterator], charsmax(weapon_entity_names[]));

	// Get rid of "weapon_" prefix.
	copy(weapon_temp_name, charsmax(weapon_temp_name), weapon_entity_names[iterator][7]);
	
	// Get weapon name to upper case.
	strtoupper(weapon_temp_name);

	// Copy weapon name to original output.
	copy(string, length, weapon_temp_name);
}

get_game_leader()
{
	new highest;
	
	if (game_mode == modeNormal)
	{
		highest = 0;

		// Loop through all players, get one with highest level and kills.
		ForPlayers(i)
		{
			if (!is_user_connected(i))
			{
				continue;
			}
			
			if (user_data[i][dataLevel] > user_data[highest][dataLevel])
			{
				highest = i;
			}

			else if (user_data[i][dataLevel] == user_data[highest][dataLevel])
			{
				if (user_data[i][dataWeaponKills] > user_data[highest][dataWeaponKills])
				{
					highest = i;
				}
			}
		}
	}
	else if (game_mode == modeTeamplay)
	{
		// Get leading team by level.
		if (tp_data[tpTeamLevel][0] == tp_data[tpTeamLevel][1])
		{
			highest = -1;
		}
		else if(tp_data[tpTeamLevel][0] > tp_data[tpTeamLevel][1])
		{
			highest = 0;
		}
		else
		{
			highest = 1;
		}

		// Get leading team by kills if they're at the same level.
		if (highest == -1)
		{
			if (tp_data[tpTeamKills][0] == tp_data[tpTeamKills][1])
			{
				highest = -1;
			}
			else if(tp_data[tpTeamKills][0] > tp_data[tpTeamKills][1])
			{
				highest = 1;
			}
			else
			{
				highest = 0;
			}
		}
	}

	return highest;
}

get_current_lowest_level()
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
		if (!is_user_connected(i) || user_data[i][dataLevel] > lowest)
		{
			continue;
		}

		lowest = user_data[i][dataLevel];
	}

	return lowest;
}

get_player_by_name(name[])
{
	// Get rid of white spaces.
	trim(name);

	// Return error value if name was not specified.
	if (!strlen(name))
	{
		// Throw error to server console.
		#if defined DEBUG_MODE
		
		log_amx("Function: get_player_by_name ^"name^" argument's length is %i.", name, strlen(name));
		
		#endif

		return -2;
	}

	new found_player_index,
		players_found;

	// Loop through players, get index if names are matching.
	ForPlayers(i)
	{
		if (!is_user_connected(i) || containi(user_data[i][dataName], name) == -1)
		{
			continue;
		}
		
		players_found++;
			
		found_player_index = i;
	}

	// Return -1 if found more than one guy.
	if (players_found > 1)
	{
		return -1;
	}

	return found_player_index;
}

get_player_by_top_level(array[], count)
{
	new highest_levels[MAX_PLAYERS + 1],
		counter;

	ForPlayers(index)
	{
		if (!is_user_connected(index))
		{
			continue;
		}

		for (new i = count - 1; i >= 0; i--)
		{
			if (highest_levels[i] < user_data[index][dataLevel] + 1 && i)
			{
				continue;
			}

			if (highest_levels[i] >= user_data[index][dataLevel] + 1 && i < count - 1)
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
				highest_levels[j + 1] = highest_levels[j];

				array[j + 1] = array[j];
			}

			highest_levels[counter] = user_data[index][dataLevel] + 1;
			array[counter] = index;
		}
	}
}

get_warmup_weapon_name()
{
	// Return if warmup weapon is static.
	if (warmup_data[warmupWeaponNameIndex] > -1)
	{
		return;
	}

	// Loop through all weapons, find one with same ID as warmup weapon.
	ForArray(i, weaponsData)
	{
		if (get_pcvar_num(cvars_data[cvar_warmup_weapon]) == weaponsData[i][weaponCSW])
		{
			warmup_data[warmupWeaponNameIndex] = i;

			break;
		}
	}
}

refill_ammo(index, bool:team = false)
{
	// Return if player is not alive or gungame has ended.
	if (gungame_ended)
	{
		return;
	}

	static userWeapon,
		weapon_classname[MAX_CHARS - 1],
		weapon_entity;

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
			get_weaponname(userWeapon, weapon_classname, charsmax(weapon_classname));

			// Get entity index of player's weapon.
			weapon_entity = find_ent_by_owner(-1, weapon_classname, i);

			// Continue if weapon index is invalid.
			if (!weapon_entity)
			{
				continue;
			}

			// Refill weapon ammo.
			cs_set_weapon_ammo(weapon_entity, ammoAmounts[userWeapon]);
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
		get_weaponname(userWeapon, weapon_classname, charsmax(weapon_classname));

		// Get entity index of player's weapon.
		weapon_entity = find_ent_by_owner(-1, weapon_classname, index);

		// Return if weapon index is invalid.
		if (!weapon_entity)
		{
			return;
		}

		// Refill weapon ammo.
		cs_set_weapon_ammo(weapon_entity, ammoAmounts[userWeapon]);
	}
}

random_warmup_weapon(index)
{
	// Return if player is not alive or warmup is not enabled.
	if (!is_user_alive(index) || !warmup_data[warmupEnabled])
	{
		return;
	}

	new csw,
		weapon_classname[MAX_CHARS - 1],
		weapons_array_index = random_num(0, sizeof(weaponsData) - 2);

	// Get random index from weaponsData array.
	csw = weaponsData[weapons_array_index][0];

	// Get classname of randomized weapon.
	get_weaponname(csw, weapon_classname, charsmax(weapon_classname));

	user_data[index][dataAllowedWeapons] |= (1 << csw);

	// Add weapon to player.
	give_item(index, weapon_classname);

	// Set weapon bp ammo to 100.
	cs_set_user_bpammo(index, csw, 100);

	user_data[index][dataWarmupWeapon] = csw;
	user_data[index][dataWarmupCustomWeaponIndex] = weapons_array_index;
}

// Clamp down user name if its length is greater than "value" argument.
clamp_down_client_name(index, output[], length, const value, const token[])
{
	if (strlen(user_data[index][dataName]) > value)
	{
		format(output, value, user_data[index][dataName]);

		add(output, length, token);
	}
	else
	{
		// Just copy his original name instead.
		copy(user_data[index][dataShortName], MAX_CHARS - 1, user_data[index][dataName]);
	}
}

wand_attack(index, weapon)
{
	// He ded >.<
	if (!is_user_alive(index))
	{
		return PLUGIN_HANDLED;
	}

	// Wand enabled?
	if (!get_pcvar_num(cvars_data[cvar_wand_enabled]))
	{
		return PLUGIN_HANDLED;
	}

	if (weapon != CSW_KNIFE)
	{
		return PLUGIN_HANDLED;
	}
	
	// Not on last level & not a warmup.
	if (!warmup_data[warmupEnabled] && !is_on_last_level(index))
	{
		return PLUGIN_HANDLED;
	}

	// Warmup weapon is not wand.
	if (warmup_data[warmupEnabled] && get_pcvar_num(cvars_data[cvar_warmup_weapon]) != -2)
	{
		return PLUGIN_HANDLED;
	}

	// Cooldown is still on.
	if (user_data[index][dataWandLastAttack] + get_pcvar_float(cvars_data[cvar_wand_attack_interval]) > get_gametime())
	{
		return PLUGIN_HANDLED;
	}

	new end_origin[3],
		start_origin[3];

	// Get player position and end position.
	get_user_origin(index, start_origin, 0);
	get_user_origin(index, end_origin, 3);

	// Block shooting if distance is too high.
	if (get_distance(start_origin, end_origin) > get_pcvar_num(cvars_data[cvar_wand_attack_max_distance]))
	{
		return PLUGIN_HANDLED;
	}

	// Animate attacking.
	set_weapon_animation(index, 1);

	// Show progress bar
	set_progress_bar(index, get_pcvar_float(cvars_data[cvar_wand_attack_interval]));

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
	write_coord(end_origin[0]);
	write_coord(end_origin[1]);
	write_coord(end_origin[2]);
	write_short(wand_sprites_indexes[wandSpriteAttack]);
	write_byte(0);
	write_byte(5);
	write_byte(get_pcvar_num(cvars_data[cvar_wand_attack_sprite_life]));
	write_byte(30);
	write_byte(40);
	write_byte(wandAttackSpriteColor[0]);
	write_byte(wandAttackSpriteColor[1]);
	write_byte(wandAttackSpriteColor[2]);
	write_byte(get_pcvar_num(cvars_data[cvar_wand_attack_sprite_brightness]));
	write_byte(0);
	message_end();

	// Animate explosion on hit.
	message_begin(0, 23);
	write_byte(3);
	write_coord(end_origin[0]);
	write_coord(end_origin[1]);
	write_coord(end_origin[2]);
	write_short(wand_sprites_indexes[wandSpriteExplodeOnHit]);
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
	user_data[index][dataWandLastAttack] = floatround(get_gametime());

	// Create temp. entity.
	new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

	static Float:victimOrigin[3];

	// Get end point vector.
	IVecFVec(end_origin, victimOrigin);

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

	new hit_damage,
		blood_scale,
		attacker_health = pev(victim, pev_health);

	// Calculate damage and blood scale.
	hit_damage = wandDamageEffects[bodyPart][0];
	blood_scale = wandDamageEffects[bodyPart][1];

	// Execute damage.
	ExecuteHamB(Ham_TakeDamage, victim, 0, index, float(hit_damage), (1<<1));

	if (attacker_health > hit_damage)
	{
		static Float:vicOrigin[3];
		pev(victim, pev_origin, vicOrigin);

		message_begin(0, 23);
		write_byte(115);
		write_coord(floatround(vicOrigin[0] + random_num(-20, 20)));
		write_coord(floatround(vicOrigin[1] + random_num(-20, 20)));
		write_coord(floatround(vicOrigin[2] + random_num(-20, 20)));
		//write_short(wand_sprites_indexes[wandSpriteBlood]);
		//write_short(wand_sprites_indexes[wandSpriteBlood]);
		write_byte(248);
		write_byte(blood_scale);
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
		write_short(wand_sprites_indexes[wandSpritePostHit]);
		write_byte(15);
		write_byte(random_num(27, 30));
		write_byte(2);
		write_byte(random_num(30, 70));
		write_byte(40);
		message_end();
	}
	else if (attacker_health <= hit_damage)
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
		write_short(wand_sprites_indexes[wandSpritePostHit]);
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

stock register_commands(const array[][], arraySize, function[], include_say = true)
{
	#if !defined ForRange

		#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

	#endif

	#if AMXX_VERSION_NUM > 183
	
	ForRange(i, 0, arraySize - 1)
	{
		ForRange(j, 0, 1)
		{
			if (include_say)
			{
				register_clcmd(fmt("%s %s", !j ? "say" : "say_team", array[i]), function);
			}
			else
			{
				register_clcmd(array[i], function);
			}
		}
	}

	#else

	new new_command[33];

	ForRange(i, 0, arraySize - 1)
	{
		ForRange(j, 0, 1)
		{
			if (include_say)
			{
				formatex(new_command, charsmax(new_command), "%s %s", !j ? "say" : "say_team", array[i]);
				register_clcmd(new_command, function);
			}
			else
			{
				register_clcmd(array[i], function);
			}
		}
	}

	#endif
}

public block_command_usage(index)
{
	return PLUGIN_HANDLED;
}

public set_black_screen_on()
{
	set_black_screen_fade(1);
}

set_black_screen_fade(fade)
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

stock remove_player_weapons(index)
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
	if (game_mode == modeNormal)
	{
		user_data[index][dataLevel] = sizeof(weaponsData) - 3;
		
		increment_user_level(index, 1, true);
	}
	else
	{
		new team = get_user_team(index);

		tp_data[tpTeamLevel][team - 1] = sizeof(weaponsData) - 3;

		increment_team_level(team, 1, true);
	}
}

public addLevel(index)
{
	if (game_mode == modeNormal)
	{
		increment_user_level(index, 1, true);
	}
	else
	{
		increment_team_level(get_user_team(index), 1, true);
	}
}

public setAWPLevel(index)
{
	if (game_mode == modeNormal)
	{
		user_data[index][dataLevel] = 19;
		increment_user_level(index, 1, true);
	}
	else
	{
		new team = get_user_team(index);
		tp_data[tpTeamLevel][team - 1] = 19;
		increment_team_level(team, 1, true);
	}
}

public godmodOff(index)
{
	set_user_godmode(index, 0);
}

public addKills(index)
{
	increment_user_weapon_kills(index, 1);
}

public addFrag(index)
{
	set_user_frags(index, get_user_frags(index) + 2);
}

public testWinMessage(index)
{
	end_gungame(index);
}

public warmupFunction(index)
{
	toggle_warmup(!warmup_data[warmupEnabled]);

	client_print(0, print_chat, "Warmup = %s", warmup_data[warmupEnabled] ? "ON" : "OFF");
}

public addKnifeKill(index)
{
	user_data[index][dataKnifeKills]++;
	client_print(0, print_chat, "%i", user_data[index][dataKnifeKills]);
}

public addHeadshot(index)
{
	user_data[index][dataHeadshots]++;
	client_print(0, print_chat, "%i", user_data[index][dataHeadshots]);
}

public addKill(index)
{
	user_data[index][dataKills]++;
	client_print(0, print_chat, "%i", user_data[index][dataKills]);
}

public addWin(index)
{
	user_data[index][dataWins]++;
	client_print(0, print_chat, "%i", user_data[index][dataWins]);
}

public addWeapon(index)
{
	user_data[index][dataLevel] = 19;
	increment_user_level(index, 1, true);
}

#endif

/*
		[ Game mode ]
*/

public show_game_vote_menu(index)
{
	if (!game_vote_enabled || !is_user_connected(index))
	{
		return PLUGIN_HANDLED;
	}

	new menu_index = menu_create("Wybierz tryb gry:", "show_game_vote_menu_handler");

	// Add game mode names to the menu.
	ForArray(i, gameModes)
	{
		menu_additem(menu_index, gameModes[i]);
	}

	// Disable exit option.
	menu_setprop(menu_index, MPROP_EXIT, MEXIT_NEVER);

	menu_display(index, menu_index);
	
	return PLUGIN_HANDLED;
}

public show_game_vote_menu_handler(index, menu_index, item)
{
	menu_destroy(menu_index);
	
	// Block player's vote if voting is not enabled.
	if (item == MENU_EXIT || !game_vote_enabled)
	{
		return PLUGIN_HANDLED;
	}

	// Add vote.
	game_votes[item]++;

	ColorChat(index, RED, "%s^x01 Wybrales tryb:^x04 %s^x01.", chatPrefix, gameModes[item]);

	return PLUGIN_HANDLED;
}

set_game_vote()
{
	// Set votes to zero.
	ForArray(i, gameModes)
	{
		game_votes[i] = 0;
	}

	game_vote_enabled = true;

	// Show game mode vote menu to all players.
	ForPlayers(i)
	{
		if (!is_user_connected(i))
		{
			continue;
		}

		show_game_vote_menu(i);
	}
}

public finish_game_vote()
{
	game_vote_enabled = false;
	game_mode = 0;

	new bool:tie,
		sum_of_votes = game_votes[0] + game_votes[1];

	// Handle game mode votes.
	if (game_votes[0] == game_votes[1])
	{
		tie = true;
	}
	else
	{
		if (game_votes[0] > game_votes[1])
		{
			game_mode = 0;
		}
		else
		{
			game_mode = 1;
		}
	}

	// If there is no definitive winner, get one randomly.
	if (tie || !sum_of_votes)
	{
		game_mode = random_num(0, sizeof(gameModes) - 1);

		tp_data[tpEnabled] = bool:(game_mode == modeTeamplay);
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
			
			formatex(message, charsmax(message), "%s^x01 %sygral tryb:^x04 %s.", chatPrefix, tie ? "Droga losowania w" : "W", gameModes[game_mode]);

			if (sum_of_votes)
			{
				format(message, charsmax(message), "%s ^x01Zdobyl^x04 %i procent^x01 glosow.", message, floatround(float(game_votes[game_mode]) / float(sum_of_votes) * 100.0));
			}

			ColorChat(i, RED, message);
		}
	}

	ExecuteForward(forward_handles[forward_game_mode_chosen], forward_return_dummy, game_mode);
}