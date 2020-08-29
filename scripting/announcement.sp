#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include "include/message.inc"

#pragma semicolon 1
#pragma newdecls required

#define TIME_SEND 60.0
static const char g_Info[][] = 
{
	"欢迎来到{GREEN}God社区{NORMAL}, Q群:{LIGHT_RED}760586300",
	"购买{LIGHT_RED}VIP{NORMAL}, 进群了解详情, Q群:{LIGHT_RED}760586300",
	"输入 !diy 进入个性化系统 修改皮肤",
	"CSGO 开箱首选 {GREEN}D2topbox.com"
};

public Plugin myinfo =
{
	name = "Announcement",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	CreateTimer(TIME_SEND, Timer_Announcement, _, TIMER_REPEAT);
}

public Action Timer_Announcement(Handle timer)
{
	static int index = 0;

	MessageToAll(g_Info[index++ % sizeof(g_Info)]);

	return Plugin_Continue;
}