#if defined _gungame_vip_included
	#endinput
#endif
#define _gungame_vip_included

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
    Gets vip flag.

    @return         Flag bitsum required for VIP status.
*/
native gg_get_vip_flag();