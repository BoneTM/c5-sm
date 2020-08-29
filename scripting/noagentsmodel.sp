#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "No Agents Model",
    author = "Bone",
    description = "",
    version = "1.0",
    url = "https://bonetm.github.io/"
};

char g_Agents[][] =
{
  "tm_balkan_variantf",
  "tm_balkan_variantg",
  "tm_balkan_varianth",
  "tm_balkan_varianti",
  "tm_balkan_variantj",
  "tm_leet_variantf",
  "tm_leet_variantg",
  "tm_leet_varianth",
  "tm_leet_varianti",
  "tm_phoenix_variantf",
  "tm_phoenix_variantg",
  "tm_phoenix_varianth",
  "ctm_fbi_variantb",
  "ctm_fbi_variantf",
  "ctm_fbi_variantg",
  "ctm_fbi_varianth",
  "ctm_sas_variantf",
  "ctm_st6_variante",
  "ctm_st6_variantg",
  "ctm_st6_varianti",
  "ctm_st6_variantk",
  "ctm_st6_variantm"
};

ArrayList g_PlayerModel[4];

ConVar g_CreaterMode;

public void OnPluginStart()
{
  HookEvent("player_spawn", Event_PlayerSpawn);
  
  g_CreaterMode = CreateConVar("nam_creater_mode", "0");

  g_PlayerModel[CS_TEAM_T] = new ArrayList(256);
  g_PlayerModel[CS_TEAM_CT] = new ArrayList(256);

  RegAdminCmd("noagentsmodel", CMD_Nam, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
  g_PlayerModel[CS_TEAM_T].Clear();
  g_PlayerModel[CS_TEAM_CT].Clear();

  char map[32];
  GetCleanMapName(map, sizeof(map));

  char path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), "configs/noagentsmodel/%s.ini", map);

  if (!FileExists(path)) {
    LogError("Missing nam file: %s", path);
    BuildPath(Path_SM, path, sizeof(path), "configs/noagentsmodel/default.ini", map);
  }
  
  if (!FileExists(path)) {
    SetFailState("default.ini missing");
  }

  File file = OpenFile(path, "r");
  if (file != null) {
    char line[PLATFORM_MAX_PATH];
    char buffers[2][256];
    char model[256];
    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line))) {
      TrimString(line);
      ExplodeString(line, "|", buffers, 2, sizeof(buffers[]));
      int team = StringToInt(buffers[0]);
      if (team == CS_TEAM_T || team == CS_TEAM_CT)
      {
        Format(model, sizeof(model), "models/player/custom_player/legacy/%s", buffers[1]);
        g_PlayerModel[team].PushString(model);
        PrecacheModel(model);
      }
    }
    delete file;
  } else {
    LogError("Failed to open NAM file: %s", path);
  }
}

public Action CMD_Nam(int client, int args)
{
  if (!g_CreaterMode.BoolValue) return;
  
  char map[32];
  GetCleanMapName(map, sizeof(map));

  char path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), "configs/noagentsmodel/%s.ini", map);
  DeleteFile(path);
  File file = OpenFile(path, "w");
  if (file != null) {
    char model[256];
    for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++)
    {
      for (int i = 0; i < g_PlayerModel[team].Length; i++)
      {
        g_PlayerModel[team].GetString(i, model, sizeof(model));
        file.WriteLine("%d|%s", team, model);
      }
    }
    delete file;
  } else {
    LogError("Failed to write NAM file: %s", path);
  }
}

void SetModel(int client)
{
  static char model[256];
  static int counter = 0;

  int team = GetClientTeam(client);
  if (team == CS_TEAM_T || team == CS_TEAM_CT)
  {
    g_PlayerModel[team].GetString(counter % g_PlayerModel[team].Length, model, sizeof(model));
    SetEntityModel(client, model);
  }

  if (counter++ > 99)
  {
    counter = 0;
  }
}

public Action Event_PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  
  if (!IsValidClient(client)) return Plugin_Continue;

  if (IsClientUsingAgent(client))
  {
    SetModel(client);
  }

  return Plugin_Continue;
}

public bool IsClientUsingAgent(int client)
{
  char model[256];
  GetClientModel(client, model, sizeof(model));
  
  for (int i = 0; i < sizeof(g_Agents); i++)
  {
    if (StrContains(model, g_Agents[i]) != -1) 
    {
      return true;
    }
  }
  
  if (g_CreaterMode.BoolValue)
  {
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T || team == CS_TEAM_CT)
    {
      char buffer[128];
      strcopy(buffer, sizeof(buffer), model[35]);
      if (g_PlayerModel[team].FindString(buffer) == -1)
      {
        g_PlayerModel[team].PushString(buffer);
      }
    }
  }
  
  return false;
}