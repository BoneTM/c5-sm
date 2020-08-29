#pragma semicolon 1

#include <sourcemod>
#include <json>
#include <system2>

public Plugin myinfo = 
{
	name = "Client stats collector for PW",
	author = "PW",
	description = "Send back user connection info to PW",
}

ConVar g_serverIP;
ConVar g_communityID;
ConVar g_communityKey;

char c_serverIP[64];
char c_communityID[64];
char c_communityKey[64];

int client_guofu[MAXPLAYERS+1];
StringMap client_steamid = null;

public void OnPluginStart(){
	g_serverIP = CreateConVar("pw_serverIP","Default", "Specify server address by IP or URL. e.g: AAA.BBB.CCC.DDD:27015");
	g_communityID = CreateConVar("pw_communityID","Default", "Specify community name. e.g: EXAMPLE Server");
	g_communityKey = CreateConVar("pw_communityKey","", "Specify community key provided.");

	g_serverIP.AddChangeHook(OnServerIPChanged);
	g_communityID.AddChangeHook(OnCommunityIDChanged);
	g_communityKey.AddChangeHook(OnCommunityKeyChanged);
	client_steamid = new StringMap();
}

public void OnMapStart(){
	g_serverIP.GetString(c_serverIP, sizeof(c_serverIP));
	g_communityID.GetString(c_communityID, sizeof(c_communityID));
	g_communityKey.GetString(c_communityKey, sizeof(c_communityKey));

	client_steamid.Clear();
	for (int i = 0; i < MAXPLAYERS+1; ++i) {
		client_guofu[i] = 0;
		//client_steamid.SetString("0");
	}
}

public void OnClientPostAdminCheck(int client) {
	CheckPW(client);
}

void CheckPW(int client) {
	char steamid64[65];
	if (GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64), true)) {
		char clientid[8];
		IntToString(client, clientid, sizeof(clientid));
		client_steamid.SetString(clientid, steamid64);
		System2HTTPRequest httpRequest = new System2HTTPRequest(PWCheckCallback, "https://csgo.wanmei.com/api-user/isOnline?steamIds=%s", steamid64);
		httpRequest.Timeout = 15;
		httpRequest.SetHeader("Content-Type", "application/json;charset=utf-8");
		httpRequest.GET();

		delete httpRequest;
	}
}

void PWCheckCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
	char url[256];
	request.GetURL(url, sizeof(url));

	if (!success) {
		PrintToServer("ERROR: Couldn't retrieve URL %s. Error: %s", url, error);
		PrintToServer("");
		PrintToServer("INFO: Finished");
		PrintToServer("");

		return;
	}

	char result[256];
	char steamid64[18];
	char IsOnline[16];
	int guofu;
	response.GetContent(result, sizeof(result));
	JSON_Object obj = json_decode(result);
	JSON_Object data = obj.GetObject("result");
	StringMapSnapshot snap = data.Snapshot();
	snap.GetKey(0, steamid64, sizeof(steamid64));
	data.GetString(steamid64, IsOnline, sizeof(IsOnline));
	if(StrEqual(IsOnline, "online")) {
		guofu = 1;
	}
	else {
		guofu = 0;
	}
	int client = GetClientIDofSteamid(steamid64);
	if (client > -1) {
		client_guofu[client] = guofu;
	}
	ConnectingRequest(client);

	delete snap;
	delete data;
	delete obj;

	/*response.GetLastURL(url, sizeof(url));

	PrintToServer("INFO: Successfully retrieved URL %s in %.0f milliseconds", url, response.TotalTime * 1000.0);
	PrintToServer("");
	PrintToServer("INFO: HTTP Version: %s", (response.HTTPVersion == VERSION_1_0 ? "1.0" : "1.1"));
	PrintToServer("INFO: Status Code: %d", response.StatusCode);
	PrintToServer("INFO: Downloaded %d bytes with %d bytes/seconds", response.DownloadSize, response.DownloadSpeed);
	PrintToServer("INFO: Uploaded %d bytes with %d bytes/seconds", response.UploadSize, response.UploadSpeed);
	PrintToServer("");
	PrintToServer("INFO: Retrieved the following headers:");

	char name[128];
	char value[128];
	ArrayList headers = response.GetHeaders();

	for (int i = 0; i < headers.Length; i++) {
		headers.GetString(i, name, sizeof(name));
		response.GetHeader(name, value, sizeof(value));
		PrintToServer("\t%s: %s", name, value);
	}
	
	PrintToServer("");
	PrintToServer("INFO: Content (%d bytes):", response.ContentLength);
	PrintToServer("");
	
	char content[128];
	for (int found = 0; found < response.ContentLength;) {
		found += response.GetContent(content, sizeof(content), found);
		PrintToServer(content);
	}

	PrintToServer("");
	PrintToServer("INFO: Finished");
	PrintToServer("");
	
	delete headers;*/
}

void ConnectingRequest(int client) {
	char steamid2[64];
	if (!IsValidClient(client)) {
		return;
	}
	GetClientAuthId(client, AuthId_Steam2, steamid2, sizeof(steamid2), true);

	char guofu[9];
	if (client_guofu[client] == 1) {
		strcopy(guofu, sizeof(guofu), "true");
	}
	else {
		strcopy(guofu, sizeof(guofu), "false");
	}
	if (StrContains(steamid2, "BOT", false) == -1) {
		int timestamp;
		char buffer[256];
		char output[256];
		timestamp = GetTime();
		
		JSON_Array arr = new JSON_Array();
		JSON_Object obj_topic = new JSON_Object();
		obj_topic.SetString("topic", "log_csgo_3rdparty");
		JSON_Object obj_client = new JSON_Object();
		obj_client.SetObject("headers", obj_topic);
		Format(buffer, sizeof(buffer), "{\"timestamp\":\"%i\", \"communityId\":\"%s\",  \"serverip\":\"%s\", \"type\":\"logingame\",  \"steamId\":\"%s\", \"guofu\":\"%s\"}", 
			timestamp, c_communityID, c_serverIP, steamid2, guofu);
		obj_client.SetString("body", buffer);
		arr.PushObject(obj_client);
		json_encode(arr, output, sizeof(output));

		System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "https://log.pwesports.cn/csgo?key=%s", c_communityKey);
		httpRequest.Timeout = 10;
		httpRequest.SetHeader("Content-Type", "application/json;charset=utf-8");
		httpRequest.SetData(output);
		httpRequest.POST();
		delete arr;
		delete obj_topic;
		delete obj_client;
		delete httpRequest;
	}
}

public void OnClientDisconnect(int client) {
	DisconnectingRequest(client);
}

void DisconnectingRequest(int client) {
	char steamid2[64];
	if (!IsValidClient(client)) {
		return;
	}
	GetClientAuthId(client, AuthId_Steam2, steamid2, sizeof(steamid2), true);
	char guofu[9];
	if (client_guofu[client] == 1) {
		strcopy(guofu, sizeof(guofu), "true");
	}
	else {
		strcopy(guofu, sizeof(guofu), "false");
	}
	if (StrContains(steamid2, "BOT", false) == -1) {
		int timestamp;
		char buffer[256];
		char output[256];
		timestamp = GetTime();
		
		JSON_Array arr = new JSON_Array();
		JSON_Object obj_topic = new JSON_Object();
		obj_topic.SetString("topic", "log_csgo_3rdparty");
		JSON_Object obj_client = new JSON_Object();
		obj_client.SetObject("headers", obj_topic);
		Format(buffer, sizeof(buffer), "{\"timestamp\":\"%i\", \"communityId\":\"%s\",  \"serverip\":\"%s\", \"type\":\"logout\",  \"steamId\":\"%s\", \"guofu\":\"%s\"}", 
			timestamp, c_communityID, c_serverIP, steamid2, guofu);
		obj_client.SetString("body", buffer);
		arr.PushObject(obj_client);
		json_encode(arr, output, sizeof(output));

		System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "https://log.pwesports.cn/csgo?key=%s", c_communityKey);
		httpRequest.Timeout = 10;
		httpRequest.SetHeader("Content-Type", "application/json;charset=utf-8");
		httpRequest.SetData(output);
		httpRequest.POST();
		delete arr;
		delete obj_topic;
		delete obj_client;
		delete httpRequest;
	}
}

int GetClientIDofSteamid(const char[] steamid64) {
	for (int i = 1; i < MAXPLAYERS+1; ++i)
	{	
		char buffer[65];
		char clientid[8];
		IntToString(i, clientid, sizeof(clientid));
		client_steamid.GetString(clientid, buffer, sizeof(buffer));
		if (StrEqual(buffer, steamid64)){
			return i;
		}
	}
	return -1;
}

void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
	char url[256];
	request.GetURL(url, sizeof(url));

	if (!success) {
		PrintToServer("ERROR: Couldn't retrieve URL %s. Error: %s", url, error);
		PrintToServer("");
		PrintToServer("INFO: Finished");
		PrintToServer("");

		return;
	}

/*    response.GetLastURL(url, sizeof(url));

	PrintToServer("INFO: Successfully retrieved URL %s in %.0f milliseconds", url, response.TotalTime * 1000.0);
	PrintToServer("");
	PrintToServer("INFO: HTTP Version: %s", (response.HTTPVersion == VERSION_1_0 ? "1.0" : "1.1"));
	PrintToServer("INFO: Status Code: %d", response.StatusCode);
	PrintToServer("INFO: Downloaded %d bytes with %d bytes/seconds", response.DownloadSize, response.DownloadSpeed);
	PrintToServer("INFO: Uploaded %d bytes with %d bytes/seconds", response.UploadSize, response.UploadSpeed);
	PrintToServer("");
	PrintToServer("INFO: Retrieved the following headers:");

	char name[128];
	char value[128];
	ArrayList headers = response.GetHeaders();

	for (int i = 0; i < headers.Length; i++) {
		headers.GetString(i, name, sizeof(name));
		response.GetHeader(name, value, sizeof(value));
		PrintToServer("\t%s: %s", name, value);
	}
	
	PrintToServer("");
	PrintToServer("INFO: Content (%d bytes):", response.ContentLength);
	PrintToServer("");
	
	char content[128];
	for (int found = 0; found < response.ContentLength;) {
		found += response.GetContent(content, sizeof(content), found);
		PrintToServer(content);
	}

	PrintToServer("");
	PrintToServer("INFO: Finished");
	PrintToServer("");
	
	delete headers;*/
}

public void OnServerIPChanged(ConVar convar, const char[] oldValue, const char[] newValue){
	convar.GetString(c_serverIP, sizeof(c_serverIP));
}

public void OnCommunityIDChanged(ConVar convar, const char[] oldValue, const char[] newValue){
	convar.GetString(c_communityID, sizeof(c_communityID));
}

public void OnCommunityKeyChanged(ConVar convar, const char[] oldValue, const char[] newValue){
	convar.GetString(c_communityKey, sizeof(c_communityKey));
}

stock bool:IsValidClient(client, bool:nobots = true)
{ 
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false; 
	}
	return IsClientInGame(client); 
}  