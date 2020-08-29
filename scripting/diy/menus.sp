Menu CreateMainMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Main);
	menu.SetTitle("个性化系统");
	
	int index = 2;
	
	if (IsPlayerAlive(client))
	{
		char weaponClass[32];
		char weaponName[32];
		
		int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	
		for (int i = 0; i < size; i++)
		{
			int weaponEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
			if(weaponEntity != -1 && GetWeaponClass(weaponEntity, weaponClass, sizeof(weaponClass)))
			{
				int team = GetClientTeam(client);
				Format(weaponName, sizeof(weaponName), "%T", weaponClass, client);
				// menu.AddItem(weaponClass, weaponName, (IsKnifeClass(weaponClass) && g_iKnife[client][team] == 0) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
				AddMenuOption(weaponClass, weaponName);
				index++;
			}
		}
	}
	
	for(int i = index; i < 6; i++)
	{
		menu.AddItem("", "", ITEMDRAW_SPACER);
	}
}

public int MenuHandler_Main(Menu menu, MenuAction action, int client, int selection)
{
    return 0;
}