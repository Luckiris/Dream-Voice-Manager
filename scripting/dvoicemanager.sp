#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <basecomm>
#include <voiceannounce_ex>

#pragma newdecls required

/* global variables */
int gVoiceStamina[MAXPLAYERS + 1];
Handle gIsTalking[MAXPLAYERS + 1];

/* Convars of the plugin */
ConVar cvStamina;
ConVar cvMute;

public Plugin myinfo = 
{
	name = "Dream - Voice manager",
	author = "Luckiris",
	description = "Mute people after speaking for a few seconds",
	version = "1.0",
	url = "https://dream-community.de/"
};

public void OnPluginStart()
{
	/* Translation file */ 
	LoadTranslations("dvoice.phrases");
	
	/* Cvars of the plugin */
	cvStamina = CreateConVar("sm_dvoice_stamina", "10", "Number of seconds a client can talk before being muted");
	cvMute = CreateConVar("sm_dvoice_mute_time", "5.0", "Number of seconds a client should be muted");
	
	/* Execute config file */
	AutoExecConfig(true, "dvoice");
}

public void OnClientSpeakingEx(int client)
{
	/*	When a client is speaking for the first time, we create a timer to update the his stamina

		IF client is an admin, then no timer
	*/
	if (!IsFakeClient(client) && gIsTalking[client] == null && !IsAdmin(client, ADMFLAG_BAN))
	{
		gIsTalking[client] = CreateTimer(1.0, TimerUpdateVoiceStamina, GetClientUserId(client), TIMER_REPEAT);
	}
}

public void OnClientSpeakingEnd(int client)
{
	/*	When a client stop talking, the other timer will be auto-killed by itself and we create a timer
		to reload the stamina of the client
		
		IF client is an admin, then no timer
	*/
	if (IsValidClient(client) && !IsFakeClient(client) && !IsAdmin(client, ADMFLAG_BAN))
	{
		CreateTimer(1.0, TimerReloadVoiceStamina, GetClientUserId(client), TIMER_REPEAT);
		gIsTalking[client] = null;
	}	
}

public Action TimerUpdateVoiceStamina(Handle timer, any userid)
{
	/*	Timer for updating the stamina of the client when he is talking

	*/
	Action result = Plugin_Stop; // <- Timer stop by itself by default to prevent any problem
	int client = GetClientOfUserId(userid); // <- Get the client number in game
	
	/* If the client is connected, talking and stamina > 0 */
	if (IsValidClient(client) && gVoiceStamina[client] > 0 && IsClientSpeaking(client))
	{
		gVoiceStamina[client]--;
		
		if (gVoiceStamina[client] == 0)
		{
			char name[64];
			GetClientName(client, name, sizeof(name));
			BaseComm_SetClientMute(client, true); // <- mute the client on the server only
			PrintToChat(client, " \x01\x04[DREAM] \x07%t !", "Mute", cvMute.FloatValue); // <- print translation message to the client
			PrintToChatAll(" \x01\x04[DREAM] Auto-Mute %s !", name);
			CreateTimer(cvMute.FloatValue, TimerUnmute, GetClientUserId(client)); // <- timer for the unmute timer
		}
		else
		{
			result = Plugin_Handled; // <- then the client doesn't need to be muted so the timer continue
		}
	}
	return result;
}

public Action TimerReloadVoiceStamina(Handle timer, any userid)
{
	/*	Timer for reloading the stamina of the client when he is not talking
	
	*/
	Action result = Plugin_Stop; // <- Timer stop by itself by default to prevent any problem
	int client = GetClientOfUserId(userid); // <- Get the client number in game
	
	/* If the client is connected, not talking and stamina > 0 */
	if (IsValidClient(client) && gVoiceStamina[client] < cvStamina.IntValue && !IsClientSpeaking(client))
	{
		gVoiceStamina[client]++;
		result = Plugin_Handled; // <- then the client doesn't need to be muted so the timer continue
	}
	
	return result;
}

public Action TimerUnmute(Handle timer, any userid)
{
	/*	Timer to unmute the guy
	
	*/
	int client = GetClientOfUserId(userid); // <- Get the client number in game
	BaseComm_SetClientMute(client, false); // <- unmute the client on the server only
	PrintToChat(client, " \x01\x04[DREAM] \x06%t !", "Unmute"); // <- print translation message to the client
	gVoiceStamina[client] = cvStamina.IntValue; // <- reset the stamina
	return Plugin_Handled;
}

public void OnClientConnected(int client)
{
	/*	Initialisation of the stamina of the client
	
	*/
	gVoiceStamina[client] = cvStamina.IntValue;
}

/* Utils functions */
public bool IsAdmin(int client, int flag)
{
	return CheckCommandAccess(client, "sm_admin", flag, true);
}

public bool IsValidClient(int client)
{
	bool valid = false;
	if (client > 0 && client <= MAXPLAYERS && IsClientConnected(client))
	{
		valid = true;
	}
	return valid;
}