#define CHECK_CLIENT(%1)  \
  if (!IsValidClient(%1)) \
  ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", %1)
#define CHECK_CAPTAIN(%1)  \
  if (%1 != 1 && %1 != 2) \
  ThrowNativeError(SP_ERROR_PARAM, "Captain number %d is not valid", %1)

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

  g_MapList = new ArrayList(PLATFORM_MAX_PATH);

  CreateNative("Pugsetup_SetupGame", Native_SetupGame);
  CreateNative("Pugsetup_SetSetupOptions", Native_SetSetupOptions);
  CreateNative("Pugsetup_GetSetupOptions", Native_GetSetupOptions);
  CreateNative("Pugsetup_ReadyPlayer", Native_ReadyPlayer);
  CreateNative("Pugsetup_UnreadyPlayer", Native_UnreadyPlayer);
  CreateNative("Pugsetup_IsReady", Native_IsReady);
  CreateNative("Pugsetup_IsSetup", Native_IsSetup);
  CreateNative("Pugsetup_GetTeamType", Native_GetTeamType);
  CreateNative("Pugsetup_GetMapType", Native_GetMapType);
  CreateNative("Pugsetup_GetGameState", Native_GetGameState);
  CreateNative("Pugsetup_IsMatchLive", Native_IsMatchLive);
  CreateNative("Pugsetup_IsPendingStart", Native_IsPendingStart);
  CreateNative("Pugsetup_IsWarmup", Native_IsWarmup);
  CreateNative("Pugsetup_GetCaptain", Native_GetCaptain);
  CreateNative("Pugsetup_SetCaptain", Native_SetCaptain);
  CreateNative("Pugsetup_GetPugMaxPlayers", Native_GetPugMaxPlayers);
  CreateNative("Pugsetup_PlayerAtStart", Native_PlayerAtStart);
  CreateNative("Pugsetup_IsPugAdmin", Native_IsPugAdmin);
  CreateNative("Pugsetup_SetRandomCaptains", Native_SetRandomCaptains);
  CreateNative("Pugsetup_GiveSetupMenu", Native_GiveSetupMenu);
  CreateNative("Pugsetup_GiveMapChangeMenu", Native_GiveMapChangeMenu);
  CreateNative("Pugsetup_IsTeamBalancerAvaliable", Native_IsTeamBalancerAvaliable);
  CreateNative("Pugsetup_SetTeamBalancer", Native_SetTeamBalancer);
  CreateNative("Pugsetup_ClearTeamBalancer", Native_ClearTeamBalancer);
  CreateNative("Pugsetup_IsDecidedMap", Native_IsDecidedMap);
  CreateNative("Pugsetup_IsClientInAuths", Native_IsClientInAuths);
  CreateNative("Pugsetup_ClearAuths", Native_ClearAuths);
  CreateNative("Pugsetup_GetMatchStats", Native_GetMatchStats);
  CreateNative("Pugsetup_MatchTeamToCSTeam", Native_MatchTeamToCSTeam);
  RegPluginLibrary("pugsetup");
  return APLRes_Success;
}

public int Native_SetupGame(Handle plugin, int numParams) {
  g_TeamType = view_as<TeamType>(GetNativeCell(1));
  g_MapType = view_as<MapType>(GetNativeCell(2));
  g_PlayersPerTeam = GetNativeCell(3);

  // optional parameters added, checking is they were
  // passed for backwards compatibility
  if (numParams >= 4) {
    g_RecordGameOption = GetNativeCell(4);
  }

  if (numParams >= 5) {
    g_DoKnifeRound = GetNativeCell(5);
  }

  SetupFinished();
}

public int Native_GetSetupOptions(Handle plugin, int numParams) {
  if (!Pugsetup_IsSetup()) {
    ThrowNativeError(SP_ERROR_ABORTED, "Cannot get setup options when a match is not setup.");
  }

  SetNativeCellRef(1, g_TeamType);
  SetNativeCellRef(2, g_MapType);
  SetNativeCellRef(3, g_PlayersPerTeam);
  SetNativeCellRef(4, g_RecordGameOption);
  SetNativeCellRef(5, g_DoKnifeRound);
}

public int Native_SetSetupOptions(Handle plugin, int numParams) {
  g_TeamType = view_as<TeamType>(GetNativeCell(1));
  g_MapType = view_as<MapType>(GetNativeCell(2));
  g_PlayersPerTeam = GetNativeCell(3);
  g_RecordGameOption = GetNativeCell(4);
  g_DoKnifeRound = GetNativeCell(5);
}

public int Native_ReadyPlayer(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  bool replyMessages = true;
  // Backwards compatability check.
  if (numParams >= 2) {
    replyMessages = GetNativeCell(2);
  }

  if (g_GameState != GameState_Warmup || !IsPlayer(client))
    return false;

  if (GetClientTeam(client) == CS_TEAM_SPECTATOR) {
    if (replyMessages)
      Message(client, "%t", "SpecCantReady");
    return false;
  }

  // already ready
  if (g_Ready[client]) {
    return false;
  }

  Call_StartForward(g_hOnReady);
  Call_PushCell(client);
  Call_Finish();

  g_Ready[client] = true;
  UpdateClanTag(client);

  if (g_EchoReadyMessagesCvar.IntValue != 0 && replyMessages) {
    MessageToAll("%t", "IsNowReady", client);
  }

  return true;
}

public int Native_UnreadyPlayer(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  if (g_GameState != GameState_Warmup || !IsPlayer(client))
    return false;

  // already un-ready
  if (!g_Ready[client]) {
    return false;
  }

  Call_StartForward(g_hOnUnready);
  Call_PushCell(client);
  Call_Finish();

  g_Ready[client] = false;
  UpdateClanTag(client);

  if (g_EchoReadyMessagesCvar.IntValue != 0) {
    MessageToAll("%t", "IsNoLongerReady", client);
  }

  return true;
}

public int Native_IsReady(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);
  if (!IsClientInGame(client) || IsFakeClient(client))
    return false;

  return g_Ready[client] && OnActiveTeam(client);
}

public int Native_IsSetup(Handle plugin, int numParams) {
  return g_GameState >= GameState_Warmup;
}

public int Native_GetMapType(Handle plugin, int numParams) {
  return view_as<int>(g_MapType);
}

public int Native_GetTeamType(Handle plugin, int numParams) {
  return view_as<int>(g_TeamType);
}

public int Native_GetGameState(Handle plugin, int numParams) {
  return view_as<int>(g_GameState);
}

public int Native_IsMatchLive(Handle plugin, int numParams) {
  return g_GameState == GameState_Live;
}

public int Native_IsPendingStart(Handle plugin, int numParams) {
  return g_GameState >= GameState_PickingPlayers && g_GameState <= GameState_GoingLive;
}

public int Native_IsWarmup(Handle plugin, int numParams) {
  return g_GameState == GameState_Warmup;
}

public int Native_SetCaptain(Handle plugin, int numParams) {
  int captainNumber = GetNativeCell(1);
  CHECK_CAPTAIN(captainNumber);

  int client = GetNativeCell(2);
  CHECK_CLIENT(client);

  bool printIfSame = false;
  // backwards compatability
  if (numParams >= 3) {
    printIfSame = GetNativeCell(3);
  }

  if (IsPlayer(client)) {
    int originalCaptain = -1;
    if (captainNumber == 1) {
      originalCaptain = g_capt1;
      g_capt1 = client;
    } else {
      originalCaptain = g_capt2;
      g_capt2 = client;
    }

    // Only printout if it's a different captain
    if (printIfSame || client != originalCaptain) {
      char buffer[64];
      FormatPlayerName(client, client, buffer);
      MessageToAll("%t", "CaptMessage", captainNumber, buffer);
    }
  }
}

public int Native_GetCaptain(Handle plugin, int numParams) {
  int captainNumber = GetNativeCell(1);
  CHECK_CAPTAIN(captainNumber);

  int capt = (captainNumber == 1) ? g_capt1 : g_capt2;

  if (IsValidClient(capt) && !IsFakeClient(capt))
    return capt;
  else
    return -1;
}

public int Native_GetPugMaxPlayers(Handle plugin, int numParams) {
  return 2 * g_PlayersPerTeam;
}

public int Native_PlayerAtStart(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  
  if (!IsPlayer(client)) return false;

  char auth[64];
  GetAuth(client, auth, sizeof(auth));

  return g_PlayerAtStart.FindString(auth) != -1;
}

public int Native_IsPugAdmin(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  AdminId admin = GetUserAdmin(client);
  if (admin != INVALID_ADMIN_ID) {
    char flags[8];
    AdminFlag flag;
    g_AdminFlagCvar.GetString(flags, sizeof(flags));
    if (!FindFlagByChar(flags[0], flag)) {
      LogError("Invalid immunity flag: %s", flags[0]);
      return false;
    } else {
      return GetAdminFlag(admin, flag);
    }
  }

  return false;
}

public int Native_SetRandomCaptains(Handle plugin, int numParams) {
  int c1 = -1;
  int c2 = -1;

  c1 = RandomPlayer();
  while (!IsPlayer(c2) || c1 == c2) {
    if (GetRealClientCount() < 2)
      break;

    c2 = RandomPlayer();
  }

  if (IsPlayer(c1))
    Pugsetup_SetCaptain(1, c1, true);

  if (IsPlayer(c2))
    Pugsetup_SetCaptain(2, c2, true);
}

public int Native_GiveSetupMenu(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);
  bool displayOnly = GetNativeCell(2);

  // backwards compatability
  int menuPosition = -1;
  if (numParams >= 3) {
    menuPosition = GetNativeCell(3);
  }

  SetupMenu(client, displayOnly, menuPosition);
}

public int Native_GiveMapChangeMenu(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);
  ChangeMapMenu(client);
}

public int Native_IsTeamBalancerAvaliable(Handle plugin, int numParams) {
  return g_BalancerFunction != INVALID_FUNCTION &&
         GetPluginStatus(g_BalancerFunctionPlugin) == Plugin_Running;
}

public int Native_SetTeamBalancer(Handle plugin, int numParams) {
  bool override = GetNativeCell(2);
  if (!Pugsetup_IsTeamBalancerAvaliable() || override) {
    g_BalancerFunctionPlugin = plugin;
    g_BalancerFunction = view_as<TeamBalancerFunction>(GetNativeFunction(1));
    return true;
  }
  return false;
}

public int Native_ClearTeamBalancer(Handle plugin, int numParams) {
  bool hadBalancer = Pugsetup_IsTeamBalancerAvaliable();
  g_BalancerFunction = INVALID_FUNCTION;
  g_BalancerFunctionPlugin = INVALID_HANDLE;
  return hadBalancer;
}

public int Native_IsDecidedMap(Handle plugin, int numParams) {
  return g_OnDecidedMap;
}

public int Native_IsClientInAuths(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  char auth[64];
  GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

  return g_auths.FindString(auth) != -1;
}

public int Native_ClearAuths(Handle plugin, int numParams) {
  g_auths.Clear();
}

public int Native_GetMatchStats(Handle plugin, int numParams) {
  Handle output = GetNativeCell(1);
  if (output == INVALID_HANDLE) {
    return view_as<int>(false);
  } else {
    KvCopySubkeys(g_StatsKv, output);
    g_StatsKv.Rewind();
    return view_as<int>(true);
  }
}

public int Native_MatchTeamToCSTeam(Handle plugin, int numParams) {
  return MatchTeamToCSTeam(GetNativeCell(1));
}
