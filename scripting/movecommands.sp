#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <colorlib_sample>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

public Plugin myinfo =
{
    name = "Move Commands",
    author = "Ilusion9",
    description = "Commands for moving players in CS:GO",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

TopMenu g_TopMenu;
int g_SelectedTeamInAdminMenu[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("movecommands.phrases");

	RegAdminCmd("sm_move", Command_Move, ADMFLAG_GENERIC, "sm_move <name|#userid> <t|ct|spec>");
	
	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == g_TopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	g_TopMenu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject move_commands = g_TopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (move_commands != INVALID_TOPMENUOBJECT)
	{
		g_TopMenu.AddItem("sm_move", AdminMenu_Move, move_commands, "sm_move", ADMFLAG_GENERIC);
	}
}

public void AdminMenu_Move(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Move player", param);
	}
	
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayMoveTeamMenu(param);
	}
}

void DisplayMoveTeamMenu(int client)
{
	Menu menu = new Menu(MenuHandler_MoveTeam);
	
	char buffer[100];
	Format(buffer, sizeof(buffer), "%T", "Move player to", client);
	menu.SetTitle(buffer);
	menu.ExitBackButton = true;
	
	Format(buffer, sizeof(buffer), "%T", "Move Spectators", client);
	menu.AddItem("1", buffer);
	
	Format(buffer, sizeof(buffer), "%T", "Move Terrorists", client);
	menu.AddItem("2", buffer);
	
	Format(buffer, sizeof(buffer), "%T", "Move Counter-Terrorists", client);
	menu.AddItem("3", buffer);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MoveTeam(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && g_TopMenu)
		{
			g_TopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		menu.GetItem(param2, info, sizeof(info));
		g_SelectedTeamInAdminMenu[param1] = StringToInt(info);
		
		DisplayMoveTargetMenu(param1);
	}
}

void DisplayMoveTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Move);
	char buffer[100];
	
	if (g_SelectedTeamInAdminMenu[client] == CS_TEAM_T)
	{
		Format(buffer, sizeof(buffer), "%T", "Move player to Terrorists", client);
	}
	
	else if (g_SelectedTeamInAdminMenu[client] == CS_TEAM_CT)
	{
		Format(buffer, sizeof(buffer), "%T", "Move player to Counter-Terrorists", client);
	}
	
	else
	{
		Format(buffer, sizeof(buffer), "%T", "Move player to Spectators", client);
	}
	
	menu.SetTitle(buffer);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, true);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Move(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			g_TopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	
	else if (action == MenuAction_Select)
	{
		char info[32];
		int targetId, target;
		
		menu.GetItem(param2, info, sizeof(info));
		targetId = StringToInt(info);

		if ((target = GetClientOfUserId(targetId)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		
		else if (!IsClientInGame(target))
		{
			PrintToChat(param1, "[SM] %t", "Target is not in game");
		}
		
		else
		{
			if (g_SelectedTeamInAdminMenu[param1] == CS_TEAM_T)
			{
				PerformMoveToTerrorists(param1, target);
			}
			
			else if (g_SelectedTeamInAdminMenu[param1] == CS_TEAM_CT)
			{
				PerformMoveToCounterTerrorists(param1, target);
			}
			
			else
			{
				PerformMoveToSpectators(param1, target);
			}
		}
		
		DisplayMoveTargetMenu(param1);
	}
}

public Action Command_Move(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_move <name|#userid> <t|ct|spec>");
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg);
	if (target == -1)
	{
		/* Invalid target */
		return Plugin_Handled;
	}
	
	GetCmdArg(2, arg, sizeof(arg));
	
	if (StrEqual(arg, "t", false))
	{
		PerformMoveToTerrorists(client, target);
	}
	
	else if (StrEqual(arg, "ct", false))
	{
		PerformMoveToCounterTerrorists(client, target);
	}
	
	else if (StrEqual(arg, "spec", false))
	{
		PerformMoveToSpectators(client, target);
	}
	
	else
	{
		ReplyToCommand(client, "[SM] %t", "Invalid team specified");
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

void PerformMoveToTerrorists(int client, int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	
	LogAction(client, target, "\"%L\" moved \"%L\" to Terrorists", client, target);
	CShowActivity(client, "[SM] %t", "Moved to Terrorists", name);
	
	if (IsPlayerAlive(target))
	{
		ForcePlayerSuicide(target);
	}
	
	ChangeClientTeam(target, CS_TEAM_T);
}

void PerformMoveToCounterTerrorists(int client, int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	
	LogAction(client, target, "\"%L\" moved \"%L\" to Counter-Terrorists", client, target);
	CShowActivity(client, "[SM] %t", "Moved to Counter-Terrorists", name);
	
	if (IsPlayerAlive(target))
	{
		ForcePlayerSuicide(target);
	}
	
	ChangeClientTeam(target, CS_TEAM_CT);
}

void PerformMoveToSpectators(int client, int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	
	LogAction(client, target, "\"%L\" moved \"%L\" to Spectators", client, target);
	CShowActivity(client, "[SM] %t", "Moved to Spectators", name);

	if (IsPlayerAlive(target))
	{
		ForcePlayerSuicide(target);
	}
	
	ChangeClientTeam(target, CS_TEAM_SPECTATOR);
}
