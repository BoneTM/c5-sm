
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