/*  CS:GO Gloves SourceMod Plugin
 *
 *  Copyright (C) 2017 Kağan 'kgns' Üstüngel
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <dhooks>

#include "include/message.inc"

#pragma semicolon 1
#pragma newdecls required

#include "c5/util.sp"
#include "gloves/armfix.sp"
#include "gloves/globals.sp"
#include "gloves/hooks.sp"
#include "gloves/helpers.sp"
#include "gloves/database.sp"
#include "gloves/config.sp"
#include "gloves/menus.sp"
#include "gloves/natives.sp"

public Plugin myinfo = 
{
	name = "Gloves",
	author = "kgns | Bone",
	description = "CS:GO Gloves Management",
	version = "1.0.4",
	url = "https://www.oyunhost.net"
};

public void OnPluginStart()
{
	LoadTranslations("gloves.phrases");
	
	g_Cvar_DBConnection = CreateConVar("sm_gloves_db_connection", "storage-local", "Database connection name in databases.cfg to use");
	g_Cvar_TablePrefix = CreateConVar("sm_gloves_table_prefix", "", "Prefix for database table (example: 'xyz_')");
	g_Cvar_ChatPrefix = CreateConVar("sm_gloves_chat_prefix", "[oyunhost.net]", "Prefix for chat messages");
	g_Cvar_EnableFloat = CreateConVar("sm_gloves_enable_float", "1", "Enable/Disable gloves float options");
	g_Cvar_FloatIncrementSize = CreateConVar("sm_gloves_float_increment_size", "0.2", "Increase/Decrease by value for gloves float");
	g_Cvar_EnableWorldModel = CreateConVar("sm_gloves_enable_world_model", "1", "Enable/Disable gloves to be seen by other living players");
	
	AutoExecConfig(true, "gloves");
	
	RegConsoleCmd("sm_glove", CommandGlove);
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	
	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say2");
	AddCommandListener(ChatListener, "say_team");

	// armfix
	/// CBaseEntity::PrecacheModel(char const*, bool)
	GameData gameData = LoadGameConfigFile("gloves.games");
	if(gameData == INVALID_HANDLE)
		SetFailState("Gamedata file gloves.games.txt is missing.");

	int offset = gameData.GetOffset("CBaseEntity::PrecacheModel");

	if(offset == -1)
	{
		SetFailState("Failed to find offset for Precache");
		delete gameData;
	}

	// StartPrepSDKCall(SDKCall_Static);

	// if(!PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CreateInterface"))
	// {
	// 	SetFailState("Failed to get CreateInterface");
	// 	delete gameData;
	// }
	
	// PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	// PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	// PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	// char identifier[64];
	// if(!GameConfGetKeyValue(gameData, "EngineInterface", identifier, sizeof(identifier)))
	// {
	// 	SetFailState("Failed to get engine identifier name");
	// 	delete gameData;
	// }
	
	// Handle temp = EndPrepSDKCall();
	// Address addr = SDKCall(temp, identifier, 0);
	
	// delete gameData;
	// delete temp;
	
	// if(!addr)
	// 	SetFailState("Failed to get engine ptr");
	
	// PrintToServer("aaaaaaaaaaa:%d", offset);
	// Dhook_PrecacheModel = DHookCreate(offset, HookType_Raw, ReturnType_Int, ThisPointer_Ignore, DHook_PrecacheModelCallback);
	// DHookAddParam(Dhook_PrecacheModel, HookParamType_CharPtr);
	// DHookAddParam(Dhook_PrecacheModel, HookParamType_Bool);
	// DHookRaw(Dhook_PrecacheModel, false, addr);
	Address addr = fnCreateEngineInterface(gameData, "EngineInterface");
	if (addr == Address_Null) {
		SetFailState("Failed to get interface for \"VEngineServer023\"");
	}

	Dhook_PrecacheModel = DHookCreate(offset, HookType_Raw, ReturnType_Int, ThisPointer_Ignore, WeaponDHookOnPrecacheModel);
	if (!Dhook_PrecacheModel) {
		SetFailState("Failed to setup hook for \"PrecacheModel\"");
	}
	DHookAddParam(Dhook_PrecacheModel, HookParamType_CharPtr);
	DHookAddParam(Dhook_PrecacheModel, HookParamType_Bool);
	DHookRaw(Dhook_PrecacheModel, false, addr);
}

stock Address fnCreateEngineInterface(GameData gameConf, char[] sKey, Address pAddress = Address_Null) 
{
    // Initialize intercace call
    static Handle hInterface = null;
    if (hInterface == null) 
    {
        // Starts the preparation of an SDK call
        StartPrepSDKCall(SDKCall_Static);
        PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "CreateInterface");

        // Adds a parameter to the calling convention. This should be called in normal ascending order
        PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWNULL);
        PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

        // Validate call
        if ((hInterface = EndPrepSDKCall()) == null)
        {
            return Address_Null;
        }
    }

    // Gets the value of a key from a config
    static char sInterface[128];
    fnInitGameConfKey(gameConf, sKey, sInterface, sizeof(sInterface));

    // Gets the address of a given interface and key
    Address pInterface = SDKCall(hInterface, sInterface, pAddress);
    if (pInterface == Address_Null) 
    {
        return Address_Null;
    }

    // Return on the success
    return pInterface;
}

stock void fnInitGameConfKey(GameData gameConf, char[] sKey, char[] sIdentifier, int iMaxLen)
{
    // Validate key
    if (!gameConf.GetKeyValue(sKey, sIdentifier, iMaxLen)) 
    {
    }
}


public void OnConfigsExecuted()
{
	GetConVarString(g_Cvar_DBConnection, g_DBConnection, sizeof(g_DBConnection));
	GetConVarString(g_Cvar_TablePrefix, g_TablePrefix, sizeof(g_TablePrefix));
	
	if(g_DBConnectionOld[0] != EOS && strcmp(g_DBConnectionOld, g_DBConnection) != 0 && db != null)
	{
		delete db;
		db = null;
	}
	
	if(db == null)
	{
		Database.Connect(SQLConnectCallback, g_DBConnection);
	}
	
	strcopy(g_DBConnectionOld, sizeof(g_DBConnectionOld), g_DBConnection);
	
	g_Cvar_ChatPrefix.GetString(g_ChatPrefix, sizeof(g_ChatPrefix));
	g_iEnableFloat = g_Cvar_EnableFloat.IntValue;
	g_fFloatIncrementSize = g_Cvar_FloatIncrementSize.FloatValue;
	g_iFloatIncrementPercentage = RoundFloat(g_fFloatIncrementSize * 100.0);
	g_iEnableWorldModel = g_Cvar_EnableWorldModel.IntValue;
	ReadConfig();
}

public Action CommandGlove(int client, int args)
{
	if (IsPlayer(client))
	{
		CreateMainMenu(client).Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	if(IsPlayer(client))
	{
		char steam32[20];
		char temp[20];
		GetClientAuthId(client, AuthId_Steam3, steam32, sizeof(steam32));
		strcopy(temp, sizeof(temp), steam32[5]);
		int index;
		if((index = StrContains(temp, "]")) > -1)
		{
			temp[index] = '\0';
		}
		g_iSteam32[client] = StringToInt(temp);
		GetPlayerData(client);
	}
}


public void GivePlayerGloves(int client)
{
	int playerTeam = GetClientTeam(client);
	

	if(g_iGloves[client][playerTeam] != 0)
	{
		int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
		if(ent != -1)
		{
			AcceptEntityInput(ent, "KillHierarchy");
		}
		char buffer[20];
		char buffers[2][10];
		int group = g_iGroup[client][playerTeam];
		int glove = g_iGloves[client][playerTeam];
		if (glove == -1)
		{
			GetRandomSkin(client, buffer, sizeof(buffer), group);
			ExplodeString(buffer, ";", buffers, 2, 10);
			group = StringToInt(buffers[0]);
			glove = StringToInt(buffers[1]);
		}

		if (IsCustomGlove(glove))
		{
			char key[128];
			char model[255];
			IntToString(glove, key, sizeof(key));
			g_CustomGloveModel.GetString(key, model, sizeof(model));
			if (model[0])
			{
				SetEntPropString(client, Prop_Send, "m_szArmsModel", model);
			}
			else
			{
				SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/weapons/t_arms.mdl");
			}

			if(g_iEnableWorldModel) SetEntProp(client, Prop_Send, "m_nBody", 0);
		}
		else
		{
			FixCustomArms(client);
			ent = CreateEntityByName("wearable_item");
			if(ent != -1)
			{
				SetEntProp(ent, Prop_Send, "m_iItemIDLow", -1);
				SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", group);
				SetEntProp(ent, Prop_Send,  "m_nFallbackPaintKit", glove);
				if (g_iSeed[client][playerTeam] != -1)
				{
					SetEntProp(ent, Prop_Send, "m_nFallbackSeed", g_iSeed[client][playerTeam]);
				}
				else
				{
					g_iSeedRandom[client][playerTeam] = GetRandomInt(0, 8192);
					SetEntProp(ent, Prop_Send, "m_nFallbackSeed", g_iSeedRandom[client][playerTeam]);
				}
				SetEntPropFloat(ent, Prop_Send, "m_flFallbackWear", g_fFloatValue[client][playerTeam]);
				SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
				SetEntPropEnt(ent, Prop_Data, "m_hParent", client);
				if(g_iEnableWorldModel) SetEntPropEnt(ent, Prop_Data, "m_hMoveParent", client);
				SetEntProp(ent, Prop_Send, "m_bInitialized", 1);
				
				DispatchSpawn(ent);
				
				SetEntPropEnt(client, Prop_Send, "m_hMyWearables", ent);
				if(g_iEnableWorldModel) SetEntProp(client, Prop_Send, "m_nBody", 1);
			}
		}
	}
	else
	{
		int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
		if(ent == -1)
		{
			SetEntProp(client, Prop_Send, "m_nBody", 0);
			SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/weapons/t_arms.mdl");
		}
	}
}

public Action ResetGlovesTimer2(Handle timer, DataPack pack)
{
	char model[128];
	ResetPack(pack);
	int clientIndex = pack.ReadCell();
	int activeWeapon = pack.ReadCell();
	pack.ReadString(model, 128);
	
	if(IsClientInGame(clientIndex))
	{
		SetEntPropString(clientIndex, Prop_Send, "m_szArmsModel", model);
		
		if(IsValidEntity(activeWeapon)) SetEntPropEnt(clientIndex, Prop_Send, "m_hActiveWeapon", activeWeapon);
	}
}

public Action RemoveItemTimer(Handle timer, any ref)
{
	int client = EntRefToEntIndex(ref);
	
	if (client != INVALID_ENT_REFERENCE)
	{
		int item = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if (item > 0)
		{
			RemovePlayerItem(client, item);
			
			Handle ph=CreateDataPack();
			WritePackCell(ph, EntIndexToEntRef(client));
			WritePackCell(ph, EntIndexToEntRef(item));
			CreateTimer(0.15 , AddItemTimer, ph, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action AddItemTimer(Handle timer, any ph)
{  
	int client, item;
	
	ResetPack(ph);
	
	client = EntRefToEntIndex(ReadPackCell(ph));
	item = EntRefToEntIndex(ReadPackCell(ph));
	
	if (client != INVALID_ENT_REFERENCE && item != INVALID_ENT_REFERENCE)
	{
		EquipPlayerWeapon(client, item);
	}
}

public void OnMapStart()
{
	Precache();
	AddDownloads();
}

void Precache()
{
	if (g_CustomGloveModel == null) return;

	StringMapSnapshot snapshot = g_CustomGloveModel.Snapshot();
	int length = snapshot.Length;

	char key[128];
	char model[255];
	for (int i = 0; i < length; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));
		g_CustomGloveModel.GetString(key, model, sizeof(model));
		
		PrecacheModel(model);
	}

	PrecacheModel("models/weapons/t_arms.mdl");
}

void AddDownloads()
{
	char line[255];
	
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/gloves/downloads.ini");
	
	File file = OpenFile(configPath, "r");
	
	if(file != INVALID_HANDLE)
	{
		while (!IsEndOfFile(file))
		{
			if (!ReadFileLine(file, line, sizeof(line)))
			{
				break;
			}
			
			TrimString(line);
			if (strlen(line) > 0 && FileExists(line))
			{
				AddFileToDownloadsTable(line);
			}
		}

		CloseHandle(file);
	}
	else
	{
		LogError("[SM] no file found for downloads : %s", configPath);
	}
}