#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include "include/message.inc"
#include "include/vip.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

Database db = null;

int g_VipTime[MAXPLAYERS + 1];

/** Forwards **/
Handle g_hOnClientDataLoad = INVALID_HANDLE;

ConVar g_VipPrefix;
ConVar g_OpPrefix;

#include "vip/menu.sp"
#include "vip/natives.sp"
#include "vip/sql_callback.sp"

public Plugin myinfo =
{
	name = "VIP System",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vip", CommandVip);

	g_VipPrefix = CreateConVar("sm_vip_prefix", "✪", "");
	g_OpPrefix = CreateConVar("sm_op_prefix", "✦", "");
  	AutoExecConfig(true, "vip", "sourcemod");

	g_hOnClientDataLoad = CreateGlobalForward("VIP_OnClientDataLoad", ET_Ignore, Param_Cell, Param_Cell);
	
	if(db == null)
	{
		Database.Connect(SQLConnectCallback, "storage-local");
	}

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public Action Event_PlayerDisconnect(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsPlayer(client)) {
		g_VipTime[client] = 0;
	}
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++) {
		g_VipTime[i] = 0;
	}
}

void GetPlayerData(int client)
{
	if (!IsPlayer(client)) return;

	char auth[64];
	GetAuth(client, auth, sizeof(auth));

	char query[256];
	Format(query, sizeof(query), "select unix_timestamp(vip_time) from c5_player where steam='%s'", auth);

	db.Query(SQL_GetPlayerDataCallback, query, GetClientUserId(client));
}

public void OnClientPutInServer(int client)
{
	GetPlayerData(client);
}

public Action CommandVip(int client, int args){
	if (!IsPlayer(client)) return Plugin_Handled;

	char code[PLATFORM_MAX_PATH];

	if(args >= 1 && GetCmdArg(1, code, sizeof(code)))
	{
		UseVipCode(client, code);
	}
	else
	{
		ShowVipInfo(client);
	}
	
	return Plugin_Handled;
}

void ShowVipInfo(int client)
{
	char auth[64];
	GetAuth(client, auth, sizeof(auth));

	char query[128];
	Format(query, sizeof(query), "select vip_time from c5_player where steam='%s'", auth);
	db.Query(SQL_ShowVipInfoCallback, query, GetClientUserId(client));
}


void UseVipCode(int client, const char[] code)
{
	char query[128];
	Format(query, sizeof(query), "select code, time from c5_vip_code where code = '%s' and steam = ''", code);
	db.Query(SQL_UseVipCodeCallback, query, GetClientUserId(client));
}