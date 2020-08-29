public MRESReturn DHook_PrecacheModelCallback(int entity, Handle hReturn, Handle hParams)
{
	char buffer[128];
	DHookGetParamString(hParams, 1, buffer, 128);
	
	if(StrContains(buffer, "models/weapons/v_models/arms/glove_hardknuckle/") != -1)
	{
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

public MRESReturn WeaponDHookOnPrecacheModel(Handle hReturn, Handle hParams)
{
    // Gets model from parameters
    static char buffer[128];
    DHookGetParamString(hParams, 1, buffer, sizeof(buffer));
    
    // Block this model for be precached
    if (!strncmp(buffer, "models/weapons/v_models/arms/glove_hardknuckle/", 47, false))
    {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    if (!strncmp(buffer, "models/weapons/v_models/arms/glove_fingerless/", 46, false))
    {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    if (!strncmp(buffer, "models/weapons/v_models/arms/glove_fullfinger/", 46, false))
    {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    if (!strncmp(buffer, "models/weapons/v_models/arms/anarchist/", 39, false))
    {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    
    
    // Skip the hook
    return MRES_Ignored;
}