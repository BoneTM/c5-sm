

public void Stats_PluginStart() {
  HookEvent("player_death", Stats_PlayerDeathEvent);
  HookEvent("player_hurt", Stats_DamageDealtEvent, EventHookMode_Pre);
  HookEvent("bomb_planted", Stats_BombPlantedEvent);
  HookEvent("bomb_defused", Stats_BombDefusedEvent);
  HookEvent("flashbang_detonate", Stats_FlashbangDetonateEvent, EventHookMode_Pre);
  HookEvent("player_blind", Stats_PlayerBlindEvent);
}

public void Stats_Reset(){
  if (g_StatsKv != null) {
    delete g_StatsKv;
  }
  g_StatsKv = new KeyValues("Stats");
}

public void Stats_Init() {
  Stats_Reset();
  
  g_StatsKv.SetString(STAT_SERIES_TEAM1NAME, "TeamA");
  g_StatsKv.SetString(STAT_SERIES_TEAM2NAME, "TeamB");
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

public MatchTeam GetClientMatchTeam(int client) {
  return CSTeamToMatchTeam(GetClientTeam(client));
}

//================================= Event Hook
public Action Stats_RoundEnd(int csTeamWinner) {
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
        g_StatsKv.SetString(STAT_NAME, clientName);
        GoBackFromPlayer();
      }
    }
  }

  return Plugin_Continue;
}

public void Stats_ResetRoundValues() {
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
}

public void Stats_RoundStart() {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        IncrementPlayerStat(i, STAT_ROUNDSPLAYED);

        GoToPlayer(i);
        char clientName[MAX_NAME_LENGTH];
        GetClientName(i, clientName, sizeof(clientName));
        g_StatsKv.SetString(STAT_NAME, clientName);
        GoBackFromPlayer();
      }
    }
  }
}

public Action Stats_PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsMatchLive()) {
    return Plugin_Continue;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int assister = GetClientOfUserId(event.GetInt("assister"));
  bool headshot = event.GetBool("headshot");

  char weapon[32];
  event.GetString("weapon", weapon, sizeof(weapon));

  bool validAttacker = IsPlayer(attacker);
  bool validVictim = IsPlayer(victim);

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
      if (IsPlayer(assister))
        IncrementPlayerStat(assister, STAT_ASSISTS);

      int flasher = g_RoundFlashedBy[victim];
      if (IsPlayer(flasher) && flasher != attacker)
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

public Action Stats_DamageDealtEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsMatchLive()) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  bool validAttacker = IsPlayer(attacker);
  bool validVictim = IsPlayer(victim);

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

public Action Stats_BombPlantedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsMatchLive()) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client)) {
    IncrementPlayerStat(client, STAT_BOMBPLANTS);
  }

  return Plugin_Continue;
}

public Action Stats_BombDefusedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsMatchLive()) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client)) {
    IncrementPlayerStat(client, STAT_BOMBDEFUSES);
  }

  return Plugin_Continue;
}

public Action Stats_FlashbangDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsMatchLive()) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);

  if (IsPlayer(client)) {
    g_LastFlashBangThrower = client;
  }

  return Plugin_Continue;
}

public Action Stats_PlayerBlindEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!Pugsetup_IsMatchLive()) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  RequestFrame(GetFlashInfo, GetClientSerial(client));

  return Plugin_Continue;
}

public void GetFlashInfo(int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
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
  if (IsPlayer(client)) {
    g_RoundFlashedBy[client] = -1;
  }
}

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