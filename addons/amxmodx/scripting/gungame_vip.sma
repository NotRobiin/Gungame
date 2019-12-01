#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fun>

#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/"

#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof %2; %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

new const vipFlag[] = "t";

// Added, not set.
new const vipHealth = 110;

// Set.
new const vipArmor = 50;

// Chat prefix.
new const vipPrefix[] = "^x04[VIP]^x01";

// Default + vipJumps.
new const vipJumps = 0;

// Display greetings on join?
new const bool:vipGreetings = true;

// Message to display.
new const vipGreetingsMessage[] = "Wchodzi vip %n!";

// How high vip jumps.
new const Float:vipJumpVelocityRange[] = { 265.0, 285.0 };

/*
	[0] - Weapon
	[1] - Damage multiplier

	If damage multiplier = 105 and weapon = CSW_M4A1 then vips will deal 5% more damage with m4a1.
*/
new const vipHigherDamageWeapons[][] = 
{
	{ CSW_KNIFE, 105 }
};

new const vipMotdCommands[][] = 
{
	"/vip",
	"/comavip"
};

new const vipMotdFile[] = "vip.txt";

new const vipMotdFileHeader[] = "Informacje o VIPie";


#define vipSkinsEnabled false

#if vipSkinsEnabled
new const vipSkins[][][] =
{
	{ CSW_KNIFE, "models/super_vip/v_crowbar.mdl", "models/super_vip/p_newcrowbar.mdl", (TEAM_T) }
};
#endif


#define vipModelsEnabled false

#if vipModelsEnabled
new const vipModel[][][] =
{
	{ "models/player/terrorystyk/", "terrorystyk", TEAM_T },
	{ "models/player/dres/", "dres", TEAM_CT }
};
#endif

new const nativesData[][][] =
{
	{ "get_user_vip", "native_get_user_vip", 0 },
	{ "set_user_vip", "native_set_user_vip", 0 }
};

new bool:userVip[33],
	userJumps[33],

	Array:greetedPlayers,

	hudObject;

public plugin_init()
{
	register_plugin("x", "v0.1", AUTHOR);

	RegisterHam(Ham_Spawn, "player", "playerSpawn", true);
	RegisterHam(Ham_TakeDamage, "player", "takeDamage");

	register_message(get_user_msgid("ScoreAttrib"), "updateVipStatus");
	register_message(get_user_msgid("SayText"), "sayHandle");

	register_forward(FM_CmdStart, "commandStartPre");

	registerCommands(vipMotdCommands, sizeof(vipMotdCommands), "vipMotd");

	#if vipSkinsEnabled
	registerForwards();
	#endif

	if(vipGreetings)
	{
		greetedPlayers = ArrayCreate(32, 1);

		hudObject = CreateHudSyncObj();
	}
}

public plugin_natives()
{
	ForArray(i, nativesData)
	{
		register_native(nativesData[i][0], nativesData[i][1], nativesData[i][2][0]);
	}
}

public plugin_precache()
{
	#if vipSkinsEnabled
	ForArray(i, vipSkins)
	{
		if(!file_exists(vipSkins[i][1]) || !file_exists(vipSkins[i][2]))
		{
			log_amx("ERROR: Tried to precache non-existing file: ^"%s^" or ^"%s^".", vipSkins[i][1], vipSkins[i][2]);

			continue;
		}

		precache_model(vipSkins[i][1]);
		precache_model(vipSkins[i][2]);
	}
	#endif

	#if vipModelsEnabled
	new modelPath[2 << 5];

	ForRange(i, 0, 1)
	{
		formatex(modelPath, charsmax(modelPath), "%s%s.mdl", vipModel[i][0], vipModel[i][1]);

		if(!file_exists(modelPath))
		{
			log_amx("ERROR: Tried to precache vip player model on path ^"%s^". File was not found.", modelPath);

			continue;
		}

		precache_model(modelPath);
	}
	#endif
}

public plugin_end()
{
	ArrayDestroy(greetedPlayers);
}

public native_get_user_vip(plugin, params)
{
	if(params < 1)
	{
		return false;
	}

	new index = get_param(1);

	if(!is_user_connected(index))
	{
		return false;
	}

	return userVip[index];
}

public native_set_user_vip(plugin, params)
{
	if(params < 2)
	{
		log_amx("ERROR: native ^"set_user_vip^" has invalid amount of params: %i (required %i). Plugin: %s", params, 2, plugin);
		
		return;
	}

	new index = get_param(1);

	if(!is_user_connected(index))
	{
		return;
	}

	userVip[index] = bool:(get_param(2));
}

public vipMotd(index)
{
	show_motd(index, vipMotdFile, vipMotdFileHeader);
}

#if vipSkinsEnabled
public weaponDeploy(entity)
{
	new index = pev(entity, pev_owner),
		weapon = cs_get_weapon_id(entity);

	setViewmodel(index, weapon);
}
#endif

public commandStartPre(index, uc_handle)
{
	if(!userVip[index])
	{
		return;
	}

	new flags = pev(index, pev_flags);

	if((get_uc(uc_handle, UC_Buttons) & IN_JUMP) && !(flags & FL_ONGROUND) && !(pev(index, pev_oldbuttons) & IN_JUMP) && userJumps[index])
	{
		--userJumps[index];

		new Float:newVelocity[3];

		pev(index, pev_velocity, newVelocity);

		newVelocity[2] = random_float(vipJumpVelocityRange[0], vipJumpVelocityRange[1]);

		set_pev(index, pev_velocity, newVelocity);
	}
	else if(flags & FL_ONGROUND && userJumps[index] != -1)
	{
		userJumps[index] = vipJumps;
	}
}

public takeDamage(victim, idinflictor, attacker, Float:damage, damagebits)
{
	if(!is_user_alive(attacker) || !is_user_alive(attacker))
	{
		return HAM_IGNORED;
	}

	ForArray(i, vipHigherDamageWeapons)
	{
		if(get_user_weapon(attacker) != vipHigherDamageWeapons[i][0])
		{
			continue;
		}

		damage *= float(vipHigherDamageWeapons[i][1]) / 100.0;

		SetHamParamFloat(4, damage);

		return HAM_IGNORED;
	}

	return HAM_IGNORED;
}

public updateVipStatus()
{
	new index = get_msg_arg_int(1);

	if(!is_user_alive(index) || !userVip[index])
	{
		return;
	}

	set_msg_arg_int(2, ARG_BYTE, get_msg_arg_int(2) | 4);
}

public sayHandle(msgId, msgDest, msgEnt)
{
	new index = get_msg_arg_int(1);

	if(!is_user_connected(index) || !userVip[index])
	{
		return PLUGIN_CONTINUE;
	}

	new userName[32],
		chatString[2][192];

	get_user_name(index, userName, charsmax(userName));

	get_msg_arg_string(2, chatString[0], charsmax(chatString[]));

	if(equal(chatString[0], "#Cstrike_Chat_All"))
	{
		get_msg_arg_string(4, chatString[0], charsmax(chatString[]));
		
		set_msg_arg_string(4, "");

		formatex(chatString[1], charsmax(chatString[]), "%s^x03 %s^x01 :  %s", vipPrefix, userName, chatString[0]);
	}
	else
	{
		formatex(chatString[1], charsmax(chatString[]), "%s^x01 %s", vipPrefix, chatString[0]);
	}

	set_msg_arg_string(2, chatString[1]);

	return PLUGIN_CONTINUE;
}

public playerSpawn(index)
{
	if(!is_user_alive(index))
	{
		return;
	}

	authorizePlayer(index, false);

	if(!userVip[index])
	{
		return;
	}

	new userTeam = get_user_team(index);

	if(0 >= userTeam > 2)
	{
		return;
	}

	set_user_health(index, vipHealth);
	set_user_armor(index, vipArmor);
}

public client_putinserver(index)
{
	authorizePlayer(index);
}

public client_disconnect(index)
{
	userVip[index] = false;
}

authorizePlayer(index, bool:connect = true)
{
	userVip[index] = bool:(get_user_flags(index) & read_flags(vipFlag));

	if(!userVip[index] || !connect || !vipGreetings)
	{
		return;
	}

	displayGreetings(index);
}

displayGreetings(index)
{
	if(inArray(fmt("%n", index), greetedPlayers))
	{
		return;
	}

	ArrayPushString(greetedPlayers, fmt("%n", index));

	set_hudmessage(24, 190, 220, 0.25, 0.2, 0, 6.0, 6.0);
	ShowSyncHudMsg(0, hudObject, vipGreetingsMessage, index);
}

#if vipSkinsEnabled
setViewmodel(index, weapon)
{
	if(!is_user_alive(index) || !userVip[index])
	{
		return;
	}

	new arrayIndex = -1;

	if(cs_get_user_shield(index))
	{
		return;
	}

	// Get array index of weapon.
	ForArray(i, vipSkins)
	{
		if(weapon != vipSkins[i][0][0] || !(get_user_team(index) & vipSkins[i][3][0]))
		{
			continue;
		}

		arrayIndex = i;

		break;
	}

	if(arrayIndex == -1)
	{
		return;
	}

	// V_
	set_pev(index, pev_viewmodel2, vipSkins[arrayIndex][1]);
	
	// P_
	set_pev(index, pev_weaponmodel2, vipSkins[arrayIndex][2]);
}

registerForwards()
{
	new entityName[33],
		Array:registeredClassnames;

	registeredClassnames = ArrayCreate(33, 1);

	ForArray(i, vipSkins)
	{
		get_weaponname(vipSkins[i][0][0], entityName, charsmax(entityName));
		
		if(inArray(entityName, registeredClassnames) || !entityName[0])
		{
			continue;
		}
		
		RegisterHam(Ham_Item_Deploy, entityName, "weaponDeploy", true);

		ArrayPushString(registeredClassnames, entityName);
	}

	ArrayDestroy(registeredClassnames);
}
#endif

stock registerCommands(const array[][], arraySize, function[])
{
	#if !defined ForRange

		#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)

	#endif

	#if AMXX_VERSION_NUM > 183
	
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

bool:inArray(searched[], Array:array)
{
	#define ForDynamicArray(%1,%2) for(new %1 = 0; %1 < ArraySize(%2); %1++)
	
	new arrayContent[33];

	ForDynamicArray(i, array)
	{
		ArrayGetString(array, i, arrayContent, charsmax(arrayContent));

		if(!equal(searched, arrayContent))
		{
			continue;
		}

		return true;
	}

	return false;
}