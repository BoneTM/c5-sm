#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

Handle g_SDKAttributeSetOrAddByName;

public void OnPluginStart() {
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x89\xE5\x57\x56\x53\x83\xEC\x5C\x8B\x55\x08\x89\x55\xBC", 15);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_SDKAttributeSetOrAddByName = EndPrepSDKCall();
	
	RegAdminCmd("sm_sticker", ApplySticker, ADMFLAG_ROOT);
}

public Action ApplySticker(int client, int argc) {
	// int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	// if (!IsValidEntity(weapon)) {
		// return Plugin_Handled;
	// }
	
	int weapon = GivePlayerItem(client, "weapon_ak47");
	AddAttribute(weapon, "sticker slot 0 id", view_as<float>(70));
	AddAttribute(weapon, "sticker slot 0 wear", 0.3);
	AddAttribute(weapon, "sticker slot 0 scale", 1.0);
	AddAttribute(weapon, "sticker slot 0 rotation", 1.0);
	AddAttribute(weapon, "sticker slot 1 id", view_as<float>(70));
	AddAttribute(weapon, "sticker slot 1 wear", 0.3);
	AddAttribute(weapon, "sticker slot 1 scale", 1.0);
	AddAttribute(weapon, "sticker slot 1 rotation", 1.0);
	AddAttribute(weapon, "sticker slot 2 id", view_as<float>(70));
	AddAttribute(weapon, "sticker slot 2 wear", 0.3);
	AddAttribute(weapon, "sticker slot 2 scale", 1.0);
	AddAttribute(weapon, "sticker slot 2 rotation", 1.0);
	AddAttribute(weapon, "sticker slot 3 id", view_as<float>(70));
	AddAttribute(weapon, "sticker slot 3 wear", 0.3);
	AddAttribute(weapon, "sticker slot 3 scale", 1.0);
	AddAttribute(weapon, "sticker slot 3 rotation", 1.0);
	AddAttribute(weapon, "sticker slot 4 id", view_as<float>(70));
	AddAttribute(weapon, "sticker slot 4 wear", 0.3);
	AddAttribute(weapon, "sticker slot 4 scale", 1.0);
	AddAttribute(weapon, "sticker slot 4 rotation", 1.0);
	SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner", -1);
	
	return Plugin_Handled;
}

void AddAttribute(int entity, const char[] name, float value) {
	int offs_AttributeList = FindSendPropInfo("CEconEntity", "m_NetworkedDynamicAttributesForDemos");
	if (!HasEntProp(entity, Prop_Send, "m_NetworkedDynamicAttributesForDemos")) {
		ThrowError("Property m_NetworkedDynamicAttributesForDemos not found on entity %d", entity);
	}
	
	SDKCall(g_SDKAttributeSetOrAddByName, GetEntityAddress(entity) + view_as<Address>(offs_AttributeList), name, value);
}
