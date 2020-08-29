#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "include/vip.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

bool g_LockDecidedMapChanging = false;

public Plugin myinfo = 
{
    name = "Pugsetup: Vip Kicker",
    author = "Bone",
    description = "",
    version = "1.0",
	url = "https://bonetm.github.io/"
};

public void Pugsetup_OnDecidedMapChanging()
{
	g_LockDecidedMapChanging = true;
	CreateTimer(30.0, Timer_AfterLockdown);
}

public Action Timer_AfterLockdown(Handle timer)
{
	g_LockDecidedMapChanging = false;

	return Plugin_Stop;
}

public void VIP_OnClientDataLoad(int client, bool isVip)
{
	if (g_LockDecidedMapChanging)
	{
		if (!Pugsetup_IsClientInAuths(client))
		{
			KickClient(client, "投票换图中 | 30秒保护时间");
		}

		return;
	}

	if (Pugsetup_IsWarmup())
	{
		ArrayList normalPlayers = new ArrayList();

		for(int i = 1; i < MaxClients; i++)
		{
			if (!IsPlayer(i)) continue;
			if (!VIP_HasClientLoaded(i)) continue;

			if (!VIP_IsVIP(i))
			{
				normalPlayers.Push(i);
			}
		}

		if (VIP_GetLoadedCount() > 10)
		{
			if (isVip)
			{
				if (normalPlayers.Length == 0)
				{
					KickClient(client, "全是会员 | 没法挤 QAQ | Q群:760586300");
				}
				else
				{
					KickClient(GetArrayCellRandom(normalPlayers), "会员来了 | 你无了 | Q群:760586300");
				}
			}
			else
			{
				KickClient(client, "人太多啦 | VIP可挤人 | Q群:760586300");
			}
		}

		delete normalPlayers;
	}
	else
	{
		if (GetUserAdmin(client) == INVALID_ADMIN_ID)
		{
			int count = GetRealClientCount();

			if (count > Pugsetup_GetPugMaxPlayers())
			{
				KickClient(client, "比赛进行中, 人员已满");
			}
		}
	}
}