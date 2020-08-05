#include <cstrike>
#include <sourcemod>

#include "include/c5_pug.inc"
#include "include/c5.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "C5: PUG - vip kicker",
    author = "Bone",
    description = "",
    version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart() {
	
}

public void C5_OnClientDataLoad(int client, bool isVip)
{
	if (C5_PUG_IsWarmup())
	{
		int count = 0;
		ArrayList normalPlayers = new ArrayList();

		for(int i = 1; i < MaxClients; i++)
		{
			if (!IsPlayer(i)) continue;

			count++;

			if (g_tags[i][0] == '\0')
			{
				normalPlayers.Push(i);
			}
		}

		if (count > 10)
		{
			if (isVip)
			{
				if (normalPlayers.Length == 0)
				{
					KickClient(client, "全是会员, 没法挤 QAQ");
				}
				else
				{
					KickClient(GetArrayCellRandom(normalPlayers), "会员来了, 你无了");
				}
			}
			else
			{
				KickClient(client, "人太多啦, 想挤人请充vip");
			}
		}

		delete normalPlayers;
	}
}