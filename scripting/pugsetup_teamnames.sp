#include <clientprefs>
#include <cstrike>
#include <geoip>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

#define TEAM_NAME_LENGTH 128
#define TEAM_FLAG_LENGTH 4
#define TEAM_LOGO_LENGTH 10

Cookie g_teamNameCookie;
Cookie g_teamFlagCookie;
Cookie g_teamLogoCookie;

enum struct PlayerData
{
  int client;
  char name[TEAM_NAME_LENGTH];
  char flag[TEAM_FLAG_LENGTH];
  char logo[TEAM_LOGO_LENGTH];
 
  void Init(int client)
  {
    this.client = client;
  }

  void Load()
  {
    GetClientCookie(this.client, g_teamNameCookie, this.name, TEAM_NAME_LENGTH);
    GetClientCookie(this.client, g_teamFlagCookie, this.flag, TEAM_FLAG_LENGTH);
    GetClientCookie(this.client, g_teamLogoCookie, this.logo, TEAM_LOGO_LENGTH);
  }
  
  void Save()
  {
    PrintToServer("%d", this.client);
    SetClientCookie(this.client, g_teamNameCookie, this.name);
    SetClientCookie(this.client, g_teamFlagCookie, this.flag);
    SetClientCookie(this.client, g_teamLogoCookie, this.logo);
  }

  void Clear()
  {
    this.name[0] = EOS;
    this.flag[0] = EOS;
    this.logo[0] = EOS;
  }
}

PlayerData g_PlayerData[MAXPLAYERS + 1];

Menu menuMatchTeam;
Menu menuFlag;

public Plugin myinfo = 
{
    name = "C5: PUG - teamnames",
    author = "Bone",
    description = "",
    version = "1.0",
    url = ""
};

public void OnPluginStart() {
  RegConsoleCmd("sm_team", Command_Team);
  g_teamNameCookie = new Cookie("pug_teamnames_teamname", "C5 Pug team name", CookieAccess_Protected);
  g_teamFlagCookie = new Cookie("pug_teamnames_teamflag", "C5 Pug team flag (2-letter country code)", CookieAccess_Protected);
  g_teamLogoCookie = new Cookie("pug_teamnames_teamlogo", "C5 Pug team logo", CookieAccess_Protected);

  for (int i = 1; i <= MaxClients; i++)
  {
    g_PlayerData[i].Init(i);

    if (!IsValidClient(i) || !AreClientCookiesCached(i)) continue;

    OnClientCookiesCached(i);
  }

  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/teamnames.cfg");
  KeyValues kv = new KeyValues("Teamnames");
  kv.ImportFromFile(configFile);

  menuMatchTeam = new Menu(menuMatchTeamHandler);
  menuMatchTeam.ExitBackButton = true;
  kv.JumpToKey("team");
  
  char teamName[138];
  char name[TEAM_NAME_LENGTH];
  char logo[TEAM_LOGO_LENGTH];
  char info[138];
  if (kv.GotoFirstSubKey())
  {
    do {
      kv.GetSectionName(teamName, sizeof(teamName));
      kv.GetString("name", name, sizeof(name));
      kv.GetString("logo", logo, sizeof(logo));
      Format(info, sizeof(info), "%s;%s", name, logo);
      AddMenuOption(menuMatchTeam, info, teamName);
    } while (kv.GotoNextKey());
    kv.GoBack();
  }
  kv.GoBack();

  menuFlag = new Menu(menuFlagHandler);
  menuFlag.ExitBackButton = true;
  kv.JumpToKey("flag");

  char countryName[64];
  char countryCode[TEAM_FLAG_LENGTH];
  if (kv.GotoFirstSubKey(false))
  {
    do {
      kv.GetSectionName(countryName, sizeof(countryName));
      kv.GetString(NULL_STRING, countryCode, sizeof(countryCode));
      
      AddMenuOption(menuFlag, countryCode, countryName);
    } while (kv.GotoNextKey(false));
    kv.GoBack();
  }
}

public void OnClientCookiesCached(int client)
{
  if (IsFakeClient(client)) return;

  g_PlayerData[client].Load();
}

public void OnClientDisconnect(int client)
{
  if (!IsPlayer(client)) return;

  g_PlayerData[client].Save();
  g_PlayerData[client].Clear();
}

public int menuMatchTeamHandler(Menu menu, MenuAction action, int client, int selection)
{
  switch(action)
  {
    case MenuAction_Select:
    {
      if(IsClientInGame(client))
      {
        char info[138];
        menu.GetItem(selection, info, sizeof(info));

        char buffer[2][TEAM_NAME_LENGTH];
        ExplodeString(info, ";", buffer, sizeof(buffer), sizeof(buffer[]));

        strcopy(g_PlayerData[client].name, TEAM_NAME_LENGTH, buffer[0]);
        strcopy(g_PlayerData[client].logo, TEAM_LOGO_LENGTH, buffer[1]);

        SetTeamInfoByClient(client);
      }
    }
    case MenuAction_Cancel:
    {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack)
      {
        CreateTeamMenu(client).Display(client, MENU_TIME_FOREVER);
      }
    }
  }

  return 0;
}

public int menuFlagHandler(Menu menu, MenuAction action, int client, int selection)
{
  switch(action)
  {
    case MenuAction_Select:
    {
      if(IsClientInGame(client))
      {
        char info[138];
        menu.GetItem(selection, info, sizeof(info));

        strcopy(g_PlayerData[client].flag, TEAM_FLAG_LENGTH, info);

        SetTeamInfoByClient(client);
      }
    }
    case MenuAction_Cancel:
    {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack)
      {
        CreateTeamMenu(client).Display(client, MENU_TIME_FOREVER);
      }
    }
  }

  return 0;
}
 
Menu CreateTeamMenu(int client)
{
  Menu menu = new Menu(TeamMenuHandler);
  AddMenuTitle(menu, "个人队标设置||当你为队长时, 队伍设置将会生效");
  AddMenuOption(menu, "matchteam", "使用战队队标");
  AddMenuOption(menu, "flag", "设置旗帜||%s", g_PlayerData[client].flag[0] ? g_PlayerData[client].flag : "无");
  AddMenuOption(menu, "name", "设置队名||%s", g_PlayerData[client].name[0] ? g_PlayerData[client].name : "无");
  AddMenuOption(menu, "name", "设置Logo||%s", g_PlayerData[client].logo[0] ? g_PlayerData[client].logo : "无");
  bool isEnable = g_PlayerData[client].name[0] || g_PlayerData[client].flag[0] || g_PlayerData[client].logo[0];
  AddMenuOptionIsEnable(menu, isEnable, "clear", "清空设置");

  return menu;
}

public int TeamMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsClientInGame(client))
			{
				char info[15];
				menu.GetItem(selection, info, sizeof(info));
				if (StrEqual(info, "matchteam"))
        {
          menuMatchTeam.Display(client, MENU_TIME_FOREVER);
        }
				else if (StrEqual(info, "flag"))
        {
          menuFlag.Display(client, MENU_TIME_FOREVER);
        }
				else if (StrEqual(info, "flag"))
        {
          menuFlag.Display(client, MENU_TIME_FOREVER);
        }
				else if (StrEqual(info, "clear"))
        {
          g_PlayerData[client].Clear();
          CreateTeamMenu(client).Display(client, MENU_TIME_FOREVER);
        }
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action Command_Team(int client, int args) {
  CreateTeamMenu(client).Display(client, MENU_TIME_FOREVER);

  return Plugin_Handled;
}

/** Clear the names/flags when the game is over **/
public void Pugsetup_OnMatchOver(bool hasDemo, const char[] demoFileName) {
  SetTeamInfo(CS_TEAM_T);
  SetTeamInfo(CS_TEAM_CT);
}

void SetTeamInfo(int team, const char[] name = "", const char[] flag = "", const char[] logo = "") {
  int team_int = (team == CS_TEAM_CT) ? 1 : 2;

  char teamCvarName[32];
  char flagCvarName[32];
  char logoCvarName[32];
  Format(teamCvarName, sizeof(teamCvarName), "mp_teamname_%d", team_int);
  Format(flagCvarName, sizeof(flagCvarName), "mp_teamflag_%d", team_int);
  Format(logoCvarName, sizeof(logoCvarName), "mp_teamlogo_%d", team_int);

  SetConVarStringSafe(teamCvarName, name);
  SetConVarStringSafe(flagCvarName, flag);
  SetConVarStringSafe(logoCvarName, logo);
}

void SetTeamInfoByClient(int client) {
  if (!IsPlayer(client)) return;

  SetTeamInfo(GetClientTeam(client), g_PlayerData[client].name, g_PlayerData[client].flag, g_PlayerData[client].logo);
}