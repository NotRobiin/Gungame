#if defined _gungame_included
	#endinput
#endif
#define _gungame_included

enum (+= 1)
{
	weaponCSW = 0,
	weaponKills,
	weaponDamage
};

/*
	Sets player's level.

	@param index		Valid (1-32) player index.
	@param level 		New level.

	@return 		1 if level was changed, nativesErrorValue otherwise.
*/
native SetUserLevel(index, level);

/*
	Gets player's level.

	@param index		Valid (1-32) player index.

	@return 		Player level or nativeErrorValue if player is not connected.
*/
native GetUserLevel(index);

/*
	Gets size of weapons array - 1, which is max level. 

	@return			Max possible gungame level.
*/
native GetMaxLevel();

/*
	Respawns player after certain time.

	@param index		Valid (1-32) player index.
	@param time			Time (float) to respawn. 0.01 is minimum.

	@return 		1 if player will be respawned, nativesErrorValue otherwise.
*/
native RespawnPlayer(index, Float:time = 1.0);

/*
	Gets player's current level weapon.

	@param index		Valid (1-32) player index.

	@return 		CSW index of player's weapon, nativesErrorValue otherwise.
*/
native GetUserWeapon(index);

/*
	Gets data from main-gungame array. You should use enum from line 6-11.

	@param arrayIndex	Level on which data you want to have.
	@param dataType		Data such as:

						0 - CSW_* index.
						1 - Kills required to levelup.
						2 - Damage multiplier for that weapon.

	@return 		Level data.
*/
native GetWeaponsData(arrayIndex, dataType);

/*
	Gets player's wins.

	@param index		Valid (1-32) player index.

	@return 		User wins, nativesErrorValue if an error occured.
*/
native GetUserWins(index);

/*
	Gets player's combo.

	@param index		Valid (1-32) player index.

	@return 		User killstreak, nativesErrorValue if an error occured.
*/
native GetUserCombo(index);

/*
	Gets current game leader.

	@return			Valid (1-32) player index. 0 if leader was not found.
*/
native GetGameLeader();

/*
	Saves data of type integer to .json file.

	@param index		Valid (1-32) player index.
	@param label[]		Child of index's player name.
	@param dotNotation	Whether to use dot notation.

	@return			1 if successfully saved data, 0 otherwise.
*/
native SaveDataInt(index, label[], value, bool:dotNotation = true);

/*
	Gets data of type integer from .json file.

	@param index		Valid (1-32) player index.
	@param label[]		Child of index's player name.
	@param dotNotation	Whether to use dot notation.

	@return 		Player's name & label child value.
*/
native GetDataInt(index, label[], bool:dotNotation = true);

/*
	Saves data of type string to .json file.
	This is not meant to be treated as array function.

	@param index		Valid (1-32) player index.
	@param label[]		Child of index's player name.
	@param string[]		Data to save.
	@param dotNotation	Whether to use dot notation.

	@return 			True if successfully saved data, false otherwise.
*/
native SaveDataString(index, label[], string[], bool:dotNotation = true);

/*
	Gets data of type string from .json file.

	@param index		Valid (1-32) player index.
	@param label[]		Child of index's player name.
	@param string[]		Array to copy string value.
	@param length		Max. length of string.

	@return			The number of cells written to the buffer.
*/
native GetDataString(index, label[], string[], length);


/*
	Called when player ranks up.

	@param index		Valid (1-32) player index.
	@param level 		New player's level.
*/
forward levelUp(index, level);

/*
	Called when player ranks down.

	@param index		Valid (1-32) player index.
	@param level 		New player's level.
*/
forward levelDown(index, level);

/*
	Called when someone wins gungame.

	@param winner		Valid (1-32) player index.
*/
forward gameEnd(winner);

/*
	Called when gungame beings, and warmup ends.

	@param warmupWinner	Valid (1-32) player index. 0 if warmup ended with no winner.
*/
forward gameBeginning(warmupWinner);

/*
	Called when player is spawned and gungame is active (warmup does not count).

	@param index		Valid (1-32) player index.
*/
forward playerSpawned(index);

/*
	Called when someone gets a kill.

	@param index		Valid (1-32) player index.
	@param streak 		Player's current killstreak.
*/
forward comboStreak(index, streak);