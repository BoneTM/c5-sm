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
    name = "PugSetup: Stats Mysql",
    author = "Bone",
    description = "",
    version = "beta",
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {

  if(db == null)
  {
    Database.Connect(SQLConnectCallback, "storage-local");
  }
}

public void Pugsetup_OnMatchOver(bool hasDemo, const char[] demoFileName){
  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `stats_matches` \
        SET end_time = NOW() WHERE match_id = %d", g_MatchID);
  if (!SQL_FastQuery(db, queryBuffer))
  {
    LogError("Pugsetup Stats fail to update match in the end.");
  }
}

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

public void Pugsetup_OnRoundStatsUpdated() {
  UpdateRoundStats();
}

public void Pugsetup_OnLive()
{
  Transaction t = SQL_CreateTransaction();

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  int serverId = GetCvarIntSafe("sb_server_id");
  if (serverId <= 0) serverId = 0;
  Format(queryBuffer, sizeof(queryBuffer), "INSERT INTO `stats_matches` (start_time, map, sid) VALUES (NOW(), '%s', %d)", mapName, serverId);
  t.AddQuery(queryBuffer);

  Format(queryBuffer, sizeof(queryBuffer), "SELECT LAST_INSERT_ID()");
  t.AddQuery(queryBuffer);

  db.Execute(t, MatchInitSuccess, MatchInitFailure);
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


public void UpdateRoundStats() {
  // Update team scores
  int t1score = CS_GetTeamScore(Pugsetup_MatchTeamToCSTeam(MatchTeam_Team1));
  int t2score = CS_GetTeamScore(Pugsetup_MatchTeamToCSTeam(MatchTeam_Team2));

  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `stats_matches` \
        SET team1_score = %d, team2_score = %d WHERE match_id = %d",
         t1score, t2score, g_MatchID);
  // LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);

  KeyValues kv = new KeyValues("Stats");
  Pugsetup_GetMatchStats(kv);
  // Update player stats
  if (kv.JumpToKey("map")) {
    if (kv.JumpToKey("team1")) {
      AddPlayerStats(kv, MatchTeam_Team1);
      kv.GoBack();
    }
    if (kv.JumpToKey("team2")) {
      AddPlayerStats(kv, MatchTeam_Team2);
      kv.GoBack();
    }
    kv.GoBack();
  }
  delete kv;
}

public void AddPlayerStats(KeyValues kv, MatchTeam team) {
  char name[MAX_NAME_LENGTH];
  char auth[AUTH_LENGTH];
  char nameSz[MAX_NAME_LENGTH * 2 + 1];
  char authSz[AUTH_LENGTH * 2 + 1];

  if (kv.GotoFirstSubKey()) {
    do {
      kv.GetSectionName(auth, sizeof(auth));
      kv.GetString("name", name, sizeof(name));
      db.Escape(auth, authSz, sizeof(authSz));
      db.Escape(name, nameSz, sizeof(nameSz));

      int kills = kv.GetNum(STAT_KILLS);
      int deaths = kv.GetNum(STAT_DEATHS);
      int flashbang_assists = kv.GetNum(STAT_FLASHBANG_ASSISTS);
      int assists = kv.GetNum(STAT_ASSISTS);
      int teamkills = kv.GetNum(STAT_TEAMKILLS);
      int damage = kv.GetNum(STAT_DAMAGE);
      int headshot_kills = kv.GetNum(STAT_HEADSHOT_KILLS);
      int roundsplayed = kv.GetNum(STAT_ROUNDSPLAYED);
      int plants = kv.GetNum(STAT_BOMBPLANTS);
      int defuses = kv.GetNum(STAT_BOMBDEFUSES);
      int v1 = kv.GetNum(STAT_V1);
      int v2 = kv.GetNum(STAT_V2);
      int v3 = kv.GetNum(STAT_V3);
      int v4 = kv.GetNum(STAT_V4);
      int v5 = kv.GetNum(STAT_V5);
      int k2 = kv.GetNum(STAT_2K);
      int k3 = kv.GetNum(STAT_3K);
      int k4 = kv.GetNum(STAT_4K);
      int k5 = kv.GetNum(STAT_5K);
      int firstkill_t = kv.GetNum(STAT_FIRSTKILL_T);
      int firstkill_ct = kv.GetNum(STAT_FIRSTKILL_CT);
      int firstdeath_t = kv.GetNum(STAT_FIRSTDEATH_T);
      int firstdeath_ct = kv.GetNum(STAT_FIRSTDEATH_CT);

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

    } while (kv.GotoNextKey());
    kv.GoBack();
  }
}