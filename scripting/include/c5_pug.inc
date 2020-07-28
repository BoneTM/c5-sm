#if defined _c5_pug_included
#endinput
#endif
#define _c5_pug_included

// Different ways teams can be selected.
enum TeamType {
  TeamType_Manual,
  TeamType_Random,
  TeamType_Captains,
  TeamType_Autobalanced,  // only allowed if C5_PUG_IsTeamBalancerAvaliable() is true
};

// Different ways the map can be selected.
enum MapType {
  MapType_Current,
  MapType_Vote,
  MapType_Veto,
};

// Permission checking values.
enum Permission {
  Permission_All,       // anyone can use the command
  Permission_Captains,  // only captains (and higher) can use the command (note: reverts to
                        // Permission_All when not using captains)
  Permission_Leader,    // only the pug leader (and higher) can use the command
  Permission_Admin,     // only pug admins can use the command
  Permission_None,      // this command is disabled
};

// Pug game state
enum GameState {
  GameState_None,                          // no setup has taken place
  GameState_Warmup,                        // setup done, waiting for players to ready up
  GameState_PickingPlayers,                // only used if TeamType_Captains is the teamtype
  GameState_Countdown,                     // doing the countdown timer
  GameState_KnifeRound,                    // in the knife round
  GameState_WaitingForKnifeRoundDecision,  // waiting for a .stay/.swap command after the knife
                                           // round
  GameState_GoingLive,                     // in the lo3 process
  GameState_Live,                          // the match is live
};

enum ChatAliasMode {
  ChatAlias_Always,     // Alias is always enabled
  ChatAlias_WhenSetup,  // Alias is only available when game state is not GameState_None
};

/**
 * Called when a setup menu is opened.
 *
 * @param client Client that did the setup menu (e.g. the leader).
 * @param menu The menu being given to the client.
 * @return Whether to display the menu to the client or not.
 */
forward Action C5_PUG_OnSetupMenuOpen(int client, Menu menu, bool displayOnly);

/**
 * Called when a setup menu option is selected.
 * You should call C5_PUG_GiveSetupMenu to the calling client at the end of this function.
 */
forward void C5_PUG_OnSetupMenuSelect(Menu menu, int client, const char[] selected_info,
                                        int selected_position);

/**
 * Called when a setup is completed.
 */
forward void C5_PUG_OnSetup();

/**
 * Called when a client force-ends the match.
 *
 * @param client Client that force-ended the match.
 */
forward void C5_PUG_OnForceEnd(int client);

/**
 * Called when a player marks themselves as ready.
 */
forward void C5_PUG_OnReady(int client);

/**
 * Called when a player marks themselves as not ready.
 */
forward void C5_PUG_OnUnready(int client);

/**
 * Called when the match is ready to begin, for example
 * when all players are ready and the captains are now picking players.
 */
forward void C5_PUG_OnReadyToStart();

/**
 * Called when a team won the knife round and made their decision.
 */
forward void C5_PUG_OnKnifeRoundDecision(bool swapping);

/**
 * Called when the going-live process begins, before the lo3.
 */
forward void C5_PUG_OnGoingLive();

/**
 * Called after the last restart when the game is completely live.
 */
forward void C5_PUG_OnLive();

/**
 * Called after the warmup config is executed.
 */
forward void C5_PUG_OnWarmupCfgExecuted();

/**
 * Called after the live config is executed.
 */
forward void C5_PUG_OnLiveCfgExecuted();

/**
 * Called after the postgame config is executed.
 */
forward void C5_PUG_OnPostGameCfgExecuted();

/**
 * Called when the match is over.
 * If you plan on using the result of the demo file,
 * I'd suggest adding a slight delay from when this is called
 * to accomodate the time spent flushing the demo to disk.
 *
 * @param hasDemo whether a demo was being recorded
 * @param demoFileName the filename of the demo (including the .dem extension)
 */
forward void C5_PUG_OnMatchOver(bool hasDemo, const char[] demoFileName);

/**
 * Called when a client is not picked in a captain-selection game.
 */
forward void C5_PUG_OnNotPicked(int client);

/**
 * Called every timer-check for whether the pug is ready to start or not.
 */
forward void C5_PUG_OnReadyToStartCheck(int readyPlayers, int totalPlayers);

/**
 * Called when user permissions are being checked. You can change
 * the value of "allow" to change the result of the check and allow
 * or disallow an action.
 *
 * @param client Client that initiated the command
 * @param command The command that was issued
 * @param p Default permissions the plugin checked against
 * @param allow Result of the check
 * @note permissions-checking is only relevent for pugsetup commands.
 */
forward void C5_PUG_OnPermissionCheck(int client, const char[] command, Permission p,
                                        bool& allow);

/**
 * Called when a tv_record command is about to be sent.
 *
 * @param demoName The name given when the tv_record command was used (no .dem file extension)
 */
forward void C5_PUG_OnStartRecording(char[] demoName);

/**
 * Called before a player gets added to a captain selection menu.
 *
 * @param menu The Menu players are being added to
 * @param client The client being added to the menu
 * @param menuString The menu display string being added for the client
 * @param length Length of the menuString
 */
forward void C5_PUG_OnPlayerAddedToCaptainMenu(Menu menu, int client, char[] menuString,
                                                 int length);

/**
 * Called when a client issues a .help command in chat.
 *
 * @param client The client issuing the command
 * @param replyMessages An ArrayList of Strings to reply with (in chat)
 * @param maxMessageSize The max length of a string in the replyMessages list
 * @param block Whether to block the reply message (set to true to have no reply)
 */
forward void C5_PUG_OnHelpCommand(int client, ArrayList replyMessages, int maxMessageSize,
                                    bool& block);

/**
 * Called during any game state change.
 */
forward void C5_PUG_OnGameStateChanged(GameState before, GameState after);

typedef TeamBalancerFunction = function void(ArrayList players);

/**
 * Returns if a team balancer function has been set for pugsetup to use, if selected in the setup
 * menu.
 */
native bool C5_PUG_IsTeamBalancerAvaliable();

/**
 * Sets a team balancer function, returning if the balancer function was set.
 */
native bool C5_PUG_SetTeamBalancer(TeamBalancerFunction balancerFunction, bool override = false);

/**
 * Clears any team balancer function set, returning if there was one before clearing.
 */
native bool C5_PUG_ClearTeamBalancer();

// Sets a game up with the given settings.
native void C5_PUG_SetupGame(TeamType teamType, MapType mapType = MapType_Vote,
                               int playersPerTeam = 5, bool recordDemo = false,
                               bool knifeRound = false);

// Sets the current game options. These can still be overwritten by a user with access to the .setup
// menu.
native void C5_PUG_SetSetupOptions(TeamType teamType, MapType mapType, int playersPerTeam = 5,
                                     bool recordDemo = false, bool knifeRound = false);

// Fetches the current game options.
// @error If there is no game setup yet.
native void C5_PUG_GetSetupOptions(TeamType& teamType, MapType& mapType, int& playersPerTeam,
                                     bool& recordDemo, bool& knifeRound);

// Readies up a player, optionally printing chat messages
// to the client about readying up.
// Returns if they were successfully readied.
native bool C5_PUG_ReadyPlayer(int client, bool chatReply = true);

// Unreadies a player.
// Returns if they were successfully unreadied. (returns false if the client was already not-ready)
native bool C5_PUG_UnreadyPlayer(int client);

// Returns whether a client is ready.
// This is only valid when the game is setup AND not live.
native bool C5_PUG_IsReady(int client);

// Returns if the game settings have been setup.
native bool C5_PUG_IsSetup();

// Returns the team type being used.
// Only valid if C5_PUG_IsSetup is true.
native TeamType C5_PUG_GetTeamType();

// Returns the map type being used.
// Only valid if C5_PUG_IsSetup is true.
native MapType C5_PUG_GetMapType();

// Returns the current pug gamestate.
native GameState C5_PUG_GetGameState();

// Returns if there is currently a match setup.
native bool C5_PUG_IsMatchLive();

// Returns if the match is pending start. (e.g. during the lo3)
native bool C5_PUG_IsWarmup();

// Sets the pug leader.
native void C5_PUG_SetLeader(int client);

// Returns the pug leader, or -1 if not set.
native int C5_PUG_GetLeader(bool allowLeaderReassignment = true);

// Sets who is a captain.
// A captain number is either 1 or 2.
native void C5_PUG_SetCaptain(int captainNumber, int client, bool printIfSame = false);

// Returns captain 1, or -1 if not set.
// A captain number is either 1 or 2.
native int C5_PUG_GetCaptain(int captainNumber);

// Returns the maximum number of players in the pug.
// Only valid if the game has already been setup.
native int C5_PUG_GetPugMaxPlayers();

// Returns if a client was present when the game started.
// This doesn't include if the player disconnected and reconnected.
native bool C5_PUG_PlayerAtStart(int client);

// Returns if the plugin has identified a player as having elevated permissions.
native bool C5_PUG_IsPugAdmin(int client);

// Returns if a client satisfies a permission check.
native bool C5_PUG_HasPermissions(int client, Permission p, bool allowLeaderReassignment = true);

// Sets random captains.
native void C5_PUG_SetRandomCaptains();

// Adds a chat alias for a command. For example: .setup as a chat trigger for sm_setup
native void C5_PUG_AddChatAlias(const char[] alias, const char[] command,
                                  ChatAliasMode mode = ChatAlias_Always);

// Give a client the root setup menu again.
// This is intended to be called in the C5_PUG_OnSetupMenuSelect forward.
native void C5_PUG_GiveSetupMenu(int client, bool displayOnly = false, int menuPosition = -1);

// Displays the map change menu to a client (bypasses access checks).
native void C5_PUG_GiveMapChangeMenu(int client);

// Returns if a console command is a valid pugsetup command.
native bool C5_PUG_IsValidCommand(const char[] command);

// Gets the permissions for a command, or throws an error on invalid command.
// Note: permissions-checking is only relevent for pugsetup commands.
native Permission C5_PUG_GetPermissions(const char[] command);

// Sets the permissions for a command, returning whether the command already had permissions set.
// Note: permissions-checking is only relevent for pugsetup commands.
native bool C5_PUG_SetPermissions(const char[] command, Permission p);

// Returns if we're on the map that is going to be used.
native bool C5_PUG_IsDecidedMap();

native bool C5_PUG_IsClientInAuths(int client);

native void C5_PUG_ClearAuths();

public SharedPlugin __pl_c5_pug = {
    name = "c5_pug", file = "c5_pug.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_c5_pug_SetNTVOptional() {
  MarkNativeAsOptional("C5_PUG_SetupGame");
  MarkNativeAsOptional("C5_PUG_GetSetupOptions");
  MarkNativeAsOptional("C5_PUG_SetSetupOptions");
  MarkNativeAsOptional("C5_PUG_ReadyPlayer");
  MarkNativeAsOptional("C5_PUG_UnreadyPlayer");
  MarkNativeAsOptional("C5_PUG_IsReady");
  MarkNativeAsOptional("C5_PUG_IsSetup");
  MarkNativeAsOptional("C5_PUG_GetTeamType");
  MarkNativeAsOptional("C5_PUG_GetMapType");
  MarkNativeAsOptional("C5_PUG_GetGameState");
  MarkNativeAsOptional("C5_PUG_IsMatchLive");
  MarkNativeAsOptional("C5_PUG_IsWarmup");
  MarkNativeAsOptional("C5_PUG_SetLeader");
  MarkNativeAsOptional("C5_PUG_GetLeader");
  MarkNativeAsOptional("C5_PUG_SetCaptain");
  MarkNativeAsOptional("C5_PUG_GetCaptain");
  MarkNativeAsOptional("C5_PUG_GetPugMaxPlayers");
  MarkNativeAsOptional("C5_PUG_PlayerAtStart");
  MarkNativeAsOptional("C5_PUG_IsPugAdmin");
  MarkNativeAsOptional("C5_PUG_HasPermissions");
  MarkNativeAsOptional("C5_PUG_SetRandomCaptains");
  MarkNativeAsOptional("C5_PUG_AddChatAlias");
  MarkNativeAsOptional("C5_PUG_GiveSetupMenu");
  MarkNativeAsOptional("C5_PUG_GiveMapChangeMenu");
  MarkNativeAsOptional("C5_PUG_IsValidCommand");
  MarkNativeAsOptional("C5_PUG_GetPermissions");
  MarkNativeAsOptional("C5_PUG_SetPermissions");
  MarkNativeAsOptional("C5_PUG_SetTeamBalancer");
  MarkNativeAsOptional("C5_PUG_IsTeamBalancerAvaliable");
  MarkNativeAsOptional("C5_PUG_ClearTeamBalancer");
  MarkNativeAsOptional("C5_PUG_IsDecidedMap");
}
#endif
