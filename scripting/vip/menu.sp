Menu CreateVipMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Vip);

	char time[128];
	FormatTime(time, sizeof(time), "%H:%M:%S", g_VipTime[client]);
	AddMenuTitle(menu, "VIP菜单||到期时间:%s", time);

	AddMenuOption(menu, "use", "使用激活码");
	return menu;
}

public int MenuHandler_Vip(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsClientInGame(client))
			{
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}