#if defined _gungame_included
	#endinput
#endif
#define _gungame_included

enum (+= 1)
{
	weaponCSW,
	weaponKills,
	weaponTeamKills
};

/*
	Sets player's level.

	@param index		Valid (1-32) player index.
	@param level 		New level.

	@return 		1 if level was changed, nativesErrorValue otherwise.
*/
native gg_set_user_level(index, level);

/*
	Gets player's level.

	@param index		Valid (1-32) player index.

	@return 		Player level or nativeErrorValue if player is not connected.
*/
native gg_get_user_level(index);

/*
	Sets team level.

	@param team		1 - TT, 2 - CT
	@param level		0 - (max level - 1)
	@param includeMembers		Adjust level of players in team?

	@return		True on success, false otherwise.

*/
native gg_set_team_level(team, level, bool:includeMembers = true);

/*
	Returns team level.

	@param team		1 - TT, 2 - CT
	
	@return		Team level or -1 if invalid team was given.

*/
native gg_get_team_level(team);

/*
	Gets size of weapons array - 1, which is max level. 

	@return			Max possible gungame level.
*/
native gg_get_max_level();

/*
	Respawns player after certain time.

	@param index		Valid (1-32) player index.
	@param time			Time (float) to respawn. 0.01 is minimum.

	@return 		1 if player will be respawned, nativesErrorValue otherwise.
*/
native gg_respawn_player(index, Float:time = 1.0);

/*
	Gets player's current level weapon.

	@param index		Valid (1-32) player index.

	@return 		CSW index of player's weapon, nativesErrorValue otherwise.
*/
native gg_get_user_weapon(index);

/*
	Gets data from main-gungame array. You should use enum from line 6-11.

	@param arrayIndex	Level on which data you want to have.
	@param dataType		Data such as:

						0 - CSW_* index.
						1 - Kills required to levelup.
						2 - Damage multiplier for that weapon.

	@return 		Level data.
*/
native gg_get_weapons_data(arrayIndex, dataType);

/*
	Gets player's wins.

	@param index		Valid (1-32) player index.

	@return 		User wins, nativesErrorValue if an error occured.
*/
native gg_get_user_wins(index);

/*
	Gets player's combo.

	@param index		Valid (1-32) player index.

	@return 		User killstreak, nativesErrorValue if an error occured.
*/
native gg_get_user_combo(index);

/*
	Gets current game leader.

	@return			Valid (1-32) player index. 0 if leader was not found.
*/
native gg_get_game_leader();

/*
	Checks if user is a vip.

	@return			True if player is a vip, false otherwise.
*/
native bool:gg_get_user_vip(index);

/*
	Sets vip.

	@return			True if vip was set, false otherwise.
*/
native gg_set_user_vip(index, bool:status);

/*
	Returns bitsum of flags required to have vip.

	@return			Bit sum or -1 if given invalid amount of params.
*/
native gg_get_vip_flags();

/*
	Called when player ranks up.

	@param index		Valid (1-32) player index.
	@param level 		New player's level.
	@param team 		-1 if leveled up on normal mode, 1/2 on teamplay
*/
forward gg_level_up(index, level, team);

/*
	Called when player ranks down.

	@param index		Valid (1-32) player index.
	@param level 		New player's level.
	@param team 		-1 if leveled down on normal mode, 1/2 on teamplay
*/
forward gg_level_down(index, level, team);

/*
	Called when someone wins gungame.

	@param winner		Valid (1-32) player index.
*/
forward gg_game_end(winner);

/*
	Called when gungame beings, and warmup ends.

	@param warmupWinner	Valid (1-32) player index. 0 if warmup ended with no winner. -1 if there's no winner because of game mode.
*/
forward gg_game_beginning(warmupWinner);

/*
	Called when player is spawned and gungame is active (warmup does not count).

	@param index		Valid (1-32) player index.
*/
forward gg_player_spawned(index);

/*
	Called when someone gets a kill.

	@param index		Valid (1-32) player index.
	@param streak 		Player's current killstreak.
*/
forward gg_combo_streak(index, streak);