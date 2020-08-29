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
		
		for (int i = 1; i <= MaxClients; i++) {
			if (g_VipTime[i] > 0)
			{
				GetPlayerData(i);
			}
		}
	}
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

	if (results.RowCount == 0)
	{
		char auth[64];
		GetAuth(client, auth, sizeof(auth));

		char query[256];
		Format(query, sizeof(query), "insert c5_player values ('%s', null)", auth);
		db.Query(SQL_NothingCallback, query);
	}
	else if (results.FetchRow())
	{
		g_VipTime[client] = results.FetchInt(0);
	}

	char prefix[30] = "";

	if (VIP_IsVIP(client))
	{
		g_VipPrefix.GetString(prefix, sizeof(prefix));
	}
	
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		g_OpPrefix.GetString(prefix, sizeof(prefix));
	}

	MessageToAll("%s %N 正在连接到服务器...", prefix, client);
	
	Call_StartForward(g_hOnClientDataLoad);
	Call_PushCell(client);
	Call_PushCell(VIP_IsVIP(client));
	Call_Finish();
}


public void SQL_NothingCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[C5] Query Fail: %s", error);
		return;
	}
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
		Message(client, "您还不是VIP!");
	}
	else if (results.FetchRow())
	{
		char vipTime[24];
		results.FetchString(0, vipTime, sizeof(vipTime));
		
		Message(client, "您的VIP到期时间为: %s", vipTime);
	}
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
		Message(client, "卡密无效!");
	}
	else if (results.FetchRow())
	{
		int vipDay;
		vipDay = results.FetchInt(1);

		char code[24];
		results.FetchString(0, code, sizeof(code));
		
		
		char auth[64];
		GetAuth(client, auth, sizeof(auth));

		char query[128];
		Transaction t = new Transaction();
		Format(query, sizeof(query), "update c5_vip_code set steam = '%s' where code = '%s'", auth, code);
		t.AddQuery(query);
		if (VIP_IsVIP(client))
		{
			Format(query, sizeof(query), "update c5_player set vip_time = date_add(vip_time, interval %d day) where steam = '%s'", vipDay, auth);
		}
		else
		{
			Format(query, sizeof(query), "update c5_player set vip_time = date_add(now(), interval %d day) where steam = '%s'", vipDay, auth);
		}
		t.AddQuery(query);
		db.Execute(t, T_UseVipCodeSuccess, T_UseVipCodeFailure, GetClientUserId(client));
	}
}

public void T_UseVipCodeSuccess(Database database, int userid, int numQueries, Handle[] results, any[] queryData) {
	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;
	
	Message(client, "激活成功!");
	ShowVipInfo(client);
	GetPlayerData(client);
}

public void T_UseVipCodeFailure(Database database, int userid, int numQueries, const char[] error, int failIndex, any[] queryData) {
	LogError("Transaction failed, error = %s", error);

	int client = GetClientOfUserId(userid);

	if (!IsPlayer(client)) return;

	Message(client, "系统错误, 请联系管理员!");
}
