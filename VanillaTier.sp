// TODO: Add documentation.
// TODO: Better logging.
// TODO: Don't use regex and read line by line into a map.
// TODO: !vnltier map_name
// TODO: Retry when http request fails (status code 0 happens occasionally).

// Edge cases:
// random spaces like "kz_beanguy_v2 "
// "kz_intercourse!"
// "N/A" tier for kzpro

#include <sourcemod>
#include <SteamWorks>
#include <regex>

#pragma tabsize 0
#pragma semicolon 1

char body[50000]; // buffer used to hold http body response
char sheets_api_key[40]; // google sheets api key
char base_url[91] = "https://sheets.googleapis.com/v4/spreadsheets/1avMaSsZ5h7u21LpRz04kk6cn-PPHucA95T745Jj21MM"; // url to google sheet

bool c_finish, u_finish, map_found, map_possible, error;
char tp_tier[3], pro_tier[3];

public Plugin myinfo = {
	name = "Vanilla Tier",
	author = "nobody",
	description = "Provides !tier for vanilla kz.",
	version = "0.0.5",
	url = "https://kiwisclub.co/" 
};

public void OnPluginStart() {
    // RegAdminCmd("sm_debug", Debug, ADMFLAG_CHANGEMAP);
	RegConsoleCmd("sm_vnltier", VanillaTier, "Show the map's vanilla tier in the chat.");

    // read API key from configs/vnltier.ini
    char filename[200];
    BuildPath(Path_SM, filename, sizeof(filename), "configs/vnltier.ini");
    File file = OpenFile(filename, "rt");
    if (!file) {
        PrintToServer("VNLTier: Cannot find configs/vnltier.ini.");
        return;
    }
    file.ReadLine(sheets_api_key, sizeof(sheets_api_key));
    file.Close();
}

// public Action Debug(int client, int args) {
//     // OnMapStart();
//     PrintToServer("error: %s", error ? "true" : "false");
//     PrintToServer("c_finish: %s", c_finish ? "true" : "false");
//     PrintToServer("u_finish: %s", u_finish ? "true" : "false");
//     PrintToServer("map_found: %s", map_found ? "true" : "false");
//     PrintToServer("map_possible: %s", map_possible ? "true" : "false");
//     PrintToServer("TP Tier: %s", tp_tier);
//     PrintToServer("PRO Tier: %s", pro_tier);
//     // PrintToServer("API Key: %s", sheets_api_key);
// }

/**
 * Returns if map name is valid under global team's rules (alphabet + digits + _).
 * Does not check prefix (kz, bkz, etc.).
 * Assumes only exception is kz_intercourse!.
 * 
 * @param map_name     Map name
 * @return             Validity of map name
 */
public bool isValidMapName(char[] map_name) {
    if (strcmp(map_name, "kz_intercourse!") == 0) {
        return true;
    }
    int n = strlen(map_name);
    for (int i = 0; i < n; i++) {
        bool flag = false;
        if ('a' <= map_name[i] && map_name[i] <= 'z') {
            flag = true;
        }
        if ('0' <= map_name[i] && map_name[i] <= '9') {
            flag = true;
        }
        if (map_name[i] == '_') {
            flag = true;
        }
        if (!flag) {
            return false;
        }
    }
    return true;
}

public GetCurrentMapName(char[] buffer, int n) {
    char tmp[500];
    GetCurrentMap(tmp, sizeof(tmp));
    // if hosting map from workshop, map name will be "workshop/[id #]/[map name]"
    if (StrContains(tmp, "/") != -1) {
        Regex regex = CompileRegex("\\/([^\\/]+)$");
        regex.MatchAll(tmp);
        regex.GetSubString(1, buffer, n);
    }
    else {
        strcopy(buffer, strlen(tmp) + 1, tmp);
    }
}

public void OnMapStart() {
    c_finish = false;
    u_finish = false;
    map_found = false;
    error = false;

    char map_name[100];
    GetCurrentMapName(map_name, sizeof(map_name));
    
    if (isValidMapName(map_name)) {
        updateCompletedTier();
        updateUncompletedTier();
    }
    else {
        map_found = false;
        c_finish = true;
        u_finish =true;
    }
}

public bool api_error(char[] s) {
    if (StrContains(s, "\"error\":") != -1) {
        if (StrContains(s, "API key not valid") != -1) {
            PrintToServer("VNLTier: API key not valid.");
        }
        else {
            Regex regex = CompileRegex("\"code\": (\\d+)");
            regex.MatchAll(s);
            char error_code[3];
            regex.GetSubString(1, error_code, sizeof(error_code));
            PrintToServer("VNLTier: Google Sheets API error code: %d", error_code);

            regex = CompileRegex("\"message\": \"(.*)\"");
            regex.MatchAll(s);
            char error_message[200];
            regex.GetSubString(1, error_message, sizeof(error_message));
            PrintToServer("VNLTier: Google Sheets API error message: %d", error_message);
        }
        return true;
    }
    return false;
}

public void updateCompletedTier() {
    char url[200];
    Format(url, sizeof(url), "%s/values/'Map%%20Tiers'!A:C/?key=%s", base_url, sheets_api_key);
    int handle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    SteamWorks_SetHTTPCallbacks(handle, HTTPCompletedTier);
    SteamWorks_SendHTTPRequest(handle);
}

public int HTTPCompletedTier(Handle HTTPRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) {
    if (!bRequestSuccessful) {
        PrintToServer("VNLTier: HTTP request not successful. Status code %d.", eStatusCode);
        error = true;
    }
    else {
        int size = -1;
        SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);
        PrintToServer("VNLTier: Received %d bytes.", size);
        SteamWorks_GetHTTPResponseBodyData(HTTPRequest, body, size);
        CloseHandle(HTTPRequest);

        if (api_error(body)) {
            error = true;
        }
        else {
            char map_name[100], regex_raw[200] = "\\[\\s*\"\\s*";
            GetCurrentMapName(map_name, sizeof(map_name)); // TODO: edit this to handle any given map name by user (figure out how to pass data via handle)
            StrCat(regex_raw, sizeof(regex_raw), map_name);
            StrCat(regex_raw, sizeof(regex_raw), "\\s*\",\\s*\"(\\d+|N/A)\",\\s*\"(\\d+|N/A)\"\\s*\\]");
            Regex regex = CompileRegex(regex_raw);
            int numMatches = regex.MatchAll(body);
            if (numMatches != 0) {
                map_found = true;
                map_possible = true;
                regex.GetSubString(1, tp_tier, sizeof(tp_tier));
                regex.GetSubString(2, pro_tier, sizeof(pro_tier));
            }
        }
    }
    c_finish = true;
}

public void updateUncompletedTier() {
    char url[200];
    Format(url, sizeof(url), "%s/values/'Uncompleted%%20Maps'!A:A/?key=%s", base_url, sheets_api_key);
    int handle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    SteamWorks_SetHTTPCallbacks(handle, HTTPUncompletedTier);
    SteamWorks_SendHTTPRequest(handle);
}

public int HTTPUncompletedTier(Handle HTTPRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) {
    if (!bRequestSuccessful) {
        PrintToServer("VNLTier: HTTP request not successful. Status code %d.", eStatusCode);
        error = true;
    }
    else {
        int size = -1;
        SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);
        PrintToServer("VNLTier: Received %d bytes.", size);
        SteamWorks_GetHTTPResponseBodyData(HTTPRequest, body, size);
        CloseHandle(HTTPRequest);

        if (api_error(body)) {
            error = true;
        }
        else {
            char map_name[100];
            GetCurrentMapName(map_name, sizeof(map_name)); // TODO: edit this to handle any given map name by user (figure out how to pass data via handle)
            char regex_t8[200] = "\"Feasible Maps\".*\"\\s*", regex_t9[200] = "\"Unfeasible Maps\".*\"\\s*", regex_t10[200] = "\"Impossible Maps\".*\"\\s*";
            
            StrCat(regex_t8, sizeof(regex_t8), map_name);
            StrCat(regex_t9, sizeof(regex_t9), map_name);
            StrCat(regex_t10, sizeof(regex_t10), map_name);

            StrCat(regex_t8, sizeof(regex_t8), "\\s*\".*\"Unfeasible Maps\"");
            StrCat(regex_t9, sizeof(regex_t9), "\\s*\".*\"Impossible Maps\"");
            StrCat(regex_t10, sizeof(regex_t10), "\\s*\"");
            
            Regex regex = CompileRegex(regex_t8, PCRE_DOTALL);
            bool t8 = (regex.MatchAll(body) > 0);
            regex = CompileRegex(regex_t9, PCRE_DOTALL);
            bool t9 = (regex.MatchAll(body) > 0);
            regex = CompileRegex(regex_t10, PCRE_DOTALL);
            bool t10 = (regex.MatchAll(body) > 0);
            
            if (t8) {
                map_found = true;
                map_possible = true;
                tp_tier = "8";
                pro_tier = "9";
            }
            else if (t9) {
                map_found = true;
                map_possible = true;
                tp_tier = "9";
                pro_tier = "9";
            }
            else if (t10) {
                map_found = true;
                map_possible = false;
            }
        }
    }
    u_finish = true;
}

public Action VanillaTier(int client, int args) {
    if (error) {
        PrintToChat(client, "[VNL] Something went wrong. Contact adminstrator.");
    }
    else if (!c_finish || !u_finish) {
        PrintToChat(client, "[VNL] Retrieving tiers... try again.");
    }
    else if (map_found) {
        if (map_possible) {
            PrintToChat(client, "[VNL] TP Tier: %s", tp_tier);
            PrintToChat(client, "[VNL] PRO Tier: %s", pro_tier);
        }
        else {
            PrintToChat(client, "[VNL] Map not possible in vanilla.");
        }
    }
    else {
        PrintToChat(client, "[VNL] Map not found.");
    }
}