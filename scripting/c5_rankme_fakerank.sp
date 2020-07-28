#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <kento_rankme/rankme>

#pragma semicolon 1
#pragma newdecls required

int g_iRankOffset;
int g_iRankPlayers[MAXPLAYERS + 1] = {3, ...};

enum RankIcon
{
	NotRanked,
	SilverI,
	SilverII,
	SilverIII,
	SilverIV,
	SilverElite,
	SilverEliteMaster,
	GoldNovaI,
	GoldNovaII,
	GoldNovaIII,
	GoldNovaMaster,
	MasterGuardianI,
	MasterGuardianII,
	MasterGuardianElite,
	DistinguishedMasterGuardian,
	LegendaryEagle,
	LegendaryEagleMaster,
	SupremeMasterFirstClass,
	TheGlobalElite
};

public Plugin myinfo =
{
    name = "C5: RankMe - fake rank",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", EventPlayerSpawn);
}

public void EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  	int client = GetClientOfUserId(event.GetInt("userid"));
	RankMe_GetRank(client, RankConnectCallback);
}

public Action RankConnectCallback(int client, int rank, any data)
{
	int totalPlayers = RankMe_GetTotalPlayers();
	int interval = totalPlayers / 18;
	int rankIconIndex = rank / interval;

	if (rankIconIndex < 1)
	{
		rankIconIndex = 1;
	}
	else if (rankIconIndex > 18)
	{
		rankIconIndex = 18;
	}

	g_iRankPlayers[client] = 19 - rankIconIndex;
}

public void OnMapStart()
{
	g_iRankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
	SDKHook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, Hook_OnThinkPost);
}

public void OnMapEnd()
{
	SDKUnhook(FindEntityByClassname(MaxClients + 1, "cs_player_manager"), SDKHook_ThinkPost, Hook_OnThinkPost);
}

public void Hook_OnThinkPost(int iEnt)
{
	SetEntDataArray(iEnt, g_iRankOffset, g_iRankPlayers, MAXPLAYERS + 1);
}