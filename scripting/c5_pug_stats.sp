#include <clientprefs>
#include <cstrike>
#include <sourcemod>

#include "include/c5.inc"
#include "include/c5_pug.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

#define AUTH_LENGTH 64

// Series stats (root section)
#define STAT_SERIESWINNER "winner"
#define STAT_SERIESTYPE "series_type"
#define STAT_SERIES_TEAM1NAME "team1_name"
#define STAT_SERIES_TEAM2NAME "team2_name"
#define STAT_SERIES_FORFEIT "forfeit"

// Map stats (under "map0", "map1", etc.)
#define STAT_MAPNAME "mapname"
#define STAT_MAPWINNER "winner"
#define STAT_DEMOFILENAME "demo_filename"

// Team stats (under map section, then "team1" or "team2")
#define STAT_TEAMSCORE "score"

// Player stats (under map section, then team section, then player's steam64)
#define STAT_NAME "name"
#define STAT_KILLS "kills"
#define STAT_DEATHS "deaths"
#define STAT_ASSISTS "assists"
#define STAT_FLASHBANG_ASSISTS "flashbang_assists"
#define STAT_TEAMKILLS "teamkills"
#define STAT_SUICIDES "suicides"
#define STAT_DAMAGE "damage"
#define STAT_HEADSHOT_KILLS "headshot_kills"
#define STAT_ROUNDSPLAYED "roundsplayed"
#define STAT_BOMBDEFUSES "bomb_defuses"
#define STAT_BOMBPLANTS "bomb_plants"
#define STAT_1K "k1"
#define STAT_2K "k2"
#define STAT_3K "k3"
#define STAT_4K "k4"
#define STAT_5K "k5"
#define STAT_V1 "v1"
#define STAT_V2 "v2"
#define STAT_V3 "v3"
#define STAT_V4 "v4"
#define STAT_V5 "v5"
#define STAT_FIRSTKILL_T "firstkill_t"
#define STAT_FIRSTKILL_CT "firstkill_ct"
#define STAT_FIRSTDEATH_T "firstdeath_t"
#define STAT_FIRSTDEATH_CT "firstdeath_ct"

enum MatchTeam {
  MatchTeam_Team1,
  MatchTeam_Team2,
  MatchTeam_TeamSpec,
  MatchTeam_TeamNone,
  MatchTeam_Count,
};

// Stats values
bool g_SetTeamClutching[4];
int g_RoundKills[MAXPLAYERS + 1];  // kills per round each client has gotten
int g_RoundClutchingEnemyCount[MAXPLAYERS + 1];  // number of enemies left alive when last alive on your team
int g_LastFlashBangThrower = -1;    // last client to have a flashbang detonate
int g_RoundFlashedBy[MAXPLAYERS + 1];
bool g_TeamFirstKillDone[4];
bool g_TeamFirstDeathDone[4];
int g_PlayerKilledBy[MAXPLAYERS + 1];
float g_PlayerKilledByTime[MAXPLAYERS + 1];
int g_DamageDone[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_DamageDoneHits[MAXPLAYERS + 1][MAXPLAYERS + 1];
KeyValues g_StatsKv;
Database db;
char queryBuffer[1024];
int g_MatchID;
int g_TeamSide[4];            // Current CS_TEAM_* side for the team.

public Plugin myinfo = {
    name = "CS:GO PugSetup: Stats",
    author = "Bone",
    description = "",
    version = "beta",
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
  //hook
  HookEvent("player_death", Event_PlayerDeathEvent);
  HookEvent("player_hurt", Event_DamageDealtEvent, EventHookMode_Pre);
  HookEvent("bomb_planted", Event_BombPlantedEvent);
  HookEvent("bomb_defused", Event_BombDefusedEvent);
  HookEvent("flashbang_detonate", Event_FlashbangDetonateEvent, EventHookMode_Pre);
  HookEvent("player_blind", Event_PlayerBlindEvent);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("round_prestart", Event_RoundPreStart);
  HookEvent("round_freeze_end", Event_FreezeEnd);

  if(db == null)
  {
    Database.Connect(SQLConnectCallback, "storage-local");
  }

  //init
  Reset();
}

//================================= Forward
public void C5_PUG_OnLive(){
  Reset();
  SetStartingTeams();
  InitMatch();
}

public void C5_PUG_OnMatchOver(bool hasDemo, const char[] demoFileName){
  GoToMap();

  if (hasDemo){
    g_StatsKv.SetString(STAT_DEMOFILENAME, demoFileName);
  }

  GoBackFromMap();
  
  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `stats_matches` \
        SET end_time = NOW() WHERE match_id = %d", g_MatchID);
  db.Query(SQLErrorCheckCallback, queryBuffer);
}

public void OnClientPutInServer(int client) {
  if (IsFakeClient(client)) {
    return;
  }

  Stats_ResetClientRoundValues(client);
}

public void Reset(){
  if (g_StatsKv != null) {
    delete g_StatsKv;
  }
  g_StatsKv = new KeyValues("Stats");
  
  g_StatsKv.SetString(STAT_SERIES_TEAM1NAME, "TeamA");
  g_StatsKv.SetString(STAT_SERIES_TEAM2NAME, "TeamB");
}

public void InitMatch() {
  Transaction t = SQL_CreateTransaction();

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  Format(queryBuffer, sizeof(queryBuffer), "INSERT INTO `stats_matches` (start_time, map) VALUES (NOW(), '%s')", mapName);
  // LogDebug(queryBuffer);
  t.AddQuery(queryBuffer);

  Format(queryBuffer, sizeof(queryBuffer), "SELECT LAST_INSERT_ID()");
  // LogDebug(queryBuffer);
  t.AddQuery(queryBuffer);

  db.Execute(t, MatchInitSuccess, MatchInitFailure);
}

public void Stats_ResetClientRoundValues(int client) {
  g_RoundKills[client] = 0;
  g_RoundClutchingEnemyCount[client] = 0;
  g_RoundFlashedBy[client] = 0;
  g_PlayerKilledBy[client] = -1;
  g_PlayerKilledByTime[client] = 0.0;
  for (int i = 1; i <= MaxClients; i++) {
    g_DamageDone[client][i] = 0;
    g_DamageDoneHits[client][i] = 0;
  }
}

public void UpdateRoundStats() {
  // Update team scores
  int t1score = CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1));
  int t2score = CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2));

  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `stats_matches` \
        SET team1_score = %d, team2_score = %d WHERE match_id = %d",
         t1score, t2score, g_MatchID);
  // LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);

  // Update player stats
  if (g_StatsKv.JumpToKey("map")) {
    if (g_StatsKv.JumpToKey("team1")) {
      AddPlayerStats(MatchTeam_Team1);
      g_StatsKv.GoBack();
    }
    if (g_StatsKv.JumpToKey("team2")) {
      AddPlayerStats(MatchTeam_Team2);
      g_StatsKv.GoBack();
    }
    g_StatsKv.GoBack();
  }
}

public void AddPlayerStats(MatchTeam team) {
  char name[MAX_NAME_LENGTH];
  char auth[AUTH_LENGTH];
  char nameSz[MAX_NAME_LENGTH * 2 + 1];
  char authSz[AUTH_LENGTH * 2 + 1];

  if (g_StatsKv.GotoFirstSubKey()) {
    do {
      g_StatsKv.GetSectionName(auth, sizeof(auth));
      g_StatsKv.GetString("name", name, sizeof(name));
      db.Escape(auth, authSz, sizeof(authSz));
      db.Escape(name, nameSz, sizeof(nameSz));

      int kills = g_StatsKv.GetNum(STAT_KILLS);
      int deaths = g_StatsKv.GetNum(STAT_DEATHS);
      int flashbang_assists = g_StatsKv.GetNum(STAT_FLASHBANG_ASSISTS);
      int assists = g_StatsKv.GetNum(STAT_ASSISTS);
      int teamkills = g_StatsKv.GetNum(STAT_TEAMKILLS);
      int damage = g_StatsKv.GetNum(STAT_DAMAGE);
      int headshot_kills = g_StatsKv.GetNum(STAT_HEADSHOT_KILLS);
      int roundsplayed = g_StatsKv.GetNum(STAT_ROUNDSPLAYED);
      int plants = g_StatsKv.GetNum(STAT_BOMBPLANTS);
      int defuses = g_StatsKv.GetNum(STAT_BOMBDEFUSES);
      int v1 = g_StatsKv.GetNum(STAT_V1);
      int v2 = g_StatsKv.GetNum(STAT_V2);
      int v3 = g_StatsKv.GetNum(STAT_V3);
      int v4 = g_StatsKv.GetNum(STAT_V4);
      int v5 = g_StatsKv.GetNum(STAT_V5);
      int k2 = g_StatsKv.GetNum(STAT_2K);
      int k3 = g_StatsKv.GetNum(STAT_3K);
      int k4 = g_StatsKv.GetNum(STAT_4K);
      int k5 = g_StatsKv.GetNum(STAT_5K);
      int firstkill_t = g_StatsKv.GetNum(STAT_FIRSTKILL_T);
      int firstkill_ct = g_StatsKv.GetNum(STAT_FIRSTKILL_CT);
      int firstdeath_t = g_StatsKv.GetNum(STAT_FIRSTDEATH_T);
      int firstdeath_ct = g_StatsKv.GetNum(STAT_FIRSTDEATH_CT);

      char teamString[16];
      if (team == MatchTeam_Team1) {
        Format(teamString, sizeof(teamString), "team1");
      } else if (team == MatchTeam_Team2) {
        Format(teamString, sizeof(teamString), "team2");
      } 

      // TODO: this should really get split up somehow. Once it hits 32-arguments
      // (aka just a few more) it will cause runtime errors and the Format will fail.
      Format(queryBuffer, sizeof(queryBuffer), "REPLACE INTO `stats_players` \
                (match_id, steam64, team, \
                rounds_played, name, kills, deaths, flashbang_assists, \
                assists, teamkills, headshot_kills, damage, \
                bomb_plants, bomb_defuses, \
                v1, v2, v3, v4, v5, \
                k2, k3, k4, k5, \
                firstkill_t, firstkill_ct, firstdeath_t, firstdeath_ct \
                ) VALUES \
                (%d, '%s', '%s', \
                %d, '%s', %d, %d, %d, \
                %d, %d, %d, %d, \
                %d, %d, \
                %d, %d, %d, %d, %d, \
                %d, %d, %d, %d, \
                %d, %d, %d, %d)",
             g_MatchID, authSz, teamString, roundsplayed, nameSz, kills, deaths,
             flashbang_assists, assists, teamkills, headshot_kills, damage, plants, defuses, v1, v2,
             v3, v4, v5, k2, k3, k4, k5, firstkill_t, firstkill_ct, firstdeath_t, firstdeath_ct);
      db.Query(SQLErrorCheckCallback, queryBuffer);

    } while (g_StatsKv.GotoNextKey());
    g_StatsKv.GoBack();
  }
}

//================================= Database Callback
public void SQLConnectCallback(Database database, const char[] error, any data){
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
  }
}

public int SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, int data) {
  if (!StrEqual("", error)) {
    LogMessage("Last Connect SQL Error: %s", error);
  }
}

public void MatchInitSuccess(Database database, any data, int numQueries, DBResultSet[] results, any[] queryData) {
  DBResultSet matchidResult = results[1];
  if (matchidResult.FetchRow()) {
    g_MatchID = matchidResult.FetchInt(0);
  } else {
    LogError("Failed to get matchid from match init query");
  }
}

public void MatchInitFailure(Database database, any data, int numQueries, const char[] error,
                      int failIndex, any[] queryData) {
  LogError("Failed match creation query, error = %s", error);
}

//================================= KV Changer
static int GetPlayerStat(int client, const char[] field) {
  GoToPlayer(client);
  int value = g_StatsKv.GetNum(field);
  GoBackFromPlayer();
  return value;
}

static int SetPlayerStat(int client, const char[] field, int newValue) {
  GoToPlayer(client);
  g_StatsKv.SetNum(field, newValue);
  GoBackFromPlayer();
  return newValue;
}

public int AddToPlayerStat(int client, const char[] field, int delta) {
  int value = GetPlayerStat(client, field);
  return SetPlayerStat(client, field, value + delta);
}

static int IncrementPlayerStat(int client, const char[] field) {
  // LogDebug("Incrementing player stat %s for %L", field, client);
  return AddToPlayerStat(client, field, 1);
}

static int GetClutchingClient(int csTeam) {
  int client = -1;
  int count = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == csTeam) {
      client = i;
      count++;
    }
  }

  if (count == 1) {
    return client;
  } else {
    return -1;
  }
}

//================================= Utils
stock int MatchTeamToCSTeam(MatchTeam t) {
  if (t == MatchTeam_Team1) {
    return g_TeamSide[MatchTeam_Team1];
  } else if (t == MatchTeam_Team2) {
    return g_TeamSide[MatchTeam_Team2];
  } else if (t == MatchTeam_TeamSpec) {
    return CS_TEAM_SPECTATOR;
  } else {
    return CS_TEAM_NONE;
  }
}

stock MatchTeam CSTeamToMatchTeam(int csTeam) {
  if (csTeam == g_TeamSide[MatchTeam_Team1]) {
    return MatchTeam_Team1;
  } else if (csTeam == g_TeamSide[MatchTeam_Team2]) {
    return MatchTeam_Team2;
  } else if (csTeam == CS_TEAM_SPECTATOR) {
    return MatchTeam_TeamSpec;
  } else {
    return MatchTeam_TeamNone;
  }
}

public MatchTeam GetClientMatchTeam(int client) {
  return CSTeamToMatchTeam(GetClientTeam(client));
}

public void SetStartingTeams() {
  g_TeamSide[MatchTeam_Team1] = CS_TEAM_T;
  g_TeamSide[MatchTeam_Team2] = CS_TEAM_CT;
}

stock bool HelpfulAttack(int attacker, int victim) {
  if (!IsValidClient(attacker) || !IsValidClient(victim)) {
    return false;
  }
  int attackerTeam = GetClientTeam(attacker);
  int victimTeam = GetClientTeam(victim);
  return attackerTeam != victimTeam && attacker != victim;
}

stock bool GetAuth(int client, char[] auth, int size) {
  if (client == 0)
    return false;

  bool ret = GetClientAuthId(client, AuthId_SteamID64, auth, size);
  if (!ret) {
    LogError("Failed to get steamid for client %L", client);
  }
  return ret;
}


//================================= Event Hook
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int csTeamWinner = event.GetInt("winner");
  // Update team scores.
  GoToMap();
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  g_StatsKv.SetString(STAT_MAPNAME, mapName);
  GoBackFromMap();

  GoToTeam(MatchTeam_Team1);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  GoBackFromTeam();

  GoToTeam(MatchTeam_Team2);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  GoBackFromTeam();

  // Update player 1vx and x-kill values.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        switch (g_RoundKills[i]) {
          case 1:
            IncrementPlayerStat(i, STAT_1K);
          case 2:
            IncrementPlayerStat(i, STAT_2K);
          case 3:
            IncrementPlayerStat(i, STAT_3K);
          case 4:
            IncrementPlayerStat(i, STAT_4K);
          case 5:
            IncrementPlayerStat(i, STAT_5K);
        }

        if (GetClientTeam(i) == csTeamWinner) {
          switch (g_RoundClutchingEnemyCount[i]) {
            case 1:
              IncrementPlayerStat(i, STAT_V1);
            case 2:
              IncrementPlayerStat(i, STAT_V2);
            case 3:
              IncrementPlayerStat(i, STAT_V3);
            case 4:
              IncrementPlayerStat(i, STAT_V4);
            case 5:
              IncrementPlayerStat(i, STAT_V5);
          }
        }

        GoToPlayer(i);
        char clientName[MAX_NAME_LENGTH];
        GetClientName(i, clientName, sizeof(clientName));
        char escapeName[MAX_NAME_LENGTH * 2 + 1];
        db.Escape(clientName, escapeName, sizeof(escapeName));
        g_StatsKv.SetString(STAT_NAME, escapeName);
        GoBackFromPlayer();
      }
    }
  }

  UpdateRoundStats();

  return Plugin_Continue;
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  g_SetTeamClutching[CS_TEAM_CT] = false;
  g_SetTeamClutching[CS_TEAM_T] = false;
  g_TeamFirstKillDone[CS_TEAM_CT] = false;
  g_TeamFirstKillDone[CS_TEAM_T] = false;
  g_TeamFirstDeathDone[CS_TEAM_CT] = false;
  g_TeamFirstDeathDone[CS_TEAM_T] = false;

  for (int i = 1; i <= MaxClients; i++) {
    Stats_ResetClientRoundValues(i);
  }

  if (CS_GetTeamScore(CS_TEAM_CT) + CS_GetTeamScore(CS_TEAM_T) == 15){
    int tmp = g_TeamSide[MatchTeam_Team1];
    g_TeamSide[MatchTeam_Team1] = g_TeamSide[MatchTeam_Team2];
    g_TeamSide[MatchTeam_Team2] = tmp;
  }

  return Plugin_Continue;
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }
  
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        IncrementPlayerStat(i, STAT_ROUNDSPLAYED);

        GoToPlayer(i);
        char clientName[MAX_NAME_LENGTH];
        GetClientName(i, clientName, sizeof(clientName));
        char escapeName[MAX_NAME_LENGTH * 2 + 1];
        db.Escape(clientName, escapeName, sizeof(escapeName));
        g_StatsKv.SetString(STAT_NAME, escapeName);
        GoBackFromPlayer();
      }
    }
  }
  
  return Plugin_Continue;
}

public Action Event_PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int assister = GetClientOfUserId(event.GetInt("assister"));
  bool headshot = event.GetBool("headshot");

  char weapon[32];
  event.GetString("weapon", weapon, sizeof(weapon));

  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);

  if (validVictim) {
    IncrementPlayerStat(victim, STAT_DEATHS);

    int victim_team = GetClientTeam(victim);
    if (!g_TeamFirstDeathDone[victim_team]) {
      g_TeamFirstDeathDone[victim_team] = true;
      IncrementPlayerStat(victim,
                          (victim_team == CS_TEAM_CT) ? STAT_FIRSTDEATH_CT : STAT_FIRSTDEATH_T);
    }
  }

  if (validAttacker) {
    int attacker_team = GetClientTeam(attacker);
    if (!g_TeamFirstKillDone[attacker_team]) {
      g_TeamFirstKillDone[attacker_team] = true;
      IncrementPlayerStat(attacker,
                          (attacker_team == CS_TEAM_CT) ? STAT_FIRSTKILL_CT : STAT_FIRSTKILL_T);
    }

    if (HelpfulAttack(attacker, victim)) {
      g_RoundKills[attacker]++;

      g_PlayerKilledBy[victim] = attacker;
      g_PlayerKilledByTime[victim] = GetGameTime();
      // UpdateTradeStat(attacker, victim);

      IncrementPlayerStat(attacker, STAT_KILLS);
      if (headshot)
        IncrementPlayerStat(attacker, STAT_HEADSHOT_KILLS);
      if (IsValidClient(assister))
        IncrementPlayerStat(assister, STAT_ASSISTS);

      int flasher = g_RoundFlashedBy[victim];
      if (IsValidClient(flasher) && flasher != attacker)
        IncrementPlayerStat(flasher, STAT_FLASHBANG_ASSISTS);
      else
        flasher = 0;

      // EventLogger_PlayerDeath(attacker, victim, headshot, assister, flasher, weapon);

    } else {
      if (attacker == victim)
        IncrementPlayerStat(attacker, STAT_SUICIDES);
      else
        IncrementPlayerStat(attacker, STAT_TEAMKILLS);
    }
  }

  // Update "clutch" (1vx) data structures to check if the clutcher wins the round
  int tCount = CountAlivePlayersOnTeam(CS_TEAM_T);
  int ctCount = CountAlivePlayersOnTeam(CS_TEAM_CT);

  if (tCount == 1 && !g_SetTeamClutching[CS_TEAM_T]) {
    g_SetTeamClutching[CS_TEAM_T] = true;
    int clutcher = GetClutchingClient(CS_TEAM_T);
    g_RoundClutchingEnemyCount[clutcher] = ctCount;
  }

  if (ctCount == 1 && !g_SetTeamClutching[CS_TEAM_CT]) {
    g_SetTeamClutching[CS_TEAM_CT] = true;
    int clutcher = GetClutchingClient(CS_TEAM_CT);
    g_RoundClutchingEnemyCount[clutcher] = tCount;
  }

  return Plugin_Continue;
}

public Action Event_DamageDealtEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);

  if (validAttacker && validVictim) {
    int preDamageHealth = GetClientHealth(victim);
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");

    // this maxes the damage variables at 100,
    // so doing 50 damage when the player had 2 health
    // only counts as 2 damage.
    if (postDamageHealth == 0) {
      damage += preDamageHealth;
    }

    g_DamageDone[attacker][victim] += damage;
    g_DamageDoneHits[attacker][victim]++;
    AddToPlayerStat(attacker, STAT_DAMAGE, damage);
  }

  return Plugin_Continue;
}

public Action Event_BombPlantedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBPLANTS);
  }

  return Plugin_Continue;
}

public Action Event_BombDefusedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBDEFUSES);
  }

  return Plugin_Continue;
}

public Action Event_FlashbangDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);

  if (IsValidClient(client)) {
    g_LastFlashBangThrower = client;
  }

  return Plugin_Continue;
}

public Action Event_PlayerBlindEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive()) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  RequestFrame(GetFlashInfo, GetClientSerial(client));

  return Plugin_Continue;
}

public void GetFlashInfo(int serial) {
  int client = GetClientFromSerial(serial);
  if (IsValidClient(client)) {
    float flashDuration =
        GetEntDataFloat(client, FindSendPropInfo("CCSPlayer", "m_flFlashDuration"));
    if (flashDuration >= 2.5) {
      g_RoundFlashedBy[client] = g_LastFlashBangThrower;
    }
    CreateTimer(flashDuration, Timer_ResetFlashStatus, serial);
  }
}

public Action Timer_ResetFlashStatus(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsValidClient(client)) {
    g_RoundFlashedBy[client] = -1;
  }
}

//================================= KV Jumper
static void GoToMap() {
  g_StatsKv.JumpToKey("map", true);
}

static void GoBackFromMap() {
  g_StatsKv.GoBack();
}

static void GoToTeam(MatchTeam team) {
  GoToMap();

  if (team == MatchTeam_Team1)
    g_StatsKv.JumpToKey("team1", true);
  else
    g_StatsKv.JumpToKey("team2", true);
}

static void GoBackFromTeam() {
  GoBackFromMap();
  g_StatsKv.GoBack();
}

static void GoToPlayer(int client) {
  MatchTeam team = GetClientMatchTeam(client);
  GoToTeam(team);

  char auth[AUTH_LENGTH];
  if (GetAuth(client, auth, sizeof(auth))) {
    g_StatsKv.JumpToKey(auth, true);
  }
}

static void GoBackFromPlayer() {
  GoBackFromTeam();
  g_StatsKv.GoBack();
}