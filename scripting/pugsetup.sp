#include <clientprefs>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <sourcemod>

#include "include/message.inc"
#include "include/pugsetup.inc"
#include "include/restorecvars.inc"
#include "c5/util.sp"

#define ALIAS_LENGTH 64
#define LIVE_TIMER_INTERVAL 0.3

#pragma semicolon 1
#pragma newdecls required


/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/


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
int g_TeamSide[4];            // Current CS_TEAM_* side for the team.

#include "pugsetup/util.sp"

/** ConVar handles **/
ConVar g_AdminFlagCvar;
ConVar g_AnnounceCountdownCvar;
ConVar g_AutoSetupCvar;
ConVar g_DemoNameFormatCvar;
ConVar g_DemoTimeFormatCvar;
ConVar g_EchoReadyMessagesCvar;
ConVar g_ExcludedMaps;
ConVar g_ForceDefaultsCvar;
ConVar g_LiveCfgCvar;
ConVar g_MapVoteTimeCvar;
ConVar g_PauseCountLimitCvar;
ConVar g_PauseTimeCvar;
ConVar g_PausingEnabledCvar;
ConVar g_PostGameCfgCvar;
ConVar g_RandomizeMapOrderCvar;
ConVar g_RandomOptionInMapVoteCvar;
ConVar g_SetupEnabledCvar;
ConVar g_SnakeCaptainsCvar;
ConVar g_StartDelayCvar;
ConVar g_WarmupCfgCvar;
ConVar g_WarmupMoneyOnSpawnCvar;

/** Setup menu options **/
bool g_DisplayMapType = true;
bool g_DisplayTeamType = true;
bool g_DisplayKnifeRound = true;
bool g_DisplayTeamSize = true;
bool g_DisplayRecordDemo = true;
bool g_DisplayMapChange = false;

/** Setup info **/
ArrayList g_MapList;
ArrayList g_PastMaps;
bool g_ForceEnded = false;

/** Specific choices made when setting up **/
int g_PlayersPerTeam = 5;
TeamType g_TeamType = TeamType_Captains;
MapType g_MapType = MapType_Vote;
bool g_RecordGameOption = false;
bool g_DoKnifeRound = false;

/** Other important variables about the state of the game **/
TeamBalancerFunction g_BalancerFunction = INVALID_FUNCTION;
Handle g_BalancerFunctionPlugin = INVALID_HANDLE;

GameState g_GameState = GameState_None;
bool g_SwitchingMaps = false;  // if we're in the middle of a map change
bool g_OnDecidedMap = false;   // whether we're on the map that is going to be used

bool g_Recording = true;
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_LiveTimerRunning = false;
int g_CountDownTicks = 0;
bool g_ForceStartSignal = false;

#define CAPTAIN_COMMAND_HINT_TIME 15
#define START_COMMAND_HINT_TIME 15
#define READY_COMMAND_HINT_TIME 19
int g_LastCaptainHintTime = 0;
int g_LastReadyHintTime = 0;

/** Pause information **/
bool g_ctUnpaused = false;
bool g_tUnpaused = false;
int g_PauseCount[4];

/** Map-choosing variables **/
ArrayList g_MapVetoed;
ArrayList g_MapVotePool;

/** Data about team selections **/
int g_capt1 = -1;
int g_capt2 = -1;
int g_Teams[MAXPLAYERS + 1];
bool g_Ready[MAXPLAYERS + 1];
ArrayList g_PlayerAtStart;

/** Auth variables **/
ArrayList g_auths;

/** Clan tag data **/
#define CLANTAG_LENGTH 16
bool g_SavedClanTag[MAXPLAYERS + 1];
char g_ClanTag[MAXPLAYERS + 1][CLANTAG_LENGTH];

/** Knife round data **/
int g_KnifeWinner = -1;
enum KnifeDecision {
  KnifeDecision_None,
  KnifeDecision_Stay,
  KnifeDecision_Swap,
};
KnifeDecision g_KnifeRoundVotes[MAXPLAYERS + 1];
int g_KnifeNumVotesNeeded = 0;

/** Forwards **/
Handle g_OnForceEnd = INVALID_HANDLE;
Handle g_hOnGoingLive = INVALID_HANDLE;
Handle g_hOnKnifeRoundDecision = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hOnLiveCfg = INVALID_HANDLE;
Handle g_hOnLiveCheck = INVALID_HANDLE;
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnNotPicked = INVALID_HANDLE;
Handle g_hOnPlayerAddedToCaptainMenu = INVALID_HANDLE;
Handle g_hOnPostGameCfg = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnReadyToStart = INVALID_HANDLE;
Handle g_hOnSetup = INVALID_HANDLE;
Handle g_hOnSetupMenuOpen = INVALID_HANDLE;
Handle g_hOnSetupMenuSelect = INVALID_HANDLE;
Handle g_hOnStartRecording = INVALID_HANDLE;
Handle g_hOnStateChange = INVALID_HANDLE;
Handle g_hOnUnready = INVALID_HANDLE;
Handle g_hOnWarmupCfg = INVALID_HANDLE;
Handle g_OnRoundStatsUpdated = INVALID_HANDLE;
Handle g_OnDecidedMapChanging = INVALID_HANDLE;

#include "pugsetup/stats.sp"
#include "pugsetup/captainpickmenus.sp"
#include "pugsetup/configs.sp"
#include "pugsetup/kniferounds.sp"
#include "pugsetup/leadermenus.sp"
#include "pugsetup/livebegin.sp"
#include "pugsetup/maps.sp"
#include "pugsetup/mapveto.sp"
#include "pugsetup/mapvote.sp"
#include "pugsetup/friendlyfirevote.sp"
#include "pugsetup/overtime.sp"
#include "pugsetup/natives.sp"
#include "pugsetup/pause.sp"
#include "pugsetup/setupmenus.sp"

/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin myinfo = {
    name = "Pugsetup",
    author = "Bone, splewis",
    description = "Tools for setting up pugs",
    version = "1.0",
	  url = "https://bonetm.github.io/"
};

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");
  LoadTranslations("pugsetup.phrases");

  /** ConVars **/
  g_AdminFlagCvar = CreateConVar(
      "sm_pugsetup_admin_flag", "b",
      "Admin flag to mark players as having elevated permissions - e.g. can always pause,setup,end the game, etc.");
  g_AnnounceCountdownCvar =
      CreateConVar("sm_pugsetup_announce_countdown_timer", "1",
                   "Whether to announce how long the countdown has left before the lo3 begins.");
  g_AutoSetupCvar =
      CreateConVar("sm_pugsetup_autosetup", "1",
                   "Whether a pug is automatically setup using the default setup options or not.");
  g_DemoNameFormatCvar = CreateConVar(
      "sm_pugsetup_demo_name_format", "pugsetup_{TIME}_{MAP}",
      "Naming scheme for demos. You may use {MAP}, {TIME}, and {TEAMSIZE}. Make sure there are no spaces or colons in this.");
  g_DemoTimeFormatCvar = CreateConVar(
      "sm_pugsetup_time_format", "%Y-%m-%d_%H%M",
      "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
  g_EchoReadyMessagesCvar = CreateConVar("sm_pugsetup_echo_ready_messages", "1",
                                         "Whether to print to chat when clients ready/unready.");
  g_ExcludedMaps = CreateConVar(
      "sm_pugsetup_excluded_maps", "0",
      "Number of past maps to exclude from map votes. Setting this to 0 disables this feature.");
  g_ForceDefaultsCvar = CreateConVar(
      "sm_pugsetup_force_defaults", "0",
      "Whether the default setup options are forced as the setup options (note that admins can override them still).");
  g_LiveCfgCvar = CreateConVar("sm_pugsetup_live_cfg", "sourcemod/pugsetup/live.cfg",
                               "Config to execute when the game goes live");
  g_MapVoteTimeCvar =
      CreateConVar("sm_pugsetup_mapvote_time", "25",
                   "How long the map vote should last if using map-votes.", _, true, 10.0);
  g_PauseCountLimitCvar = CreateConVar(
      "sm_pugsetup_pause_count_limit", "2", "");
  g_PauseTimeCvar = CreateConVar(
      "sm_pugsetup_pause_time", "120", "");
  g_PausingEnabledCvar =
      CreateConVar("sm_pugsetup_pausing_enabled", "1", "Whether pausing is allowed.");
  g_PostGameCfgCvar =
      CreateConVar("sm_pugsetup_postgame_cfg", "sourcemod/pugsetup/warmup.cfg",
                   "Config to execute after games finish; should be in the csgo/cfg directory.");
  g_RandomizeMapOrderCvar =
      CreateConVar("sm_pugsetup_randomize_maps", "1",
                   "When maps are shown in the map vote/veto, whether their order is randomized.");
  g_RandomOptionInMapVoteCvar =
      CreateConVar("sm_pugsetup_random_map_vote_option", "1",
                   "Whether option 1 in a mapvote is the random map choice.");
  g_SetupEnabledCvar = CreateConVar("sm_pugsetup_setup_enabled", "1",
                                    "Whether the sm_setup commands are enabled");
  g_SnakeCaptainsCvar = CreateConVar(
      "sm_pugsetup_snake_captain_picks", "1",
      "If set to 0: captains pick players in a ABABABAB order. If set to 1, in a ABBAABBA order. If set to 2, in a ABBABABA order. If set to 3, in a ABBABAAB order.");
  g_StartDelayCvar =
      CreateConVar("sm_pugsetup_start_delay", "5",
                   "How many seconds of a countdown phase right before the lo3 process begins.", _,
                   true, 0.0, true, 60.0);
  g_WarmupCfgCvar =
      CreateConVar("sm_pugsetup_warmup_cfg", "sourcemod/pugsetup/warmup.cfg",
                   "Config file to run before/after games; should be in the csgo/cfg directory.");
  g_WarmupMoneyOnSpawnCvar = CreateConVar(
      "sm_pugsetup_money_on_warmup_spawn", "1",
      "Whether clients recieve 16,000 dollars when they spawn. It's recommended you use mp_death_drop_gun 0 in your warmup config if you use this.");

  /** Create and exec plugin's configuration file **/
  AutoExecConfig(true, "pugsetup", "sourcemod/pugsetup");

  /** Commands **/
  RegConsoleCmd("sm_r", Command_Ready, "Marks the client as ready");
  RegConsoleCmd("sm_unready", Command_NotReady, "Marks the client as not ready");
  RegConsoleCmd("sm_pause", Command_Pause, "Pauses the game");
  RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the game");
  RegConsoleCmd("sm_stay", Command_Stay, "Elects to stay on the current team after winning a knife round");
  RegConsoleCmd("sm_swap", Command_Swap, "Elects to swap the current teams after winning a knife round");
  RegConsoleCmd("sm_t", Command_T, "Elects to start on T side after winning a knife round");
  RegConsoleCmd("sm_ct", Command_Ct, "Elects to start on CT side after winning a knife round");
  RegAdminCmd("sm_setup", Command_Setup, ADMFLAG_GENERIC, "Starts pug setup (.ready, .capt commands become avaliable)");
  RegAdminCmd("sm_rand", Command_Rand, ADMFLAG_GENERIC, "Sets random captains");
  RegAdminCmd("sm_forceend", Command_ForceEnd, ADMFLAG_GENERIC, "Pre-emptively ends the match, without any confirmation menu");
  RegAdminCmd("sm_forceready", Command_ForceReady, ADMFLAG_GENERIC, "Force-readies a player");
  RegAdminCmd("sm_capt", Command_Capt, ADMFLAG_GENERIC, "Gives the client a menu to pick captains");
  RegAdminCmd("sm_forcestart", Command_ForceStart, ADMFLAG_GENERIC, "Force starts the game");

  /** Hooks **/
  HookEvent("cs_win_panel_match", Event_MatchOver);
  HookEvent("round_start", Event_RoundStart);
  HookEvent("round_freeze_end", Event_RoundFreezeEnd);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_connect", Event_PlayerConnect);
  HookEvent("player_disconnect", Event_PlayerDisconnect);
  HookEvent("round_prestart", Event_RoundPrestart);
  Stats_PluginStart();

  g_OnForceEnd = CreateGlobalForward("Pugsetup_OnForceEnd", ET_Ignore, Param_Cell);
  g_hOnGoingLive = CreateGlobalForward("Pugsetup_OnGoingLive", ET_Ignore);
  g_hOnKnifeRoundDecision =
      CreateGlobalForward("Pugsetup_OnKnifeRoundDecision", ET_Ignore, Param_Cell);
  g_hOnLive = CreateGlobalForward("Pugsetup_OnLive", ET_Ignore);
  g_hOnLiveCfg = CreateGlobalForward("Pugsetup_OnLiveCfgExecuted", ET_Ignore);
  g_hOnLiveCheck =
      CreateGlobalForward("Pugsetup_OnReadyToStartCheck", ET_Ignore, Param_Cell, Param_Cell);
  g_hOnMatchOver = CreateGlobalForward("Pugsetup_OnMatchOver", ET_Ignore, Param_Cell, Param_String);
  g_hOnNotPicked = CreateGlobalForward("Pugsetup_OnNotPicked", ET_Ignore, Param_Cell);
  g_hOnPlayerAddedToCaptainMenu =
      CreateGlobalForward("Pugsetup_OnPlayerAddedToCaptainMenu", ET_Ignore, Param_Cell, Param_Cell,
                          Param_String, Param_Cell);
  g_hOnPostGameCfg = CreateGlobalForward("Pugsetup_OnPostGameCfgExecuted", ET_Ignore);
  g_hOnReady = CreateGlobalForward("Pugsetup_OnReady", ET_Ignore, Param_Cell);
  g_hOnReadyToStart = CreateGlobalForward("Pugsetup_OnReadyToStart", ET_Ignore);
  g_hOnSetup = CreateGlobalForward("Pugsetup_OnSetup", ET_Ignore, Param_Cell, Param_Cell,
                                   Param_Cell, Param_Cell);
  g_hOnSetupMenuOpen =
      CreateGlobalForward("Pugsetup_OnSetupMenuOpen", ET_Event, Param_Cell, Param_Cell, Param_Cell);
  g_hOnSetupMenuSelect = CreateGlobalForward("Pugsetup_OnSetupMenuSelect", ET_Ignore, Param_Cell,
                                             Param_Cell, Param_String, Param_Cell);
  g_hOnStartRecording = CreateGlobalForward("Pugsetup_OnStartRecording", ET_Ignore, Param_String);
  g_hOnStateChange =
      CreateGlobalForward("Pugsetup_OnGameStateChanged", ET_Ignore, Param_Cell, Param_Cell);
  g_hOnUnready = CreateGlobalForward("Pugsetup_OnUnready", ET_Ignore, Param_Cell);
  g_hOnWarmupCfg = CreateGlobalForward("Pugsetup_OnWarmupCfgExecuted", ET_Ignore);
  g_OnRoundStatsUpdated = CreateGlobalForward("Pugsetup_OnRoundStatsUpdated", ET_Ignore);
  g_OnDecidedMapChanging = CreateGlobalForward("Pugsetup_OnDecidedMapChanging", ET_Ignore);

  g_LiveTimerRunning = false;
  ReadSetupOptions();

  g_MapVotePool = new ArrayList(PLATFORM_MAX_PATH);
  g_PastMaps = new ArrayList(PLATFORM_MAX_PATH);
  
  g_auths = new ArrayList(64);

  // hook for friendlyfire
  for (int i = 1; i <= MaxClients; i++)
  {
      HookOnTakeDamage(i);
  }

  g_PlayerAtStart = new ArrayList(64);
}

public void OnConfigsExecuted() {
  FillMapList("maps.txt", g_MapList);
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
  g_Ready[client] = false;
  g_SavedClanTag[client] = false;
  CheckAutoSetup();
  return true;
}

public void OnClientDisconnect_Post(int client) {
  int numPlayers = 0;
  for (int i = 1; i <= MaxClients; i++)
    if (IsPlayer(i))
      numPlayers++;

  if (numPlayers == 0 && !g_SwitchingMaps && g_AutoSetupCvar.IntValue == 0) {
    EndMatch(true);
  }
}

public void OnMapStart() {
  if (g_SwitchingMaps) {
    g_SwitchingMaps = false;
  }

  g_ForceEnded = false;
  g_MapVetoed = new ArrayList();
  g_Recording = false;
  g_LiveTimerRunning = false;
  g_ForceStartSignal = false;

  if (g_GameState == GameState_Warmup) {
    ExecWarmupConfigs();
    StartWarmup();
    StartLiveTimer();
  } else {
    g_capt1 = -1;
    g_capt2 = -1;
    for (int i = 1; i <= MaxClients; i++) {
      g_Ready[i] = false;
      g_Teams[i] = CS_TEAM_NONE;
    }
  }
}

public void OnMapEnd() {
  CloseHandle(g_MapVetoed);
}

public bool UsingCaptains() {
  return g_TeamType == TeamType_Captains || g_MapType == MapType_Veto;
}

public Action Timer_CheckReady(Handle timer) {
  if (g_GameState != GameState_Warmup || !g_LiveTimerRunning) {
    g_LiveTimerRunning = false;
    return Plugin_Stop;
  }

  int readyPlayers = 0;
  int totalPlayers = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClanTag(i);
      int team = GetClientTeam(i);
      if (team == CS_TEAM_CT || team == CS_TEAM_T) {
        totalPlayers++;
        if (g_Ready[i]) {
          readyPlayers++;
        }
      }
    }
  }

  if (totalPlayers >= Pugsetup_GetPugMaxPlayers()) {
    GiveReadyHints();
  }

  // beware: scary spaghetti code ahead
  if ((readyPlayers == totalPlayers && readyPlayers >= 2 * g_PlayersPerTeam) ||
      g_ForceStartSignal) {
    g_ForceStartSignal = false;

    if (g_OnDecidedMap) {
      if (g_TeamType == TeamType_Captains) {
        if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
          g_LiveTimerRunning = false;
          PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReadyPick");
          CreateTimer(1.0, StartPicking, _, TIMER_FLAG_NO_MAPCHANGE);
          return Plugin_Stop;
        } else {
          StatusHint(readyPlayers, totalPlayers);
        }
      } else {
        g_LiveTimerRunning = false;

        PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReady");

        ReadyToStart();
        return Plugin_Stop;
      }

    } else {
      if (g_MapType == MapType_Veto) {
        if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
          g_LiveTimerRunning = false;
          PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReadyVeto");
          MessageToAll("%t", "VetoMessage");
          CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
          return Plugin_Stop;
        } else {
          StatusHint(readyPlayers, totalPlayers);
        }

      } else {
        g_LiveTimerRunning = false;
        PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReadyVote");
        MessageToAll("%t", "VoteMessage");
        CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
      }
    }

  } else {
    StatusHint(readyPlayers, totalPlayers);
  }

  Call_StartForward(g_hOnLiveCheck);
  Call_PushCell(readyPlayers);
  Call_PushCell(totalPlayers);
  Call_Finish();

  if (g_TeamType == TeamType_Captains &&  totalPlayers >= Pugsetup_GetPugMaxPlayers()) {
    // re-randomize captains if they aren't set yet
    if (!IsPlayer(g_capt1)) {
      g_capt1 = RandomPlayer();
    }

    while (!IsPlayer(g_capt2) || g_capt1 == g_capt2) {
      if (GetRealClientCount() < 2)
        break;
      g_capt2 = RandomPlayer();
    }
  }

  return Plugin_Continue;
}

public void StatusHint(int readyPlayers, int totalPlayers) {
  char rdyCommand[ALIAS_LENGTH];
  GetInputFromCommand("sm_r", rdyCommand);
  bool captainsNeeded = (!g_OnDecidedMap && g_MapType == MapType_Veto) ||
                        (g_OnDecidedMap && g_TeamType == TeamType_Captains);

  if (captainsNeeded) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        GiveCaptainHint(i, readyPlayers, totalPlayers);
      }
    }
  } else {
    PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers, rdyCommand);
  }
}

static void GiveReadyHints() {
  int time = GetTime();
  int dt = time - g_LastReadyHintTime;

  if (dt >= READY_COMMAND_HINT_TIME) {
    g_LastReadyHintTime = time;
    char cmd[ALIAS_LENGTH];
    GetInputFromCommand("sm_ready", cmd);
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && !Pugsetup_IsReady(i) && OnActiveTeam(i)) {
        Message(i, "%t", "ReadyCommandHint", cmd);
      }
    }
  }
}

static void GiveCaptainHint(int client, int readyPlayers, int totalPlayers) {
  char cap1[MAX_NAME_LENGTH];
  char cap2[MAX_NAME_LENGTH];
  const int kMaxNameLength = 14;

  if (IsPlayer(g_capt1)) {
    Format(cap1, sizeof(cap1), "%N", g_capt1);
    if (strlen(cap1) > kMaxNameLength) {
      strcopy(cap1, kMaxNameLength, cap1);
      Format(cap1, sizeof(cap1), "%s...", cap1);
    }
  } else {
    Format(cap1, sizeof(cap1), "%T", "CaptainNotSelected", client);
  }

  if (IsPlayer(g_capt2)) {
    Format(cap2, sizeof(cap2), "%N", g_capt2);
    if (strlen(cap2) > kMaxNameLength) {
      strcopy(cap2, kMaxNameLength, cap2);
      Format(cap2, sizeof(cap2), "%s...", cap2);
    }
  } else {
    Format(cap2, sizeof(cap2), "%T", "CaptainNotSelected", client);
  }

  PrintHintTextToAll("%t", "ReadyStatusCaptains", readyPlayers, totalPlayers, cap1, cap2);

  // if there aren't any captains and we full players, print the hint telling the leader how to set
  // captains
  if (!IsPlayer(g_capt1) && !IsPlayer(g_capt2) && totalPlayers >= Pugsetup_GetPugMaxPlayers()) {
    // but only do it at most every CAPTAIN_COMMAND_HINT_TIME seconds so it doesn't get spammed
    int time = GetTime();
    int dt = time - g_LastCaptainHintTime;
    if (dt >= CAPTAIN_COMMAND_HINT_TIME) {
      g_LastCaptainHintTime = time;
      char cmd[ALIAS_LENGTH];
      GetInputFromCommand("sm_capt", cmd);
      // MessageToAll("%t", "SetCaptainsHint", Pugsetup_GetLeader(), cmd);
    }
  }
}

/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

public Action Command_Setup(int client, int args) {
  if (g_SetupEnabledCvar.IntValue == 0) {
    return Plugin_Handled;
  }

  if (g_GameState > GameState_Warmup) {
    Message(client, "%t", "AlreadyLive");
    return Plugin_Handled;
  }

  if (g_GameState == GameState_Warmup) {
    Pugsetup_GiveSetupMenu(client, false);
    return Plugin_Handled;
  }

  if (client == 0) {
    // if we did the setup command from the console just use the default settings
    ReadSetupOptions();
    Pugsetup_SetupGame(g_TeamType, g_MapType, g_PlayersPerTeam, g_RecordGameOption, g_DoKnifeRound);
  } else {
    Pugsetup_GiveSetupMenu(client);
  }

  return Plugin_Handled;
}

public Action Command_Rand(int client, int args) {
  if (g_GameState != GameState_Warmup)
    return Plugin_Handled;

  if (!UsingCaptains()) {
    Message(client, "%t", "NotUsingCaptains");
    return Plugin_Handled;
  }

  Pugsetup_SetRandomCaptains();
  return Plugin_Handled;
}

public Action Command_Capt(int client, int args) {
  if (g_GameState != GameState_Warmup)
    return Plugin_Handled;

  if (!UsingCaptains()) {
    Message(client, "%t", "NotUsingCaptains");
    return Plugin_Handled;
  }

  char buffer[MAX_NAME_LENGTH];
  if (GetCmdArgs() >= 1) {
    GetCmdArg(1, buffer, sizeof(buffer));
    int target = FindTarget(client, buffer, true, false);
    if (IsPlayer(target))
      Pugsetup_SetCaptain(1, target, true);

    if (GetCmdArgs() >= 2) {
      GetCmdArg(2, buffer, sizeof(buffer));
      target = FindTarget(client, buffer, true, false);

      if (IsPlayer(target))
        Pugsetup_SetCaptain(2, target, true);

    } else {
      Captain2Menu(client);
    }

  } else {
    Captain1Menu(client);
  }
  return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args) {
  if (g_GameState != GameState_Warmup)
    return Plugin_Handled;


  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && !Pugsetup_IsReady(i)) {
      Pugsetup_ReadyPlayer(i, false);
    }
  }
  g_ForceStartSignal = true;
  return Plugin_Handled;
}

public void GetInputFromCommand(const char[] command, char alias[ALIAS_LENGTH]) {
  strcopy(alias, sizeof(alias), command);
  ReplaceString(alias, sizeof(alias), "sm_", ".");
}


public Action Command_ForceEnd(int client, int args) {

  Call_StartForward(g_OnForceEnd);
  Call_PushCell(client);
  Call_Finish();

  MessageToAll("%t", "ForceEnd", client);
  EndMatch(true);
  g_ForceEnded = true;
  return Plugin_Handled;
}

public Action Command_ForceReady(int client, int args) {

  char buffer[MAX_NAME_LENGTH];
  if (args >= 1 && GetCmdArg(1, buffer, sizeof(buffer))) {
    if (StrEqual(buffer, "all")) {
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
          Pugsetup_ReadyPlayer(i);
        }
      }
    } else {
      int target = FindTarget(client, buffer, true, false);
      if (IsPlayer(target)) {
        Pugsetup_ReadyPlayer(target);
      }
    }
  } else {
    Message(client, "Usage: .forceready <player>");
  }

  return Plugin_Handled;
}

static bool Pauseable() {
  return g_GameState >= GameState_KnifeRound && g_PausingEnabledCvar.IntValue != 0;
}

public Action Command_Pause(int client, int args) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  if (!Pauseable() || IsPaused())
    return Plugin_Handled;
  
  
  g_ctUnpaused = false;
  g_tUnpaused = false;

  int team = GetClientTeam(client);
  if (g_PauseCountLimitCvar.IntValue > 0)
  {
    if (g_PauseCount[team] <= 0)
    {
      Message(client, "你们已经没有暂停的机会啦!");
      return Plugin_Handled;
    }
    else
    {
      g_PauseCount[team]--;
    }
  }

  if (g_PauseTimeCvar.IntValue > 0 && g_IsInFreezeTime)
  {
    StartPauseCountDown();
  }
  Pause();
  if (IsPlayer(client)) {
    if (g_PauseCountLimitCvar.IntValue > 0)
    {
      MessageToAll("%t, 该队伍还剩 {LIGHT_RED}%d {NORMAL}次暂停机会", "Pause", client, g_PauseCount[team]);
    }
    else
    {
      MessageToAll("%t", "Pause", client);
    }
  }

  return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  if (!IsPaused())
    return Plugin_Handled;

  char unpauseCmd[ALIAS_LENGTH];
  GetInputFromCommand("sm_unpause", unpauseCmd);

  // Let console force unpause
  if (client == 0) {
    ClearPauseCountDown();
  } else {
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T)
      g_tUnpaused = true;
    else if (team == CS_TEAM_CT)
      g_ctUnpaused = true;

    if (g_tUnpaused && g_ctUnpaused) {
      ClearPauseCountDown();
      if (IsPlayer(client)) {
        MessageToAll("%t", "Unpause", client);
      }
    } else if (g_tUnpaused && !g_ctUnpaused) {
      MessageToAll("%t", "MutualUnpauseMessage", "T", "CT", unpauseCmd);
    } else if (!g_tUnpaused && g_ctUnpaused) {
      MessageToAll("%t", "MutualUnpauseMessage", "CT", "T", unpauseCmd);
    }
  }

  return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
  Pugsetup_ReadyPlayer(client);
  return Plugin_Handled;
}

public Action Command_NotReady(int client, int args) {
  Pugsetup_UnreadyPlayer(client);
  return Plugin_Handled;
}

/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action Event_MatchOver(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == GameState_Live) {
    CreateTimer(15.0, Timer_EndMatch);
    ExecCfg(g_WarmupCfgCvar);

    char map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    g_PastMaps.PushString(map);
  }

  if (g_PastMaps.Length > g_ExcludedMaps.IntValue) {
    g_PastMaps.Erase(0);
  }

  return Plugin_Continue;
}

/** Helper timer to delay starting warmup period after match is over by a little bit **/
public Action Timer_EndMatch(Handle timer) {
  EndMatch(false, false);
  ChangeMap(g_MapList, _, _, false);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  CheckAutoSetup();
  if (IsPaused() && Pugsetup_IsMatchLive())
  {
    StartPauseCountDown();
  }
  g_IsInFreezeTime = true;
}

public Action Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  g_IsInFreezeTime = false;
  if (g_GameState == GameState_Live)
  {
    Stats_RoundStart();
  }
}

public Action Event_RoundPrestart(Event event, const char[] name, bool dontBroadcast) {
  Stats_ResetRoundValues();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == GameState_KnifeRound) {
    ChangeState(GameState_WaitingForKnifeRoundDecision);
    g_KnifeWinner = GetKnifeRoundWinner();

    char teamString[4];
    if (g_KnifeWinner == CS_TEAM_CT)
      teamString = "CT";
    else
      teamString = "T";

    char stayCmd[ALIAS_LENGTH];
    char swapCmd[ALIAS_LENGTH];
    GetInputFromCommand("sm_stay", stayCmd);
    GetInputFromCommand("sm_swap", swapCmd);

    CreateKnifeVoteMenu();
    MessageToAll("%t", "KnifeRoundWinnerVote", teamString, stayCmd, swapCmd);
  }

  if (g_GameState == GameState_Live)
  {
    int csTeamWinner = event.GetInt("winner");
    Stats_RoundEnd(csTeamWinner);
    Call_StartForward(g_OnRoundStatsUpdated);
    Call_Finish();
    if (CS_GetTeamScore(CS_TEAM_T) == 15 && CS_GetTeamScore(CS_TEAM_CT) == 15)
    {
      DisplayOvertimeVoteMenu();
    }
  }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != GameState_Warmup)
    return;

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client) && OnActiveTeam(client) && g_WarmupMoneyOnSpawnCvar.IntValue != 0) {
    SetEntProp(client, Prop_Send, "m_iAccount", GetCvarIntSafe("mp_maxmoney"));
  }
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  g_Teams[client] = CS_TEAM_NONE;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  if (g_capt1 == client)
    g_capt1 = -1;
  if (g_capt2 == client)
    g_capt2 = -1;
}

/**
 * Silences cvar changes when executing live/knife/warmup configs, *unless* it's sv_cheats.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != GameState_None) {
    char cvarName[128];
    event.GetString("cvarname", cvarName, sizeof(cvarName));
    if (!StrEqual(cvarName, "sv_cheats")) {
      event.BroadcastDisabled = true;
    }
  }

  return Plugin_Continue;
}

/***********************
 *                     *
 *   Pugsetup logic    *
 *                     *
 ***********************/

public void PrintSetupInfo(int client) {
  // print each setup option avaliable
  char buffer[128];

  if (g_DisplayMapType) {
    GetMapString(buffer, sizeof(buffer), g_MapType, client);
    Message(client, "%t: {GREEN}%s", "MapTypeOption", buffer);
  }

  if (g_DisplayTeamSize || g_DisplayTeamType) {
    GetTeamString(buffer, sizeof(buffer), g_TeamType, client);
    Message(client, "%t: ({GREEN}%d vs %d{NORMAL}) {GREEN}%s", "TeamTypeOption",
                     g_PlayersPerTeam, g_PlayersPerTeam, buffer);
  }

  if (g_DisplayRecordDemo) {
    GetEnabledString(buffer, sizeof(buffer), g_RecordGameOption, client);
    Message(client, "%t: {GREEN}%s", "DemoOption", buffer);
  }

  if (g_DisplayKnifeRound) {
    GetEnabledString(buffer, sizeof(buffer), g_DoKnifeRound, client);
    Message(client, "%t: {GREEN}%s", "KnifeRoundOption", buffer);
  }
}

public void ReadyToStart() {
  Call_StartForward(g_hOnReadyToStart);
  Call_Finish();

  DisplayFriendlyFireVoteMenu();
}

public void CreateCountDown() {
  ChangeState(GameState_Countdown);
  g_CountDownTicks = g_StartDelayCvar.IntValue;
  CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CountDown(Handle timer) {
  if (g_GameState != GameState_Countdown) {
    // match cancelled
    MessageToAll("%t", "CancelCountdownMessage");
    return Plugin_Stop;
  }

  if (g_CountDownTicks <= 0) {
    StartGame();
    return Plugin_Stop;
  }

  if (g_AnnounceCountdownCvar.IntValue != 0 &&
      (g_CountDownTicks < 5 || g_CountDownTicks % 5 == 0)) {
    MessageToAll("%t", "Countdown", g_CountDownTicks);
  }

  g_CountDownTicks--;

  return Plugin_Continue;
}

public void StartGame() {
  if (g_RecordGameOption && !IsTVEnabled()) {
    LogError("GOTV demo could not be recorded since tv_enable is not set to 1");
  } else if (g_RecordGameOption && IsTVEnabled()) {
    // get the map, with any workshop stuff before removed
    // this is {MAP} in the format string
    char mapName[128];
    GetCurrentMap(mapName, sizeof(mapName));
    int last_slash = 0;
    int len = strlen(mapName);
    for (int i = 0; i < len; i++) {
      if (mapName[i] == '/' || mapName[i] == '\\')
        last_slash = i + 1;
    }

    // get the time, this is {TIME} in the format string
    char timeFormat[64];
    g_DemoTimeFormatCvar.GetString(timeFormat, sizeof(timeFormat));
    int timeStamp = GetTime();
    char formattedTime[64];
    FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

    // get the player count, this is {TEAMSIZE} in the format string
    char playerCount[MAX_INTEGER_STRING_LENGTH];
    IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

    // create the actual demo name to use
    char demoName[PLATFORM_MAX_PATH];
    g_DemoNameFormatCvar.GetString(demoName, sizeof(demoName));

    ReplaceString(demoName, sizeof(demoName), "{MAP}", mapName[last_slash], false);
    ReplaceString(demoName, sizeof(demoName), "{TEAMSIZE}", playerCount, false);
    ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);

    Call_StartForward(g_hOnStartRecording);
    Call_PushString(demoName);
    Call_Finish();

    if (Record(demoName)) {
      LogMessage("Recording to %s", demoName);
      Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
      g_Recording = true;
    }
  }

  if (g_TeamType == TeamType_Autobalanced) {
    if (!Pugsetup_IsTeamBalancerAvaliable()) {
      LogError(
          "Match setup with autobalanced teams without a balancer avaliable - falling back to random teams");
      g_TeamType = TeamType_Random;
    } else {
      ArrayList players = new ArrayList();
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
          if (Pugsetup_IsReady(i))
            players.Push(i);
          else
            ChangeClientTeam(i, CS_TEAM_SPECTATOR);
        }
      }

      char buffer[128];
      GetPluginFilename(g_BalancerFunctionPlugin, buffer, sizeof(buffer));

      Call_StartFunction(g_BalancerFunctionPlugin, g_BalancerFunction);
      Call_PushCell(players);
      Call_Finish();
      delete players;
    }
  }

  if (g_TeamType == TeamType_Random) {
    MessageToAll("%t", "Scrambling");
    ScrambleTeams();
  }

  CreateTimer(3.0, Timer_BeginMatch);
  ExecGameConfigs();
  if (InWarmup()) {
    EndWarmup();
  }
}

public Action Timer_BeginMatch(Handle timer) {
  // clear pause count
  ResetPauseCount();

  if (g_DoKnifeRound) {
    ChangeState(GameState_KnifeRound);
    CreateTimer(3.0, StartKnifeRound, _, TIMER_FLAG_NO_MAPCHANGE);
  } else {
    ChangeState(GameState_GoingLive);
    CreateTimer(3.0, BeginLive, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public void ScrambleTeams() {
  int tCount = 0;
  int ctCount = 0;

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) != CS_TEAM_SPECTATOR) {
      if (tCount < g_PlayersPerTeam && ctCount < g_PlayersPerTeam) {
        bool ct = (GetRandomInt(0, 1) == 0);
        if (ct) {
          SwitchPlayerTeam(i, CS_TEAM_CT);
          ctCount++;
        } else {
          SwitchPlayerTeam(i, CS_TEAM_T);
          tCount++;
        }

      } else if (tCount < g_PlayersPerTeam && ctCount >= g_PlayersPerTeam) {
        // CT is full
        SwitchPlayerTeam(i, CS_TEAM_T);
        tCount++;

      } else if (ctCount < g_PlayersPerTeam && tCount >= g_PlayersPerTeam) {
        // T is full
        SwitchPlayerTeam(i, CS_TEAM_CT);
        ctCount++;

      } else {
        // both teams full
        SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
        Call_StartForward(g_hOnNotPicked);
        Call_PushCell(i);
        Call_Finish();
      }
    }
  }
}

public void ExecWarmupConfigs() {
  ExecCfg(g_WarmupCfgCvar);
}

public void ExecGameConfigs() {
  ServerCommand("exec gamemode_competitive");

  ExecCfg(g_LiveCfgCvar);
  if (InWarmup())
    EndWarmup();

  ServerCommand("mp_match_can_clinch 1");
}

stock void EndMatch(bool execConfigs = true, bool doRestart = true) {
  if (g_GameState == GameState_None) {
    return;
  }

  if (g_Recording) {
    StopRecording();
    g_Recording = false;
    Call_StartForward(g_hOnMatchOver);
    Call_PushCell(true);
    Call_PushString(g_DemoFileName);
    Call_Finish();
  } else {
    Call_StartForward(g_hOnMatchOver);
    Call_PushCell(false);
    Call_PushString("");
    Call_Finish();
  }

  g_LiveTimerRunning = false;
  g_capt1 = -1;
  g_capt2 = -1;
  g_OnDecidedMap = false;
  ChangeState(GameState_None);

  if (g_KnifeCvarRestore != null) {
    RestoreCvars(g_KnifeCvarRestore);
    CloseCvarStorage(g_KnifeCvarRestore);
    g_KnifeCvarRestore = null;
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClanTag(i);
    }
  }

  if (execConfigs) {
    ExecCfg(g_PostGameCfgCvar);
  }
  if (IsPaused()) {
    ClearPauseCountDown();
  }
  if (InWarmup()) {
    EndWarmup();
  }
  if (doRestart) {
    RestartGame(1);
  }
}

public void SetupMapVotePool(bool excludeRecentMaps) {
  g_MapVotePool.Clear();

  char mapNamePrimary[PLATFORM_MAX_PATH];
  char mapNameSecondary[PLATFORM_MAX_PATH];

  for (int i = 0; i < g_MapList.Length; i++) {
    bool mapExists = false;
    FormatMapName(g_MapList, i, mapNamePrimary, sizeof(mapNamePrimary));
    for (int v = 0; v < g_PastMaps.Length; v++) {
      g_PastMaps.GetString(v, mapNameSecondary, sizeof(mapNameSecondary));
      if (StrEqual(mapNamePrimary, mapNameSecondary)) {
        mapExists = true;
      }
    }
    if (!mapExists || !excludeRecentMaps) {
      g_MapVotePool.PushString(mapNamePrimary);
    }
  }
}

public Action MapSetup(Handle timer) {
  if (g_MapType == MapType_Vote) {
    CreateMapVote();
  } else if (g_MapType == MapType_Veto) {
    CreateMapVeto();
  } else {
    LogError("Unexpected map type in MapSetup=%d", g_MapType);
  }
  return Plugin_Handled;
}

public Action StartPicking(Handle timer) {
  ChangeState(GameState_PickingPlayers);
  Pause();
  RestartGame(1);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      g_Teams[i] = CS_TEAM_SPECTATOR;
      SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
    } else {
      g_Teams[i] = CS_TEAM_NONE;
    }
  }

  // temporary teams
  SwitchPlayerTeam(g_capt2, CS_TEAM_CT);
  g_Teams[g_capt2] = CS_TEAM_CT;

  SwitchPlayerTeam(g_capt1, CS_TEAM_T);
  g_Teams[g_capt1] = CS_TEAM_T;

  CreateTimer(2.0, Timer_InitialChoiceMenu);
  return Plugin_Handled;
}

public Action FinishPicking(Handle timer) {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      if (g_Teams[i] == CS_TEAM_NONE || g_Teams[i] == CS_TEAM_SPECTATOR) {
        SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
        Call_StartForward(g_hOnNotPicked);
        Call_PushCell(i);
        Call_Finish();
      } else {
        SwitchPlayerTeam(i, g_Teams[i]);
      }
    }
  }

  Unpause();
  ReadyToStart();

  return Plugin_Handled;
}

public void CheckAutoSetup() {
  if (g_AutoSetupCvar.IntValue != 0 && g_GameState == GameState_None && !g_ForceEnded) {
    // Re-fetch the defaults
    ReadSetupOptions();
    SetupFinished();
  }
}

public void ExecCfg(ConVar cvar) {
  char cfg[PLATFORM_MAX_PATH];
  cvar.GetString(cfg, sizeof(cfg));

  // for files that start with configs/pugsetup/* we just
  // read the file and execute each command individually,
  // otherwise we assume the file is in the cfg/ directory and
  // just use the game's exec command.
  if (StrContains(cfg, "configs/pugsetup") == 0) {
    char formattedPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, formattedPath, sizeof(formattedPath), cfg);
    ExecFromFile(formattedPath);
  } else {
    ServerCommand("exec \"%s\"", cfg);
  }

  if (cvar == g_LiveCfgCvar) {
    Call_StartForward(g_hOnLiveCfg);
    Call_Finish();
  } else if (cvar == g_WarmupCfgCvar) {
    Call_StartForward(g_hOnWarmupCfg);
    Call_Finish();
  } else if (cvar == g_PostGameCfgCvar) {
    Call_StartForward(g_hOnPostGameCfg);
    Call_Finish();
  }
}

public void ExecFromFile(const char[] path) {
  if (FileExists(path)) {
    File file = OpenFile(path, "r");
    if (file != null) {
      char buffer[256];
      while (!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer))) {
        ServerCommand(buffer);
      }
      delete file;
    } else {
      LogError("Failed to open config file for reading: %s", path);
    }
  } else {
    LogError("Config file does not exist: %s", path);
  }
}

stock void UpdateClanTag(int client, bool strip = false) {
  if (IsPlayer(client) && GetClientTeam(client) != CS_TEAM_NONE) {
    if (!g_SavedClanTag[client]) {
      CS_GetClientClanTag(client, g_ClanTag[client], CLANTAG_LENGTH);
      g_SavedClanTag[client] = true;
    }

    // don't bother with crazy things when the plugin isn't active
    if (g_GameState == GameState_Live || g_GameState == GameState_None || strip) {
      RestoreClanTag(client);
      return;
    }

    int team = GetClientTeam(client);
    if (team == CS_TEAM_CT || team == CS_TEAM_T) {
      char tag[32];
      if (g_Ready[client]) {
        Format(tag, sizeof(tag), "%T", "Ready", LANG_SERVER);
      } else {
        Format(tag, sizeof(tag), "%T", "NotReady", LANG_SERVER);
      }
      CS_SetClientClanTag(client, tag);
    } else {
      RestoreClanTag(client);
    }
  }
}

// Restores the clan tag to a client's original setting, or the empty string if it was never saved.
public void RestoreClanTag(int client) {
  if (g_SavedClanTag[client]) {
    CS_SetClientClanTag(client, g_ClanTag[client]);
  } else {
    CS_SetClientClanTag(client, "");
  }
}

public void ChangeState(GameState state) {
  Call_StartForward(g_hOnStateChange);
  Call_PushCell(g_GameState);
  Call_PushCell(state);
  Call_Finish();
  g_GameState = state;
}

stock bool TeamTypeFromString(const char[] teamTypeString, TeamType& teamType,
                              bool logError = false) {
  if (StrEqual(teamTypeString, "captains", false) || StrEqual(teamTypeString, "captain", false)) {
    teamType = TeamType_Captains;
  } else if (StrEqual(teamTypeString, "manual", false)) {
    teamType = TeamType_Manual;
  } else if (StrEqual(teamTypeString, "random", false)) {
    teamType = TeamType_Random;
  } else if (StrEqual(teamTypeString, "autobalanced", false) ||
             StrEqual(teamTypeString, "balanced", false)) {
    teamType = TeamType_Autobalanced;
  } else {
    if (logError)
      LogError(
          "Invalid team type: \"%s\", allowed values: \"captains\", \"manual\", \"random\", \"autobalanced\"",
          teamTypeString);
    return false;
  }

  return true;
}

stock bool MapTypeFromString(const char[] mapTypeString, MapType& mapType, bool logError = false) {
  if (StrEqual(mapTypeString, "current", false)) {
    mapType = MapType_Current;
  } else if (StrEqual(mapTypeString, "vote", false)) {
    mapType = MapType_Vote;
  } else if (StrEqual(mapTypeString, "veto", false)) {
    mapType = MapType_Veto;
  } else {
    if (logError)
      LogError("Invalid map type: \"%s\", allowed values: \"current\", \"vote\", \"veto\"",
               mapTypeString);
    return false;
  }

  return true;
}

stock bool PermissionFromString(const char[] permissionString, Permission& p,
                                bool logError = false) {
  if (StrEqual(permissionString, "all", false) || StrEqual(permissionString, "any", false)) {
    p = Permission_All;
  } else if (StrEqual(permissionString, "captains", false) ||
             StrEqual(permissionString, "captain", false)) {
    p = Permission_Captains;
  } else if (StrEqual(permissionString, "leader", false)) {
    p = Permission_Leader;
  } else if (StrEqual(permissionString, "admin", false)) {
    p = Permission_Admin;
  } else if (StrEqual(permissionString, "none", false)) {
    p = Permission_None;
  } else {
    if (logError)
      LogError(
          "Invalid permission type: \"%s\", allowed values: \"all\", \"captain\", \"leader\", \"admin\", \"none\"",
          permissionString);
    return false;
  }

  return true;
}
