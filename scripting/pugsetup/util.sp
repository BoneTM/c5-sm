
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