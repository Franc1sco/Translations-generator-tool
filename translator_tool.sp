/*  SM File translations generator tool
 *
 *  Copyright (C) 2018 Francisco 'Franc1sco' García
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

#include <sdktools>
#include <SteamWorks>


#define DATA "0.2"

Handle kv;
char sConfig[PLATFORM_MAX_PATH];
Handle timers;

public Plugin myinfo =
{
	name = "SM Translations generator tool",
	description = "Tool for translate plugins that auto create the translation file in all languages",
	author = "Franc1sco franug",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_translate", Command_Translate, ADMFLAG_ROOT);
	RegAdminCmd("sm_translate_txt", Command_TranslateTxt, ADMFLAG_ROOT);
}

public Action Command_Translate(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Use sm_translate <phrase to translate>");
		return Plugin_Handled;
	}
		

	char buffer[255];
	GetCmdArgString(buffer,sizeof(buffer));
	StripQuotes(buffer);
	
	if (strlen(buffer) < 1)return Plugin_Handled;
	
	if (kv == null)
	{
		ReplyToCommand(client, "You need to set first the file target with sm_translate_txt <filetarget> command.");
		return Plugin_Handled;
	}
	
	char temp[3];
	
	new maxLangs = GetLanguageCount();
	for (new i = 0; i < maxLangs; i++)
	{
		GetLanguageInfo(i, temp, 3);
		Handle request = CreateRequest(buffer, temp);
		SteamWorks_SendHTTPRequest(request);
	}
	
	ReplyToCommand(client, "Working on translations...");
	return Plugin_Handled;
}

public Action Command_TranslateTxt(int client, int args)
{
	if(args != 1)
	{
		ReplyToCommand(client, "Use sm_translate_txt <file target>");
		return Plugin_Handled;
	}
		
	char sLangFile[64];
		
	GetCmdArg(1, sLangFile, sizeof(sLangFile));
	
	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, "translations/%s", sLangFile);
	
	if (kv != null)CloseHandle(kv);
	
	if(!FileExists(sConfig))
	{
		kv = CreateKeyValues("Phrases");
		KeyValuesToFile(kv, sConfig);
	}
	else
	{
		kv = CreateKeyValues("Phrases");
		FileToKeyValues(kv, sConfig);
	}	
	
	ReplyToCommand(client, "File set to %s",sConfig);
	
	return Plugin_Handled;
}

Handle CreateRequest(char[] input, char[] target)
{
    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, "http://www.headlinedev.xyz/translate/translate.php");
    SteamWorks_SetHTTPRequestGetOrPostParameter(request, "input", input);
    SteamWorks_SetHTTPRequestGetOrPostParameter(request, "target", target);
    
    Handle datapack = CreateDataPack();
    WritePackString(datapack, target);
    WritePackString(datapack, input);
    
    SteamWorks_SetHTTPRequestContextValue(request, datapack);
    SteamWorks_SetHTTPCallbacks(request, Callback_OnHTTPResponse);
    return request;
}

public int Callback_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, Handle datapack)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{        
        return;
	}

	int iBufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, iBufferSize);
    
	char[] result = new char[iBufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, result, iBufferSize);
	delete request;
	
	char target[3], input[255];
	ResetPack(datapack);
	ReadPackString(datapack, target, 3);
	ReadPackString(datapack, input, 255);
	CloseHandle(datapack);


	KvJumpToKey(kv, input, true);
	KvSetString(kv, target, result);

	// dont write file each time, just wait for finish
	if (timers != null)KillTimer(timers);
	
	timers = CreateTimer(4.0, Timer_WriteData);
	
	KvRewind(kv);
}  

public Action Timer_WriteData(Handle timer)
{
	if(kv != null) KeyValuesToFile(kv, sConfig);
	
	timers = null;
	
	PrintToChatAll("Translations done");
}