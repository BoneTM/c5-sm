#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include "include/c5.inc"
#include "include/pugsetup.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

Database db = null;

char g_tags[MAXPLAYERS + 1][24];

C5_CONFIG g_Config;

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
	
	HookEvent("player_spawn", Event_PlayerSpawn);

	if(db == null)
	{
		Database.Connect(SQLConnectCallback, "storage-local");
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsPlayer(client)) return;

	if (PugSetup_GetGameState() != GameState_Live) return;
	
	if(g_tags[client][0])
	{
		CS_SetClientClanTag(client, g_tags[client]);
	}
}

public void OnClientPutInServer(int client){
	if (PugSetup_GetGameState() != GameState_Warmup)
	{
		int count = 0;
		for(int i = 1; i < MAXPLAYERS + 1; i++)
		{
			if (!IsPlayer(i)) continue;

			count++;
		}

		if (count > 10)
		{
			KickClient(client, "比赛进行中, 人员已满");
		}
	}

	GetPlayerData(client);
}

void GetPlayerData(int client)
{
	if (!IsPlayer(client)) return;

	char auth[64];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

	char query[256];
	Format(query, sizeof(query), "select unix_timestamp(vip_time) from c5_player where steam='%s'", auth);

	db.Query(T_GetPlayerDataAndApply, query, GetClientUserId(client));
}

public void T_GetPlayerDataAndApply(Database database, DBResultSet results, const char[] error, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;

	if (results == null)
	{
		LogError("Query failed! %s", error);
		return;
	}

	Format(g_tags[client], sizeof(g_tags[]), "");

	if (results.RowCount == 0)
	{

	}
	else if (results.FetchRow())
	{
		int vipTime = results.FetchInt(0);
		int now = GetTime();
		if (now > vipTime)
		{
			// Format(tag, sizeof(tag), "[NO VIP]");
			// PrintToChat(client, "\x01\x0B[系统提示]\x07您不是VIP 60s后将被踢出");
			// KickPlayer(client);
		}
		else
		{
			Format(g_tags[client], sizeof(g_tags[]), g_Config.VIP_PREFIX);

			// kick normal player when the game is full
			if (PugSetup_GetGameState() == GameState_Warmup)
			{
				int count = 0;
				ArrayList normalPlayers = new ArrayList();

				for(int i = 1; i < MAXPLAYERS + 1; i++)
				{
					if (!IsPlayer(i)) continue;

					count++;

					if (g_tags[i][0] == '\0')
					{
						normalPlayers.Push(i);
					}
				}
				PrintToServer("count:%d", count);
				PrintToServer("normalPlayers:%d", normalPlayers.Length);

				if (count >= 10)
				{
					if (normalPlayers.Length == 0)
					{
						// KickClient(client, "全是会员, 没法挤 QAQ");
					}
					else
					{
						int random = GetRandomInt(0, normalPlayers.Length - 1);
						int sorry = normalPlayers.Get(random);
						// KickClient(sorry, "会员来了, 你无了");
					}
				}

				delete normalPlayers;
			}

		}
	}
	
	// Format(clientName, sizeof(clientName), "%s%s", tag, clientName);
	
	// SetPlayerName(client, clientName);
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		Format(g_tags[client], sizeof(g_tags[]), g_Config.OP_PREFIX);
	}
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

public Action CommandLogin(int client, int args){
	if (!IsPlayer(client)) return Plugin_Handled;

	CreateWebMenu().Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
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

		LoadConfig();
	}
}

void LoadConfig()
{
	db.Query(SQL_LoadConfigCallback, "select * from c5_config where id=1");
}

public void SQL_LoadConfigCallback(Database database, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Query failed! %s", error);
		return;
	}

	if (results.RowCount == 0)
	{
		
	}
	else if (results.FetchRow())
	{
		results.FetchString(1, g_Config.MESSAGE_PREFIX, sizeof(g_Config.MESSAGE_PREFIX));
		results.FetchString(1, g_Config.VIP_PREFIX, sizeof(g_Config.VIP_PREFIX));
		results.FetchString(1, g_Config.OP_PREFIX, sizeof(g_Config.OP_PREFIX));
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