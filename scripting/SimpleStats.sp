#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "queijocoalho"
#define PLUGIN_VERSION "1.3"

#define PREFIX "\x05[SimpleStats]\x01"

// === MySQL === //
Database DBSQL = null;

//#pragma newdecls required 

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <simplestats>

enum PlayerStats
{
	 Kills,
	 Deaths,
	 Shots,
	 Hits,
	 Headshots,
	 Assists,
	 Playtime
} 

int g_Stats[MAXPLAYERS + 1][PlayerStats];
// new g_Stats[MAXPLAYERS + 1][PlayerStats];


int RemoveClient[MAXPLAYERS + 1];

// === ConVars === //
ConVar PluginEnabled;
ConVar MinimumPlayers;
ConVar WarmUP;
ConVar CountKnife;
ConVar EnabledTop;
ConVar TopLimit;

public Plugin myinfo = 
{
	name = "[CS:GO - queijocoalho] Simple Stats", 
	author = PLUGIN_AUTHOR, 
	description = "Realy simple stats plugin.", 
	version = PLUGIN_VERSION, 
	url = "keepomod.com"
};

public void OnPluginStart()
{
	// === Admin Commands === //
	RegAdminCmd("sm_ssreset", Cmd_ResetPlayer, ADMFLAG_ROOT, "Command for flag z to reset player stats");
	
	// === Player Commands === //
	RegConsoleCmd("sm_stats", Cmd_Stats, "Command for client to open menu with his stats.");
	
	RegConsoleCmd("sm_top", Cmd_Top, "Command for client to open menu with top kills x players.");
	
		// === Events === //
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	// === ConVars && More === //
	PluginEnabled = CreateConVar("sm_ss_enabled", "1", "Sets whether or not to record stats");
	MinimumPlayers = CreateConVar("sm_ss_minplayers", "4", "Minimum players to start record stats");
	WarmUP = CreateConVar("sm_ss_warmup", "1", "Record stats while we are in warmup ?");
	CountKnife = CreateConVar("sm_ss_countknife", "1", "Record knife as shot when client slash ?");
	EnabledTop = CreateConVar("sm_ss_topenabled", "1", "Enable the menu with top players?");
	TopLimit = CreateConVar("sm_ss_toplimit", "10", "Amount of people to display on sm_top");
	
	SQL_StartConnection();
	
	AutoExecConfig(true, "sm_simplestats");
	
	for (int i = 0; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsClientAuthorized(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
	
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("SS_GetKillsAmount", Native_GetKillsAmount);
	CreateNative("SS_GetDeathsAmount", Native_GetDeathsAmount);
	CreateNative("SS_GetShotsAmount", Native_GetShotsAmount);
	CreateNative("SS_GetHitsAmount", Native_GetHitsAmount);
	CreateNative("SS_GetHeadshotsAmount", Native_GetHSAmount);
	CreateNative("SS_GetAssistsAmount", Native_GetAssistsAmount);
	CreateNative("SS_GetPlayTimeAmount", Native_GetPlayTimeAmount);
	
	RegPluginLibrary("simplestats");
	
	
	return APLRes_Success;
}

void SQL_StartConnection()
{
	if (!PluginEnabled.BoolValue)
		return;

	if (DBSQL != null)
		delete DBSQL;
	
	char Error[255];
	if (SQL_CheckConfig("simplestats"))
	{
		DBSQL = SQL_Connect("simplestats", true, Error, 255);
		
		if (DBSQL == null)
		{
			SetFailState("[SS] Error on start. Reason: %s", Error);
		}
	}
	else
	{
		SetFailState("[SS] Cant find `simplestats` on database.cfg");
	}
	
	DBSQL.SetCharset("utf8");
	
	char Query[1024];
	FormatEx(Query, 1024, "CREATE TABLE IF NOT EXISTS `players` (`steamid` VARCHAR(64) NOT NULL, `name` VARCHAR(128), `ip` VARCHAR(64), `kills` INT(11) NOT NULL DEFAULT 0, `deaths` INT(11) NOT NULL DEFAULT 0, `shots` INT(11) NOT NULL DEFAULT 0, `hits` INT(11) NOT NULL DEFAULT 0, `headshots` INT(11) NOT NULL DEFAULT 0, `assists` INT(11) NOT NULL DEFAULT 0, `secsonserver` INT(20) NOT NULL DEFAULT 0, `lastconn` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`steamid`))");
	if (!SQL_FastQuery(DBSQL, Query))
	{
		SQL_GetError(DBSQL, Error, 255);
		LogError("[SS] Cant create table. Error : %s", Error);
	}
}

stock bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		return true;
	}
	return false;
}

stock int GetPlayersCount()
{
	int count = 0;
	for (int i = 0; i < MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			count++;
		}
	}
	return count;
}

stock bool InWarmUP()
{
	return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

public void Event_RoundEnd(Event e, const char[] name, bool dontBroadcast)
{
	if (!PluginEnabled.BoolValue)
	{
		return;
	}
	
	if (DBSQL == null)
	{
		return;
	}
	
	for (int i = 0; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			FuckingUpdateThatSHITHeadPlayer(i, GetClientTime(i));
		}
	}
}

void FuckingUpdateThatSHITHeadPlayer(int client, float timeonserver)
{
	if (!PluginEnabled.BoolValue)
	{
		return;
	}
	if (DBSQL == null)
	{
		return;
	}
	
	char SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, SteamID64, 32))
	{
		return;
	}
	
	
	int Seconds = RoundToNearest(timeonserver);
	
	char Query[512];
	FormatEx(Query, 512, "UPDATE `players` SET `kills`= %d,`deaths`= %d,`shots`= %d,`hits`= %d,`headshots`= %d,`assists`= %d, `secsonserver` = secsonserver + %d WHERE `steamid` = '%s';", g_Stats[client][Kills], g_Stats[client][Deaths], g_Stats[client][Shots], g_Stats[client][Hits], g_Stats[client][Headshots], g_Stats[client][Assists], Seconds, SteamID64);
	DBSQL.Query(SQL_UpdatePlayer_Callback, Query, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_UpdatePlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SS] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SS] SQL_UpdatePlayer_Callback(): Cant use client %N data. Reason: %s", client, error);
		}
		return;
	}
}

public void Event_PlayerDeath(Event e, const char[] name, bool dontBroadcast)
{
	if (!PluginEnabled.BoolValue)
	{
		return;
	}
	
	if (DBSQL == null)
	{
		return;
	}
	
	if (GetPlayersCount() < MinimumPlayers.IntValue)
	{
		return;
	}
	
	if (InWarmUP() && !WarmUP.BoolValue)
	{
		return;
	}
	
	//Check shit
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
	bool headshot = GetEventBool(e, "headshot");
	int assister = GetClientOfUserId(GetEventInt(e, "assister"));
	
	if (!IsValidClient(client) || !IsValidClient(attacker))
	{
		return;
	}
	
	if (attacker == client)
	{
		return;
	}
	
	//Player Stats//
	g_Stats[attacker][Kills]++;
	g_Stats[client][Deaths]++;
	if (headshot)
		g_Stats[attacker][Headshots]++;
	
	if (assister)
		g_Stats[assister][Assists]++;
}

public void Event_WeaponFire(Event e, const char[] name, bool dontBroadcast)
{
	if (!PluginEnabled.BoolValue)
	{
		return;
	}
	if (DBSQL == null)
	{
		return;
	}
	
	if (GetPlayersCount() < MinimumPlayers.IntValue)
	{
		return;
	}
	
	if (InWarmUP() && !WarmUP.BoolValue)
	{
		return;
	}
	
	char FiredWeapon[32];
	GetEventString(e, "weapon", FiredWeapon, sizeof(FiredWeapon));
	
	if (StrEqual(FiredWeapon, "hegrenade") || StrEqual(FiredWeapon, "flashbang") || StrEqual(FiredWeapon, "smokegrenade") || StrEqual(FiredWeapon, "molotov") || StrEqual(FiredWeapon, "incgrenade") || StrEqual(FiredWeapon, "decoy"))
	{
		return;
	}
	
	if (!CountKnife.BoolValue && StrEqual(FiredWeapon, "weapon_knife"))
	{
		return;
	}
	
	//Check shit
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	if (!IsValidClient(client))
	{
		return;
	}
	
	//Player Stats//
	g_Stats[client][Shots]++;
}

public void Event_PlayerHurt(Event e, const char[] name, bool dontBroadcast)
{
	if (!PluginEnabled.BoolValue)
	{
		return;
	}
	
	if (DBSQL == null)
	{
		return;
	}
	
	if (GetPlayersCount() < MinimumPlayers.IntValue)
	{
		return;
	}
	
	if (InWarmUP() && !WarmUP.BoolValue)
	{
		return;
	}
	
	//Check shit
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
	
	if (!IsValidClient(client) || !IsValidClient(attacker))
	{
		return;
	}
	
	int ClientTeam = GetClientTeam(client);
	int AttackerTeam = GetClientTeam(attacker);
	
	if (ClientTeam != AttackerTeam)
	{
		//Player Stats//
		g_Stats[attacker][Hits]++;
	}
}

public int AreYouSureHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(item, info, 32);
		
		if (StrEqual(info, "yes"))
		{
			int target = GetClientFromSerial(RemoveClient[client]);
			
			char SteamID64[32];
			if (!GetClientAuthId(target, AuthId_SteamID64, SteamID64, 32))
			{
				return 0;
			}
			char Query[512];
			FormatEx(Query, 512, "DELETE FROM `players` WHERE `steamid` = '%s'", SteamID64);
			DBSQL.Query(SQL_RemovePlayer_Callback, Query, GetClientSerial(client), DBPrio_Normal);
		}
	}
	if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

public void SQL_RemovePlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SS] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SS] SQL_RemovePlayer_Callback(): Cant use client %N data. Reason: %s", GetClientFromSerial(RemoveClient[client]), error);
		}
		return;
	}
	
	CPrintToChat(client, "%s You have been reset \x07%N's\x01 stats.", PREFIX, GetClientFromSerial(RemoveClient[client]));
	OnClientPostAdminCheck(GetClientFromSerial(RemoveClient[client]));
	RemoveClient[client] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}
	
	if (!PluginEnabled.BoolValue)
	{
		return;
	}
	
	if (DBSQL == null)
	{
		return;
	}
	
	char SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, SteamID64, 32))
	{
		KickClient(client, "Verification problem, please reconnect.");
		return;
	}

	char PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, PlayerName, MAX_NAME_LENGTH);
	
	//escaping name , dynamic array;
	int iLength = ((strlen(PlayerName) * 2) + 1);
	char[] EscapedName = new char[iLength];
	DBSQL.Escape(PlayerName, EscapedName, iLength);
	
	char ClientIP[64];
	GetClientIP(client, ClientIP, 64);
	
	char Query[512];
	FormatEx(Query, 512, "INSERT INTO `players` (`steamid`, `name`, `ip`) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE `name` = '%s', `ip` = '%s';", SteamID64, EscapedName, ClientIP, EscapedName, ClientIP);
	DBSQL.Query(SQL_InsertPlayer_Callback, Query, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_InsertPlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SS] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SS] SQL_InsertPlayer_Callback(): Cant use client %N data. Reason: %s", client, error);
		}
		return;
	}
	
	char SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, SteamID64, 32))
	{
		return;
	}
	
	
	char Query[512];
	char Query2[512];
	
	FormatEx(Query, 512, "SELECT kills, deaths, shots, hits, headshots, assists, secsonserver FROM `players` WHERE `steamid` = '%s'", SteamID64);
	DBSQL.Query(SQL_SelectPlayer_Callback, Query, GetClientSerial(client), DBPrio_Normal);
	
	FormatEx(Query2, 512, "UPDATE `players` SET `lastconn`= CURRENT_TIMESTAMP() WHERE `steamid` = '%s';", SteamID64);
	DBSQL.Query(SQL_UpdatePlayer2_Callback, Query2, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_SelectPlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SS] Selecting player error. Reason: %s", error);
		return;
	}
	
	int client = GetClientFromSerial(data);
	if (client == 0)
	{
		LogError("[SS] Client is not valid. Reason: %s", error);
		return;
	}
	
	while (results.FetchRow())
	{
		g_Stats[client][Kills] = results.FetchInt(0);
		g_Stats[client][Deaths] = results.FetchInt(1);
		g_Stats[client][Shots] = results.FetchInt(2);
		g_Stats[client][Hits] = results.FetchInt(3);
		g_Stats[client][Headshots] = results.FetchInt(4);
		g_Stats[client][Assists] = results.FetchInt(5);
		g_Stats[client][Playtime] = results.FetchInt(6);
	}
}

public void SQL_UpdatePlayer2_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	if (results == null)
	{
		if (client == 0)
		{
			LogError("[SS] Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("[SS] SQL_UpdatePlayer2_Callback(): Cant use client %N data. Reason: %s", client, error);
		}
		return;
	}
}

stock int SecondsToTime(int seconds, char[] buffer)
{
	int mins, secs;
	if (seconds >= 60)
	{
		mins = RoundToFloor(float(seconds / 60));
		seconds = seconds % 60;
	}
	secs = RoundToFloor(float(seconds));
	
	if (mins)
		Format(buffer, 70, "%s%d mins, ", buffer, mins);
	
	Format(buffer, 70, "%s%d secs", buffer, secs);
}

void OpenStatsMenu(int client, int displayto)
{
	Menu menu = new Menu(Stats_MenuHandler);
	
	char PlayerName[MAX_NAME_LENGTH];
	GetClientName(client, PlayerName, MAX_NAME_LENGTH);
	char Title[32];
	FormatEx(Title, 32, "%s's stats :", PlayerName);
	menu.SetTitle(Title);
	
	char c_Kills[128], c_Deaths[128], c_Shots[128], c_Hits[128], c_HS[128], c_Assists[128], c_PlayTime[258], c_PlayTime2[128];
	int Seconds = RoundToZero(GetClientTime(client));
	int CurrentTime = Seconds + g_Stats[client][Playtime];
	SecondsToTime(CurrentTime, c_PlayTime2);
	
	int Accuracy = 0;
	if (g_Stats[client][Hits] != 0 && g_Stats[client][Shots] != 0)
	{
		Accuracy = (100 * g_Stats[client][Hits] + g_Stats[client][Shots] / 2) / g_Stats[client][Shots];
	}
	
	int HSP = 0;
	if (g_Stats[client][Hits] != 0 && g_Stats[client][Headshots] != 0)
	{
		HSP = (100 * g_Stats[client][Hits] + g_Stats[client][Headshots] / 2) / g_Stats[client][Headshots];
	}
	
	FormatEx(c_Kills, 128, "Your total kills : %d", g_Stats[client][Kills]);
	FormatEx(c_Deaths, 128, "Your total deaths : %d", g_Stats[client][Deaths]);
	FormatEx(c_Shots, 128, "Your total shots : %d", g_Stats[client][Shots]);
	FormatEx(c_Hits, 128, "Your total hits : %d (Accuracy : %d%%%)", g_Stats[client][Hits], Accuracy);
	FormatEx(c_HS, 128, "Your total headshots : %d (HS Percent : %d%%%)", g_Stats[client][Headshots], HSP);
	FormatEx(c_Assists, 128, "Your total assists : %d", g_Stats[client][Assists]);
	FormatEx(c_PlayTime, 128, "Play time : %s", c_PlayTime2);
	
	menu.AddItem("", c_Kills, ITEMDRAW_DISABLED);
	menu.AddItem("", c_Deaths, ITEMDRAW_DISABLED);
	menu.AddItem("", c_Shots, ITEMDRAW_DISABLED);
	menu.AddItem("", c_Hits, ITEMDRAW_DISABLED);
	menu.AddItem("", c_HS, ITEMDRAW_DISABLED);
	menu.AddItem("", c_Assists, ITEMDRAW_DISABLED);
	menu.AddItem("", c_PlayTime, ITEMDRAW_DISABLED);
	
	menu.ExitButton = true;
	menu.Display(displayto, 30);
}

public int Stats_MenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public void SQL_SelectTop_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SS] Selecting players error. Reason: %s", error);
		return;
	}
	
	int client = GetClientFromSerial(data);
	if (client == 0)
	{
		LogError("[SS] Client is not valid. Reason: %s", error);
		return;
	}
	
	Menu menu = new Menu(TopHandler);
	char Title[128];
	Format(Title, 128, "Top %d Killers", TopLimit.IntValue);
	menu.SetTitle(Title);
	
	int Count = 0;
	while (results.FetchRow())
	{
		Count++;
		
		//SteamID
		char[] SteamID = new char[32];
		results.FetchString(0, SteamID, 32);
		
		
		//Player Name
		char[] PlayerName = new char[MAX_NAME_LENGTH];
		results.FetchString(1, PlayerName, MAX_NAME_LENGTH);
		
		//Kills
		int i_Kills = results.FetchInt(2);
		
		char MenuContent[128];
		FormatEx(MenuContent, 128, "%d - %s (%d kill%s)", Count, PlayerName, i_Kills, i_Kills > 1 ? "s":"");
		menu.AddItem(SteamID, MenuContent);
	}
	
	if (!Count)
	{
		menu.AddItem("-1", "No results.");
	}
	
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int TopHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public Action Cmd_ResetPlayer(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if (!PluginEnabled.BoolValue)
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		CPrintToChat(client, "%s Usage : sm_ssreset <target>", PREFIX);
		return Plugin_Handled;
	}
	
	char arg1[MAX_TARGET_LENGTH];
	GetCmdArg(1, arg1, MAX_TARGET_LENGTH);
	
	int target = FindTarget(client, arg1, false, false);
	
	if (target == -1)
	{
		CPrintToChat(client, "%s Cant find target with this specific name , try to add more letters.", PREFIX);
		return Plugin_Handled;
	}
	
	RemoveClient[client] = GetClientSerial(target);
	
	Menu menu = new Menu(AreYouSureHandler);
	char PlayerName[MAX_NAME_LENGTH];
	GetClientName(target, PlayerName, MAX_NAME_LENGTH);
	char Title[32];
	FormatEx(Title, 32, "Reset %s's stats ?", PlayerName);
	menu.SetTitle(Title);
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action Cmd_Stats(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if (!PluginEnabled.BoolValue)
	{
		return Plugin_Handled;
	}
	
	char SteamID64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, SteamID64, 32))
	{
		return Plugin_Handled;
	}
	
	OpenStatsMenu(client, client);
	
	return Plugin_Handled;
}

public Action Cmd_Top(int client, int args)
{
	if (!EnabledTop.BoolValue)
	{
		return Plugin_Handled;
	}
	
	char Query[512];
	
	FormatEx(Query, 512, "SELECT steamid, name, kills FROM `players` WHERE kills != 0 ORDER BY kills DESC LIMIT %d;", TopLimit.IntValue);
	DBSQL.Query(SQL_SelectTop_Callback, Query, GetClientSerial(client), DBPrio_Normal);
	
	
	return Plugin_Handled;
}

public int Native_GetKillsAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Kills];
}

public int Native_GetDeathsAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Deaths];
}

public int Native_GetShotsAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Shots];
}
public int Native_GetHitsAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Hits];
}

public int Native_GetHSAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Headshots];
}

public int Native_GetAssistsAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Assists];
}

public int Native_GetPlayTimeAmount(Handle handler, int numParams)
{
	return g_Stats[GetNativeCell(1)][Playtime];
}