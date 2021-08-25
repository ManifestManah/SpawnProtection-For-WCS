/*
-------------------------------------------------------------------------------
////////////////////////[CS:GO] Spawn Protection Module////////////////////////
-------------------------------------------------------------------------------

Code Written By Manifest @Road To Glory (c) 2021
- Have any questions? - Contact: https://steamcommunity.com/id/ManifestVisuals/

-------------------------------------------------------------------------------

I started to work on a spawn protection plugin with Warcraft-Source in mind. 
Over the years I've never quite found a spawn protection plugin that did 
exactly what I needed for my WC:S server.

This plugin is designed to combat the problem that can arise with bad level
design, where players may be able to shoot each other as soon as the freeze
time ends, leading to some players being unable to play that round as they die
just as the freeze time expires.

By editing the cfg/sourcemod/custom_SpawnProtectionModule.cfg you can easily 
change the way the plugin works to fit your server's preferences and needs.


Features:

- Protects players from all damage sources the first few seconds after a new
  round starts.

- Players will NOT be protected when taking over bots, or respawning.

- Clients can indivdually choose whether or not to see the message that is
  posted when spawn protection is disabled.

- Option: Color players while they are protected. (Enabling this is not 
  recommendable for WC:S servers)

- Option: Firing a gun or attacking with knife (both left and right) will 
  disable the player's  spawn protection.

- Option: Zooming with a weapon disables the player's spawn protection.

- Option: Disable the player's spawn protection if he uses his ability.

- Option: Disable the player's spawn protection if he uses his ultimate.


Thank you for choosing to use my plugin!
- Manifest @Road To Glory

-------------------------------------------------------------------------------
Version History:

	V. 1.0.0 [Beta] - (10/08/2021)
	- Initial release!

-------------------------------------------------------------------------------
*/


///////////////////////
// Actual Code Below //
///////////////////////


// List of Includes
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;


// Booleans
bool SpawnProtection = true;
bool IsPlayerProtected[MAXPLAYERS + 1] = {false,...};

// Integers
int PlayerSpawnCount[MAXPLAYERS+1] = {0, ...};

// Config Convars
Handle cvar_ProtectionTime;
Handle cvar_ProtectMultipleTimes;
Handle cvar_ProtectionColorEnabled;
Handle cvar_RemoveWhenAttacking;
Handle cvar_RemoveWhenZooming;
Handle cvar_RemoveWhenUsingUltimate;
Handle cvar_RemoveWhenUsingAbility;

// Cookie Related Variables
bool option_no_text[MAXPLAYERS + 1] = {true,...};
Handle cookie_show_sptext = INVALID_HANDLE;


// The retrievable information about the plugin itself 
public Plugin myinfo =
{
	name		= "[CS:GO] Spawn Protection Module",
	author		= "Manifest @Road To Glory & backwards",
	description	= "Protects players for a short duration after they spawn.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Hooks the events that we intend to use in our plugin
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
	HookEvent("weapon_zoom", Event_WeaponZoom, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);

	// The list of convars which we'll use to enable/disable features through our auto generated config file
	cvar_ProtectionTime = CreateConVar("Mani_ProtectionTime", "7.0", "Time in seconds that the player is protected for after spawning - [Default = 7.0]");
	cvar_ProtectMultipleTimes = CreateConVar("Mani_ProtectMultipleTimes", "0", "Let players be protected multiple times in one round, for example when they take over a bot or they get respawned - [1 = Yes] / [0 = No]");
	cvar_ProtectionColorEnabled = CreateConVar("Mani_ProtectionColorEnabled", "0", "Color the player while he is protected - [1 = Yes] / [0 = No]");
	cvar_RemoveWhenAttacking = CreateConVar("Mani_RemoveWhenAttacking", "1", "Firing weapons or swinging the knife removes the player's spawn protection - [1 = Yes] / [0 = No]");
	cvar_RemoveWhenZooming = CreateConVar("Mani_RemoveWhenZooming", "1", "Scoping with a weapon removes the player's spawn protection - [1 = Yes] / [0 = No]");
	cvar_RemoveWhenUsingUltimate = CreateConVar("Mani_RemoveWhenUsingUltimate", "1", "Using ultimates removes the player's spawn protection - [1 = Yes] / [0 = No]");
	cvar_RemoveWhenUsingAbility = CreateConVar("Mani_RemoveWhenUsingAbility", "1", "Using abilities removes the player's spawn protection - [1 = Yes] / [0 = No]");

	// These are cookie related and used for our client preferances
	cookie_show_sptext = RegClientCookie("Show SP Text On/Off 1", "sptext", CookieAccess_Private);
	SetCookieMenuItem(CookieMenuHandler_ShowSpawnText, cookie_show_sptext, "Show SP Text");

	// Adds the command listeners used in WC:S if the feature is enabled  
	int check_RemoveWhenUsingUltimate = GetConVarInt(cvar_RemoveWhenUsingUltimate);
	if (check_RemoveWhenUsingUltimate)
	{
		AddCommandListener(WCS_Feature, "ultimate");
	}
	int check_RemoveWhenUsingAbility = GetConVarInt(cvar_RemoveWhenUsingAbility);
	if (check_RemoveWhenUsingAbility)
	{
		AddCommandListener(WCS_Feature, "ability");
	}

	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "custom_SpawnProtectionModule");

	// Loads the multi-language translation file
	LoadTranslations("custom_SpawnProtectionModule.phrases");
}


///////////////////////////////////////
// Cookie & Client Preferance System //
///////////////////////////////////////

public void OnClientCookiesCached(int client)
{
	option_no_text[client] = GetCookieProtText(client);
}


bool GetCookieProtText(int client)
{
	char buffer[10];
	GetClientCookie(client, cookie_show_sptext, buffer, sizeof(buffer));
	
	return !StrEqual(buffer, "Off");
}


public void CookieMenuHandler_ShowSpawnText(int client, CookieMenuAction action, any SProt_Text, char[] buffer, int maxlen)
{	
	if (action == CookieMenuAction_DisplayOption)
	{
		char status[16];

		if (option_no_text[client])
		{
			Format(status, sizeof(status), "%s", "[ON]", client);
		}
		else
		{
			Format(status, sizeof(status), "%s", "[OFF]", client);
		}
		
		Format(buffer, maxlen, "Spawn Protection Text: %s", status);
	}
	else
	{
		option_no_text[client] = !option_no_text[client];
		
		if (option_no_text[client])
		{
			SetClientCookie(client, cookie_show_sptext, "On");
			CPrintToChat(client, "%t", "Spawn Protection Text Enabled");
		}
		else
		{
			SetClientCookie(client, cookie_show_sptext, "Off");
			CPrintToChat(client, "%t", "Spawn Protection Text Disabled");
		}
		
		ShowCookieMenu(client);
	}
}


//////////////////////////////////
// Warcraft-Source System Parts //
//////////////////////////////////

public Action WCS_Feature(int client, const char[] command, int argc)
{
	RemoveSpawnProtection(client);
}


/////////////////////////////////
// Remaining Parts of The Code //
/////////////////////////////////

// This happens every time a player spawns
public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the spawned player's userid and stores it within the variable client
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Checks if the player meets our client validation criteria
	if(IsValidClient(client))
	{
		// If the convar check_ProtectMultipleTimes is set to 1, then execute this section
		int check_ProtectMultipleTimes = GetConVarInt(cvar_ProtectMultipleTimes);
		if (check_ProtectMultipleTimes)
		{
			// Calls upon the function: ApplySpawnProtection
			ApplySpawnProtection(client);
		}
		// If the convar check_ProtectMultipleTimes is set to 0, then execute this section
		else
		{
			// Execute this section if the round is a warmup round 
			if (GameRules_GetProp("m_bWarmupPeriod") == 1)
			{
				// Changes the global variable SpawnProtection to true
				SpawnProtection = true;
			}

			// Execute this section if the global SpawnProtection variable is set to true
			if (SpawnProtection)
			{
				// Calls upon the function: ApplySpawnProtection
				ApplySpawnProtection(client);
			}
		}
	}
}


// This function is called upon to grant the player spawn protection
public void ApplySpawnProtection(int client)
{
	// Checks if the player meets our client validation criteria
	if(IsValidClient(client))
	{
		// If the player is alive then proceed
		if(IsPlayerAlive(client))
		{
			// Changes the SpawnProtection status of the client to be turned on
			IsPlayerProtected[client] = true;

			// Turns the player's God Mode on
			SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);

			// If the check_ProtectionColorEnabled convar is set to 1, then execute this section
			int check_ProtectionColorEnabled = GetConVarInt(cvar_ProtectionColorEnabled);
			if (check_ProtectionColorEnabled)
			{
				// Changes the rendering mode of the player
				SetEntityRenderMode(client, RENDER_TRANSCOLOR);

				// If the player is on the Terrorist team then execute this section
				if (GetClientTeam(client) == 2)
				{
					// Changes the player's color to red
					SetEntityRenderColor(client, 200, 0, 0, 255);
				}
				// If the player is on the Coutner-Terrorist team then execute this section
				if (GetClientTeam(client) == 3)
				{
					// Changes the player's color to blue
					SetEntityRenderColor(client, 0, 0, 230, 255);
				}
			}

			// Counter Per Client
			PlayerSpawnCount[client]++;
			
			// Creates a package of data and store it within our variable: pack 
			DataPack pack = new DataPack();

			// Stores the client variable within our data package variable: pack
			pack.WriteCell(client);

			// Stores the PlayerSpawnCount variable within our data package variable: pack
			pack.WriteCell(PlayerSpawnCount[client]);


			// Creates a float variable matchin our cvar_ProtectionTime convar
			float ProtectionTime = GetConVarFloat(cvar_ProtectionTime);

			// After the seconds of 7 seconds [default] then execute the RemoveSpawnProtectionTimer function
			CreateTimer(ProtectionTime, Timer_RemoveSpawnProtection, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}


// This function is called upon by our timer
public Action Timer_RemoveSpawnProtection(Handle timer, DataPack data)
{
	data.Reset();

	// Obtains data from our data package, and store it in our client variable
	int client = data.ReadCell();

	// Obtains the data from our data package, and store it in our SpawnCount variable
	int SpawnCount = data.ReadCell();
	
	// Deletes our data package now that we have acquired the information we needed from it
	delete data;
	
	// If the player doesn't meet our validation criteria then stop the plugin
	if(!IsValidClient(client))
		return Plugin_Stop;
	
	// If the spawncount variable is anything else than the spawncount variable were when the timer started then execute this section
	if(SpawnCount != PlayerSpawnCount[client])
	{
		return Plugin_Stop;
	}

	// Calls upon the function: RemoveSpawnProtection
	RemoveSpawnProtection(client);

	return Plugin_Stop;
}


// We call upon this function in multiple cases for turning off the player's spawn protection
public void RemoveSpawnProtection(int client)
{
	// Checks if the player meets our client validation criteria
	if(IsValidClient(client))
	{
		// If the player is spawn protected then execute this section
		if(IsPlayerProtected[client])
		{
			// Changes the SpawnProtection status of the client to be turned off
			IsPlayerProtected[client] = false;

			// Turns the player's God Mode off
			SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);

			// If the check_ProtectionColorEnabled convar is set to 1, then execute this section
			int check_ProtectionColorEnabled = GetConVarInt(cvar_ProtectionColorEnabled);
			if (check_ProtectionColorEnabled)
			{
				// Changes the player's color to the default color 
				SetEntityRenderColor(client, 255, 255, 255, 255);
			}

			// If the player's preferance for Spawn Protection Turned is set to enabled then execute this section
			if(option_no_text[client])
			{
				// Displays a text message to the player, letting him know when the spawn protection is turned off
				ShowHudMsg(client, "Your Spawn Protection Was Disabled", 0.3650, 0.3750, 255, 255, 255, 125, 3, false, false);
			}
		}
	}
}


// This is executed everytime the player zooms
public Action Event_WeaponZoom(Handle event, const char[] weaponName, bool dontBroadcast)
{
	// If the convar cvar_RemoveWhenZooming is set to 1 then execute this section
	int check_RemoveWhenZooming = GetConVarInt(cvar_RemoveWhenZooming);
	if (check_RemoveWhenZooming)
	{
		// Obtains the player's userid and stores it within the variable: client
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		// Checks if the player meets our client validation criteria
		if(IsValidClient(client))
		{
			// If the player is spawn protected then execute this section
			if(IsPlayerProtected[client])
			{	
				// Calls upon the function: RemoveSpawnProtection
				RemoveSpawnProtection(client);
			}
		}
	}
}


// This section is executed everytime the player fires a weapon or left attacks with his knife
public Action Event_WeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	// If the convar cvar_RemoveWhenAttacking is set to 1 then execute this section
	int check_RemoveWhenAttacking = GetConVarInt(cvar_RemoveWhenAttacking);
	if (check_RemoveWhenAttacking)
	{
		// Obtains the player's userid and stores it within the variable: client
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		// Checks if the player meets our client validation criteria
		if(IsValidClient(client))
		{
			// If the player is spawn protected then execute this section
			if(IsPlayerProtected[client])
			{
				// Calls upon the function: RemoveSpawnProtection
				RemoveSpawnProtection(client);
			}
		}
	}
}


// This section is executed whenever a plyaer presses a button - Thank you for the help backwards! (^.^)
public Action OnPlayerRunCmd(int client, int &buttons) 
{
	// Checks if the player meets our client validation criteria
	if(IsValidClient(client))
	{
		// If the player is spawn protected then execute this section
		if(IsPlayerProtected[client])
		{
			// If the player is alive then proceed
			if(IsPlayerAlive(client))
			{
				// Obtains the client's active weapon and store it within the variable: weapon
				int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if (weapon != -1)
				{
					// Obtains the player's weapon based on weapon slot
					int knife_weapon = GetPlayerWeaponSlot(client, 2);
					if(knife_weapon != -1)
					{
						// if the weapon that is used is a knife and the player uses right click then execute this
						if(knife_weapon == weapon && buttons & IN_ATTACK2)
						{
							// Calls upon the function: RemoveSpawnProtection
							RemoveSpawnProtection(client);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue; 
} 


// This Occurs whenever the round ends 
public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	// If the convar cvar_ProtectMultipleTimes is set to 1 then execute this section
	int check_ProtectMultipleTimes = GetConVarInt(cvar_ProtectMultipleTimes);
	if (!check_ProtectMultipleTimes)
	{
		// Changes the global spawnprotection status to true
		SpawnProtection = true;
	}
}


// This happens whenever a new round starts
public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// If the convar cvar_ProtectMultipleTimes is set to 1 then execute this section
	int check_ProtectMultipleTimes = GetConVarInt(cvar_ProtectMultipleTimes);
	if (!check_ProtectMultipleTimes)
	{
		// Changes the global spawnprotection status to false
		SpawnProtection = false;
	}
}


// We call upon this true and false statement whenever we wish to validate our player
bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}


// We call upon this function when we wish to display the hud text in the middle of the screen - Thank you for the help backwards! (^.^)
void ShowHudMsg(int client, const char[] message, float x, float y, int r, int g, int b, int a, int channel, bool flash, bool past = false)
{
	float holdtime = 2.5;

	if(past)
		holdtime = 2.5;

	if(channel == 3)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
}