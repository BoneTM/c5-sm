#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include "include/c5.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

Database db = null;

bool g_VipClient[MAXPLAYERS + 1];

/** Forwards **/
Handle g_hOnClientDataLoad = INVALID_HANDLE;

ConVar g_VipPrefix;
ConVar g_OpPrefix;

public Plugin myinfo =
{
	name = "C5: VIP",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vip", CommandVip);

	g_VipPrefix = CreateConVar("sm_c5_vip_prefix", "✪", "");
	g_OpPrefix = CreateConVar("sm_c5_op_prefix", "✦", "");
  	AutoExecConfig(true, "c5_vip", "sourcemod/c5");

	g_hOnClientDataLoad = CreateGlobalForward("C5_OnClientDataLoad", ET_Ignore, Param_Cell, Param_Cell);
	
	if(db == null)
	{
		Database.Connect(SQLConnectCallback, "storage-local");
	}
}

void GetPlayerData(int client)
{
	if (!IsPlayer(client)) return;

	char auth[64];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

	char query[256];
	Format(query, sizeof(query), "select unix_timestamp(vip_time) from c5_player where steam='%s'", auth);

	db.Query(SQL_GetPlayerDataCallback, query, GetClientUserId(client));
}

public void SQL_GetPlayerDataCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;

	if (results == null)
	{
		LogError("Query failed! %s", error);
		return;
	}

	g_VipClient[client] = false;
	if (results.RowCount == 0)
	{
		char auth[64];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

		char query[256];
		Format(query, sizeof(query), "insert c5_player values ('%s', null)", auth);
		db.Query(SQL_NothingCallback, query);
	}
	else if (results.FetchRow())
	{
		if (GetTime() < results.FetchInt(0))
		{
			g_VipClient[client] = true;
		}
	}

	char prefix[30] = "";

	if (g_VipClient[client])
	{
		g_VipPrefix.GetString(prefix, sizeof(prefix));
	}
	
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		g_OpPrefix.GetString(prefix, sizeof(prefix));
	}

	C5_MessageToAll("%s %N 正在连接到服务器...", prefix, client);
	
	Call_StartForward(g_hOnClientDataLoad);
	Call_PushCell(client);
	Call_PushCell(g_VipClient[client]);
	Call_Finish();
}

public void OnClientPutInServer(int client)
{
	GetPlayerData(client);
}

public void SQLConnectCallback(Database database, const char[] error, any data)
{
	if (database == null)
	{
		LogError("Database failure: %s", error);
	}
	else
	{
		db = database;
		if(!db.SetCharset("utf8mb4")){
			db.SetCharset("utf8");
		}
	}
}

public void SQL_NothingCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[C5] Query Fail: %s", error);
		return;
	}
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
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

	char query[128];
	Format(query, sizeof(query), "select vip_time from c5_player where steam='%s'", auth);
	db.Query(SQL_ShowVipInfoCallback, query, GetClientUserId(client));
}

void SQL_ShowVipInfoCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;

	if (results == null)
	{
		LogError("Query failed! %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		C5_Message(client, "您还不是VIP!");
	}
	else if (results.FetchRow())
	{
		char vipTime[24];
		results.FetchString(0, vipTime, sizeof(vipTime));
		
		C5_Message(client, "您的VIP到期时间为: %s", vipTime);
	}
}

void UseVipCode(int client, const char[] code)
{
	char query[128];
	Format(query, sizeof(query), "select code, time from c5_vip_code where code = '%s' and steam = ''", code);
	db.Query(SQL_UseVipCodeCallback, query, GetClientUserId(client));
}

void SQL_UseVipCodeCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;
	
	if (results == null)
	{
		LogError("Query failed! %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		C5_Message(client, "卡密无效!");
	}
	else if (results.FetchRow())
	{
		int vipDay;
		vipDay = results.FetchInt(1);

		char code[24];
		results.FetchString(0, code, sizeof(code));
		
		
		char auth[64];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

		Transaction t = new Transaction();
		
		char query[128];
		Format(query, sizeof(query), "update c5_vip_code set steam = '%s' where code = '%s'", auth, code);
		t.AddQuery(query);
		Format(query, sizeof(query), "update c5_player set vip_time = date_add(vip_time, interval %d day) where steam = '%s'", vipDay, auth);
		t.AddQuery(query);
		db.Execute(t, T_UseVipCodeSuccess, T_UseVipCodeFailure, GetClientUserId(client));
	}
}

public void T_UseVipCodeSuccess(Database database, int userid, int numQueries, Handle[] results, any[] queryData) {
	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;
	
	C5_Message(client, "激活成功!");
	ShowVipInfo(client);
}

public void T_UseVipCodeFailure(Database database, int userid, int numQueries, const char[] error, int failIndex, any[] queryData) {
	LogError("Transaction failed, error = %s", error);

	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;

	C5_Message(client, "系统错误, 请联系管理员!");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  CreateNative("C5_GetVipPrefix", Native_GetVipPrefix);
  CreateNative("C5_GetOpPrefix", Native_GetOpPrefix);

  RegPluginLibrary("c5_vip");

  return APLRes_Success;
}

public int Native_GetVipPrefix(Handle plugin, int numParams)
{
  char prefix[30];
  g_VipPrefix.GetString(prefix, sizeof(prefix));
  SetNativeString(1, prefix, GetNativeCell(2));
}

public int Native_GetOpPrefix(Handle plugin, int numParams)
{
  char prefix[30];
  g_OpPrefix.GetString(prefix, sizeof(prefix));
  SetNativeString(1, prefix, GetNativeCell(2));
}
