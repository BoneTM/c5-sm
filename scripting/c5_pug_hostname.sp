#include <cstrike>
#include <sourcemod>

#include "include/c5_pug.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

#define MAX_HOST_LENGTH 256

ConVar g_HostnameCvar;

bool g_GotHostName = false;
char g_HostName[MAX_HOST_LENGTH];  // stores the original hostname

public Plugin myinfo =
{
    name = "C5: pug - hostname",
    author = "Bone",
    description = "",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
  g_HostnameCvar = FindConVar("hostname");
  
  if (g_HostnameCvar == INVALID_HANDLE)
    SetFailState("Failed to find cvar \"hostname\"");

  HookEvent("round_start", Event_RoundStart);
}

public void OnConfigsExecuted()
{
  if (!g_GotHostName)
  {
    g_HostnameCvar.GetString(g_HostName, sizeof(g_HostName));
    g_GotHostName = true;
  }
}

public void C5_PUG_OnReadyToStartCheck(int readyPlayers, int totalPlayers)
{
  
  char hostname[MAX_HOST_LENGTH];
  int need = C5_PUG_GetPugMaxPlayers() - totalPlayers;

  if (need >= 1)
  {
    Format(hostname, sizeof(hostname), "%s [NEED %d]", g_HostName, need);
  }
  else
  {
    Format(hostname, sizeof(hostname), "%s", g_HostName);
  }

  g_HostnameCvar.SetString(hostname);
}

public void C5_PUG_OnGoingLive()
{
  char hostname[MAX_HOST_LENGTH];
  Format(hostname, sizeof(hostname), "%s [LIVE]", g_HostName);
  g_HostnameCvar.SetString(hostname);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
  if (!C5_PUG_IsMatchLive()) return Plugin_Continue;

  char hostname[MAX_HOST_LENGTH];
  Format(hostname, sizeof(hostname), "%s [LIVE %d-%d]", g_HostName, CS_GetTeamScore(CS_TEAM_CT),
         CS_GetTeamScore(CS_TEAM_T));
  g_HostnameCvar.SetString(hostname);

  return Plugin_Continue;
}

public void C5_PUG_OnMatchOver()
{
  g_HostnameCvar.SetString(g_HostName);
}
