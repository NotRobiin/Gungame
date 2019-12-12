#include <amxmodx>
#include <amxmisc>

#define PLUGIN "GunGame JoinGuard"
#define VERSION "1.0"
#define AUTHOR "aSior & Ogen Dogen"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
}

public forceTeamJoin(id, team)
{
    engclient_cmd(id, "jointeam", team);
}

bool:isAutoJoin()
{
    return !access(id, ADMIN_IMMUNITY);
}