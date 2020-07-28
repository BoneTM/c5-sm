#if defined _c5_included
  #endinput
#endif
#define _c5_included


enum C5Config{
	C5Config_MessagePrefix,
	C5Config_VipPrefix,
	C5Config_OpPrefix,
}
/**
 * Called when a client is put in server after loading data
 */
forward void C5_OnClientDataLoad(int client, bool isVip);

// Prints a plugin-formatted message to a client.
native void C5_Message(int client, const char[] format, any:...);

// Prints a plugin-formatted message to all clients.
native void C5_MessageToAll(const char[] format, any:...);

public SharedPlugin __pl_c5 = {
  name = "c5",
  file = "c5.smx",
  #if defined REQUIRE_PLUGIN
  required = 1
  #else
  required = 0
  #endif
};

#if !defined REQUIRE_PLUGIN
public __pl_c5_SetNTVOptional() {
  MarkNativeAsOptional("C5_Message");
  MarkNativeAsOptional("C5_MessageToAll");
}
#endif
