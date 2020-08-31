#include <sourcemod>
#include <regex>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Test",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};


public void OnPluginStart()
{
	RegConsoleCmd("sm_test", CommandTest);
}
public Action CommandTest(int client, int args)
{
	char code[128];
	char dd[128];
	char Arguments[256], arg[50], time[20];

	if(args >= 1 && GetCmdArg(1, code, sizeof(code)))
	{
		GetCmdArgString(Arguments, sizeof(Arguments));
		BreakString(Arguments, arg, sizeof(arg));
		GetAuthFromString(arg, dd, sizeof(dd));
	}
	PrintToChatAll(dd);
	
	return Plugin_Handled;
}

stock bool GetAuthFromString(const char[] authid, char[] auth, int size) {
	int accountId = 0;
	Regex steam2 = new Regex("^STEAM_[0-9]:([0-9]):([0-9]+)$");
	Regex steam3 = new Regex("^\\[U:[0-9]:([0-9]+)\\]$");

	if (steam2.Match(authid) > 0)
	{
		char temp[32];
		steam2.GetSubString(1, temp, sizeof(temp));
		int left = StringToInt(temp);
		steam2.GetSubString(2, temp, sizeof(temp));
		int right = StringToInt(temp);
		accountId = left + right * 2;
	}

	if (steam3.Match(authid) > 0)
	{
		char temp[32];
		steam3.GetSubString(1, temp, sizeof(temp));
		accountId = StringToInt(temp);
	}

	int up = 765611979;
	int down = 60265728 + accountId;
	int front = down / 100000000;
	up += front;
	char downStr[32];
	IntToString(down, downStr, sizeof(downStr));

	int value = front;
	int frontSize = 0;
	while(value)
	{
		PrintToChatAll("%d", frontSize);
		frontSize++;
		value /= 10;
	}
	
	Format(auth, size, "%d-%s", up, downStr[frontSize]);
	
	return true;
}