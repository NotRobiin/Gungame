#include <amxmodx>
#include <amxmisc>

#define PLUGIN "GunGame JoinGuard"
#define VERSION "1.0"
#define AUTHOR "aSior & Ogen Dogen"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
    register_message(get_user_msgid("ShowMenu"), "messageShowMenu");
	register_message(get_user_msgid("VGUIMenu"), "messageVGUIMenu");
}

public forceTeamJoin(id, team)
{
    client_cmd(id, "jointeam %d", team);
}

stock bool:isAutoJoin(id)
{
    return !access(id, ADMIN_IMMUNITY);
}