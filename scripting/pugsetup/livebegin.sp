public Action BeginLive(Handle timer) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  ChangeState(GameState_GoingLive);

  // force kill the warmup if we need to
  if (InWarmup()) {
    EndWarmup();
  }

  // reset player tags
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClanTag(i, true);  // force strip them
    }
  }

  SetConVarInt(FindConVar("sv_cheats"), 0);
  Call_StartForward(g_hOnGoingLive);
  Call_Finish();

  Stats_Reset();
  g_TeamSide[MatchTeam_Team1] = CS_TEAM_T;
  g_TeamSide[MatchTeam_Team2] = CS_TEAM_CT;

  RestartGame(3);
  CreateTimer(3.1, MatchLive);

  return Plugin_Handled;
}

public Action MatchLive(Handle timer) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  ChangeState(GameState_Live);
  Call_StartForward(g_hOnLive);
  Call_Finish();

  // Restore client clan tags since we're live.
  char auth[64];
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      RestoreClanTag(i);
      GetAuth(i, auth, sizeof(auth));
      g_PlayerAtStart.Clear();
      g_PlayerAtStart.Push(auth);
    }
  }

  for (int i = 0; i < 5; i++) {
    MessageToAll("%t", "Live");
  }

  return Plugin_Handled;
}
