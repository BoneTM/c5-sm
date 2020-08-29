#include <clientprefs>
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

Database db = null;
char queryBuffer[1024];

int g_MatchID = -1;

public Plugin myinfo = 
{
    name = "PugSetup: Ban Abort",
    author = "Bone",
    description = "",
    version = "1.0",
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart()
{

}

public void Pugsetup_OnMatchOver(bool hasDemo, const char[] demoFileName)
{
  
}
