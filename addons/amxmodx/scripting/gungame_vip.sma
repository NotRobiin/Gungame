#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fun>
#include <colorchat>

#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/"

#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof %2; %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)
#define ForPlayers(%1) for(new %1 = 1; %1 <= MAX_PLAYERS; %1++)

new const vipFlag[] = "t";
new const vipHealth = 110;
new const vipArmor = 50;
new const vipPrefix[] = "^x04[VIP]^x01";
new const vipJumps = 0;
new const bool:vipGreetings = true;
new const vipGreetingsMessage[] = "Wchodzi vip %n!";
new const vipMotdFile[] = "vip.txt";
new const vipMotdFileHeader[] = "Informacje o VIPie";

// [0] - Weapon, [1] - Damage multiplier
// If damage multiplier = 105 and weapon = CSW_M4A1 then vips will deal 5% more damage with m4a1.
new const vipHigherDamageWeapons[][] = 
{
	{ CSW_KNIFE, 105 }
};

new const vipMotdCommands[][] = 
{
	"/vip",
	"/comavip"
};

new const vipsOnlineCommands[][] =
{
	"/vips",
	"/vipy",
	"/vipyonline"
};

new bool:userVip[33],
	userJumps[33],

	Array:greetedPlayers,

	hudObject;

public plugin_init()
{
	register_plugin("Gungame VIP", "v1.2", AUTHOR);

	RegisterHam(Ham_Spawn, "player", "playerSpawn", true);
	RegisterHam(Ham_TakeDamage, "player", "takeDamage");

	register_message(get_user_msgid("ScoreAttrib"), "updateVipStatus");
	register_message(get_user_msgid("SayText"), "sayHandle");

	register_forward(FM_CmdStart, "commandStartPre");

	registerCommands(vipMotdCommands, sizeof(vipMotdCommands), "showVipMotd");
	registerCommands(vipsOnlineCommands, sizeof(vipsOnlineCommands), "showVipsOnline");

	if(vipGreetings)
	{
		greetedPlayers = ArrayCreate(32, 1);
		hudObject = CreateHudSyncObj();
	}
}

public plugin_natives()
{
	register_native("gg_get_user_vip", "native_get_user_vip", 0);
	register_native("gg_set_user_vip", "native_set_user_vip", 0);
	register_native("gg_get_vip_flag", "native_get_vip_flag", 0);
}

public plugin_end()
{
	ArrayDestroy(greetedPlayers);
}

public native_get_user_vip(plugin, params)
{
	new const requiredParams = 1;

	if(params < requiredParams)
	{
		log_amx("ERROR: native ^"gg_get_user_vip^" has invalid amount of params: %i (required %i). Plugin: %s", params, requiredParams, plugin);
		
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
	new const requiredParams = 2;

	if(params < requiredParams)
	{
		log_amx("ERROR: native ^"gg_set_user_vip^" has invalid amount of params: %i (required %i). Plugin: %s", params, requiredParams, plugin);
		
		return false;
	}

	new index = get_param(1);

	if(!is_user_connected(index))
	{
		return false;
	}

	userVip[index] = bool:(get_param(2));

	return true;
}

public native_get_vip_flag(plugin, params)
{
	new const requiredParams = 0;

	if(params)
	{
		log_amx("ERROR: native ^"gg_get_vip_flag^" has invalid amount of params: %i (required: %i). Plugin: %s", params, requiredParams, plugin);

		return -1;
	}

	return read_flags(vipFlag);
}

public showVipMotd(index)
{
	show_motd(index, vipMotdFile, vipMotdFileHeader);
}

public showVipsOnline(index)
{
	new const chatPrefix[] = "[GUNGAME]^x01";

	new message[191],
		onlineCount;
	
	ForPlayers(i)
	{
		if (!is_user_connected(i) || !userVip[i])
		{
			continue;
		}

		onlineCount++;

		if (strlen(message) + strlen(fmt("%n, ", i)) > 191)
		{
			break;
		}

		add(message, charsmax(message), fmt("^x04%n^x01, ", i));
	}

	if (!onlineCount)
	{
		ColorChat(index, RED, "%s Brak vipow online^x01.", chatPrefix);
	}
	else
	{
		format(message, strlen(message) - 3, message);
		format(message, charsmax(message), "Online (%i): %s^x01.", onlineCount, message);
		
		ColorChat(index, RED, "%s %s", chatPrefix, message);
	}
}

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

		newVelocity[2] = random_float(265.0, 285.0);

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

	if(0 >= get_user_team(index) > 2)
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