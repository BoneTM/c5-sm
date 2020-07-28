#include <cstrike>
#include <sourcemod>

#include "include/c5_pug.inc"
#include "include/c5.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "C5: pug - locker",
    author = "Bone",
    description = "Blocks team join events to full teams",
    version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart() {

}

public void OnClientPutInServer(int client) {
	if (!C5_PUG_IsWarmup())
	{
		int count = GetRealClientCount();

		if (count > 10)
		{
			KickClient(client, "比赛进行中, 人员已满");
		}
	}
}

	// kick normal player when the game is full
	// if (C5_PUG_GetGameState() == GameState_Warmup)
	// {
	// 	int count = 0;
	// 	ArrayList normalPlayers = new ArrayList();

	// 	for(int i = 1; i < MAXPLAYERS + 1; i++)
	// 	{
	// 		if (!IsPlayer(i)) continue;

	// 		count++;

	// 		if (g_tags[i][0] == '\0')
	// 		{
	// 			normalPlayers.Push(i);
	// 		}
	// 	}
	// 	PrintToServer("count:%d", count);
	// 	PrintToServer("normalPlayers:%d", normalPlayers.Length);

	// 	if (count >= 10)
	// 	{
	// 		if (normalPlayers.Length == 0)
	// 		{
	// 			// KickClient(client, "全是会员, 没法挤 QAQ");
	// 		}
	// 		else
	// 		{
	// 			int random = GetRandomInt(0, normalPlayers.Length - 1);
	// 			int sorry = normalPlayers.Get(random);
	// 			// KickClient(sorry, "会员来了, 你无了");
	// 		}
	// 	}

	// 	delete normalPlayers;
	// }