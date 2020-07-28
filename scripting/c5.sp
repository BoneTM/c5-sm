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

ConVar g_ServerIP;
ConVar g_MessagePrefix;
ConVar g_VipPrefix;
ConVar g_OpPrefix;

#include "c5/vip.sp"
#include "c5/natives.sp"

public Plugin myinfo =
{
	name = "C5",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vip", CommandVip);
	RegConsoleCmd("sm_login", CommandLogin);
	RegConsoleCmd("sm_dl", CommandLogin);

	g_ServerIP = CreateConVar("sm_c5_server_ip", "localhost", "Current Server IP");
	g_MessagePrefix = CreateConVar("sm_c5_message_prefix", "[{GREEN}C5{NORMAL}]", "message prefix");
	g_VipPrefix = CreateConVar("sm_c5_vip_prefix", "✪", "");
	g_OpPrefix = CreateConVar("sm_c5_op_prefix", "✦", "");
  	AutoExecConfig(true, "c5", "sourcemod/c5");

	g_hOnClientDataLoad = CreateGlobalForward("C5_OnClientDataLoad", ET_Ignore, Param_Cell, Param_Cell);
	if(db == null)
	{
		Database.Connect(SQLConnectCallback, "storage-local");
	}
}

void GetPlayerData(int client)
{
	if (!IsValidClient(client)) return;

	char auth[64];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

	char query[256];
	Format(query, sizeof(query), "select unix_timestamp(vip_time) from c5_player where steam='%s'", auth);

	db.Query(SQL_GetPlayerDataCallback, query, GetClientUserId(client));
}

public void SQL_GetPlayerDataCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsValidClient(client)) return;

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

Menu CreateWebMenu()
{
	Menu menu = new Menu(WebMenuHandler);

	menu.SetTitle("登陆令牌管理");
	menu.AddItem("print", "打印在聊天框");
	menu.AddItem("reset", "重置登陆令牌");

	return menu;
}

public int WebMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsPlayer(client))
			{
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				if(StrEqual(buffer, "print"))
				{
					PrintLoginCode(client);
				}
				else if(StrEqual(buffer, "reset"))
				{
					PrintToChat(client, "\x01\x0B重置\x07登陆令牌\x01中...");
					ResetLoginCode(client);
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void ResetLoginCode(int client)
{
	char code[24];
	
	GetRandomCode(code, sizeof(code));
	char auth[64];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	char query[512];
	Format(query, sizeof(query), "	\
		replace into binder (steam64, code) values ('%s', '%s')", auth, code);
	db.Query(SQL_ResetLoginCodeCallback, query, GetClientUserId(client), DBPrio_High);
}

public void SQL_ResetLoginCodeCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsPlayer(client))
	{
		if (results == null)
		{
			LogError("Query failed! %s", error);

			return;
		}

		PrintLoginCode(client);
	}
}

void PrintLoginCode(int client)
{
	char auth[64];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

	char query[128];
	Format(query, sizeof(query), "select code from binder where steam64='%s'", auth);
	db.Query(SQL_PrintLoginCodeCallback, query, GetClientUserId(client));
}

public void SQL_PrintLoginCodeCallback(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsPlayer(client))
	{
		if (results == null)
		{
			LogError("Query failed! %s", error);
			return;
		}

		if (results.RowCount == 0)
		{
			ResetLoginCode(client);
		}
		else if (results.FetchRow())
		{
			char code[24];
			results.FetchString(0, code, sizeof(code));
			
			if (strlen(code) != 23)
			{
				ResetLoginCode(client);
			}
			else
			{
				PrintToChat(client, "\x01\x0B您的\x07登陆令牌\x01为:\x04%s", code);
			}
		}
	}
}

public Action CommandLogin(int client, int args){
	if (!IsPlayer(client)) return Plugin_Handled;

	CreateWebMenu().Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
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