#include <amxmodx>
#include <amxmisc>

#define PLUGIN "GunGame JoinGuard"
#define VERSION "1.0"
#define AUTHOR "aSior & Ogen Dogen"

new playerTeam[33];
new teamPlayers[2];

// todo:
// team event handling

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_message(get_user_msgid("ShowMenu"), "messageShowMenu");
    register_message(get_user_msgid("VGUIMenu"), "messageVGUIMenu");

    register_clcmd("say /spect", "spectForAdmins");
    register_clcmd("say_team /spect", "spectForAdmins");
    
    teamPlayers[0] = 0;
    teamPlayers[1] = 0;
}

enum (+= 1)
{
	teamTT = 0,
	teamCT,
    teamSpect
};

public spectForAdmins(id)
{
    if (access(id, ADMIN_BAN))
    {
        new adminTeam = get_user_team(id);
        if (adminTeam == teamTT || adminTeam == teamCT)
        {
            forceTeamJoin(id, teamSpect);
        }
        else if (adminTeam == teamSpect)
        {
            chooseTeamForPlayer(id);
        }
    }

    return PLUGIN_HANDLED;
}

public client_connect(id)
{
    playerTeam[id] = -1;
}

public client_disconnected(id)
{
    teamPlayers[get_user_team(id)]--;
}

public messageShowMenu(msgid, dest, id)
{
    if (isAutoJoin(id))
    {
        chooseTeamForPlayer(id);
        return PLUGIN_HANDLED;
    }
    
    return PLUGIN_CONTINUE;
}

public messageVGUIMenu(msgid, dest, id)
{
    if (isAutoJoin(id))
    {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public chooseTeamForPlayer(id)
{
    if (teamPlayers[teamTT] > teamPlayers[teamCT])
    {
        forceTeamJoin(id, teamCT);
    }
    else if (teamPlayers[teamTT] < teamPlayers[teamCT])
    {
        forceTeamJoin(id, teamTT);
    }
    else if (teamPlayers[teamTT] == teamPlayers[teamCT])
    {
        forceTeamJoin(id, random_num(0, 1));
    }
}

public forceTeamJoin(id, team)
{
    client_cmd(id, "jointeam %d", team);
    // todo: changing team handling
    teamPlayers[team]++;
}

stock bool:isAutoJoin(id)
{
    return !access(id, ADMIN_IMMUNITY);
}