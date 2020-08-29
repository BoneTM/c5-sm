#include <sourcemod>
#include <SteamWorks>
#include <regex>

#include "include/vip.inc"
#include "include/message.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

#define TIME_LIMIT 300
static const char g_Url[] = "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=B33388E194EEC145E84F2C2207DC7FEA&steamid=%s&appids_filter[0]=730";
static const char g_ChatInfo[] = "{LIGHT_RED}游戏时间不满300小时 或 STEAM资料非公开, 30s后您将被请出服务器 | VIP可解除限制 | Q群:760586300";
static const char g_KickInfo[] = "游戏时间不满300小时或资料不公开 | VIP可解除限制 | Q群:760586300";


public Plugin myinfo =
{
	name = "Steam Profile Limiter",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void VIP_OnClientDataLoad(int client, bool isVip)
{
	if (!isVip && IsPlayer(client))
	{
		SteamWorks_SendHTTPRequest(CreateRequest_TimePlayed(client));
	}
}

Handle CreateRequest_TimePlayed(int client)
{
    char auth[64];
    GetAuth(client, auth, sizeof(auth));

    char url[256];
    Format(url, sizeof(url), g_Url, auth);

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    
    SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
    SteamWorks_SetHTTPCallbacks(request, TimePlayed_OnHTTPResponse);

    return request;
}

public int TimePlayed_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK || !IsPlayer(client))
    {
        delete request;
        return;
    }

    int bufferSize;
    SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
    
    char[] body = new char[bufferSize];
    SteamWorks_GetHTTPResponseBodyData(request, body, bufferSize);
    Regex regex = new Regex("(?<=\"playtime_forever\":).*?(?=,)");
    if (regex.Match(body) > 0)
    {
        char time[128];
        regex.GetSubString(0, time, sizeof(time));
        LogMessage("player: %N, time: %d", client, time);
        
        int hour = StringToInt(time) / 60;

        if (hour < TIME_LIMIT)
        {
            Message(client, g_ChatInfo);
            KickClient(client, g_KickInfo);
        }
    }
    else
    {
        Message(client, g_ChatInfo);
        KickClient(client, g_KickInfo);
    }
    
    delete request;
}
