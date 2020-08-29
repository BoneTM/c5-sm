#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

char g_WeaponClasses[][] = 
{
/* 0*/ "weapon_awp", /* 1*/ "weapon_ak47", /* 2*/ "weapon_m4a1", /* 3*/ "weapon_m4a1_silencer", /* 4*/ "weapon_deagle", /* 5*/ "weapon_usp_silencer", /* 6*/ "weapon_hkp2000", /* 7*/ "weapon_glock", /* 8*/ "weapon_elite", 
/* 9*/ "weapon_p250", /*10*/ "weapon_cz75a", /*11*/ "weapon_fiveseven", /*12*/ "weapon_tec9", /*13*/ "weapon_revolver", /*14*/ "weapon_nova", /*15*/ "weapon_xm1014", /*16*/ "weapon_mag7", /*17*/ "weapon_sawedoff", 
/*18*/ "weapon_m249", /*19*/ "weapon_negev", /*20*/ "weapon_mp9", /*21*/ "weapon_mac10", /*22*/ "weapon_mp7", /*23*/ "weapon_ump45", /*24*/ "weapon_p90", /*25*/ "weapon_bizon", /*26*/ "weapon_famas", /*27*/ "weapon_galilar", 
/*28*/ "weapon_ssg08", /*29*/ "weapon_aug", /*30*/ "weapon_sg556", /*31*/ "weapon_scar20", /*32*/ "weapon_g3sg1"
};

char g_ItemLastBought[MAXPLAYERS + 1][32];

public Plugin myinfo = 
{
    name = "Pugsetup: auto rebuy",
    author = "Bone",
    description = "auto rebuy in warmup",
    version = "1.0",
    url = ""
};

public void OnPluginStart() {
  HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsWarmup())
    return;

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsPlayer(client) && OnActiveTeam(client)) {
    // remove secondary weapon
    int weapon;
    if (GetSoltByClassname(g_ItemLastBought[client]) == CS_SLOT_SECONDARY)
    {
      if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
      {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
      }
    }
    
    GivePlayerItem(client, g_ItemLastBought[client]);
  }
}

public void OnClientPutInServer(int client)
{
  g_ItemLastBought[client] = "";
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
  char classname[32];
  Format(classname, sizeof(classname), "weapon_%s", weapon);
  if (GetSoltByClassname(classname) != -1)
  {
    g_ItemLastBought[client] = classname;
  }
}

int GetSoltByClassname(const char[] classname)
{
  for (int i = 0; i < sizeof(g_WeaponClasses); i++)
  {
    if (StrEqual(g_WeaponClasses[i], classname))
    {
      if (i >= 4 && i <= 13)
      {
        return CS_SLOT_SECONDARY;
      }
      else
      {
        return CS_SLOT_PRIMARY;
      }
    }
  }

  return -1;
}