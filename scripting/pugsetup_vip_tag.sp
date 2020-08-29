#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "include/message.inc"
#include "include/vip.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

char g_tags[MAXPLAYERS + 1][30];

public Plugin myinfo = 
{
    name = "Pugsetup: Tag",
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

	if (!Pugsetup_IsMatchLive()) return;
	
	if (g_tags[client][0])
	{
		CS_SetClientClanTag(client, g_tags[client]);
	}
}

public void VIP_OnClientDataLoad(int client, bool isVip)
{
	Format(g_tags[client], sizeof(g_tags[]), "");

	char prefix[30];
	if (isVip)
	{
		VIP_GetVipPrefix(prefix, sizeof(prefix));
		Format(g_tags[client], sizeof(g_tags[]), prefix);
	}
	
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		VIP_GetOpPrefix(prefix, sizeof(prefix));
		Format(g_tags[client], sizeof(g_tags[]), prefix);
	}
}
