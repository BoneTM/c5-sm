#include <cstrike>
#include <sourcemod>

#include "include/c5.inc"
#include "include/c5_pug.inc"
#include "include/c5_vip.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

char g_tags[MAXPLAYERS + 1][30];

public Plugin myinfo = 
{
    name = "C5: PUG - tag",
    author = "Bone",
    description = "Name Tag",
    version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart() {
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsPlayer(client)) return;

	if (!C5_PUG_IsMatchLive()) return;
	
	if (g_tags[client][0])
	{
		CS_SetClientClanTag(client, g_tags[client]);
	}
}

public void C5_OnClientDataLoad(int client, bool isVip)
{
	Format(g_tags[client], sizeof(g_tags[]), "");

	char prefix[30];
	if (isVip)
	{
		C5_GetVipPrefix(prefix, sizeof(prefix));
		Format(g_tags[client], sizeof(g_tags[]), prefix);
	}
	
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		C5_GetOpPrefix(prefix, sizeof(prefix));
		Format(g_tags[client], sizeof(g_tags[]), prefix);
	}
}
