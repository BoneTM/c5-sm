public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("VIP_GetVipPrefix", Native_GetVipPrefix);
	CreateNative("VIP_GetOpPrefix", Native_GetOpPrefix);
	CreateNative("VIP_IsVIP", Native_IsVIP);
	CreateNative("VIP_HasClientLoaded", Native_HasClientLoaded);
	CreateNative("VIP_GetLoadedCount", Native_GetLoadedCount);
	RegPluginLibrary("vip");

	return APLRes_Success;
}

public int Native_GetVipPrefix(Handle plugin, int numParams)
{
	char prefix[30];
	g_VipPrefix.GetString(prefix, sizeof(prefix));
	SetNativeString(1, prefix, GetNativeCell(2));
}

public int Native_GetOpPrefix(Handle plugin, int numParams)
{
	char prefix[30];
	g_OpPrefix.GetString(prefix, sizeof(prefix));
	SetNativeString(1, prefix, GetNativeCell(2));
}

public int Native_IsVIP(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsPlayer(client)) return false;

	return GetTime() < g_VipTime[client];
}

public int Native_HasClientLoaded(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsPlayer(client)) return false;

	return g_VipTime[client] != 0;
}

public int Native_GetLoadedCount(Handle plugin, int numParams)
{
  int count = 0;

  for (int i = 1; i <= MaxClients; i++) {
    if (g_VipTime[i] > 0)
    {
      count++;
    }
  }

  return count;
}
