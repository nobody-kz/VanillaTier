// TODO: Add documentation.
// TODO: Better logging.
// TODO: Retry when http request fails (status code 0 happens occasionally).

// Edge cases:
// random spaces like "kz_beanguy_v2 "
// "kz_intercourse!"
// "N/A" tier for kzpro

#include <json>
#include <sourcemod>
#include <SteamWorks>
#include <regex>

#define MAX_BODY_LENGTH 50000
#define MAX_URL_LENGTH 200
#define MAX_MAP_NAME_LENGTH 100
#define MAX_MAP_COUNT 1000

#define FEASIBLE 0
#define UNFEASIBLE 1
#define IMPOSSIBLE 2

#pragma newdecls required
#pragma tabsize 0
#pragma semicolon 1

char sheets_api_key[40]; // google sheets api key
char base_url[91] = "https://sheets.googleapis.com/v4/spreadsheets/1avMaSsZ5h7u21LpRz04kk6cn-PPHucA95T745Jj21MM"; // url to google sheet

char map_names[MAX_MAP_COUNT][MAX_MAP_NAME_LENGTH];
int tp_tiers[MAX_MAP_COUNT], pro_tiers[MAX_MAP_COUNT];
int num_maps;

char feasible_map_names[MAX_MAP_COUNT][MAX_MAP_NAME_LENGTH], unfeasible_map_names[MAX_MAP_COUNT][MAX_MAP_NAME_LENGTH], impossible_map_names[MAX_MAP_COUNT][MAX_MAP_NAME_LENGTH];
int num_feasible_maps, num_unfeasible_maps, num_impossible_maps;

char prefixes[][] = {"kz_", "xc_", "bkz_", "skz_", "vnl_", "kzpro_"};
char unfeasible[] = "Unfeasible Maps", impossible[] = "Impossible Maps";

public Plugin myinfo = {
	name = "Vanilla Tier",
	author = "nobody",
	description = "Provides !tier for vanilla kz.",
	version = "0.0.6",
	url = "https://kiwisclub.co/" 
};

public void OnPluginStart() {
    RegConsoleCmd("sm_vnltier", VanillaTier, "Show the map's vanilla tier in the chat.");

    // read API key from configs/vnltier.ini
    char filename[200], buffer[500];
    BuildPath(Path_SM, filename, sizeof(filename), "configs/vnltier.ini");
    File file = OpenFile(filename, "rt");
    if (!file) {
        PrintToServer("VNLTier: Cannot find configs/vnltier.ini.");
        return;
    }
    ReadFileString(file, buffer, sizeof(buffer) -1);
    file.Close();

    JSON_Object obj = json_decode(buffer);
    obj.GetString("key", sheets_api_key, sizeof(sheets_api_key));
    json_cleanup_and_delete(obj);
    // PrintToServer("VNLTier: API key is %s", sheets_api_key);
}

public bool isDigit(char c) {
    return '0' <= c && c <= '9';
}

public bool checkPrefix(const char[] s, const char[] prefix) {
    if (strlen(s) < strlen(prefix)) {
        return false;
    }
    for (int i = 0; i < strlen(prefix); i++) {
        if (s[i] != prefix[i]) {
            return false;
        }
    }
    return true;
}

/**
 * Returns if map name is valid under global team's rules.
 * Exception is "kz_intercourse!"".
 * 
 * @param name         Map name
 * @return             Validity of map name
 */
public bool isValidMapName(const char[] name) {
    if (strcmp(name, "kz_intercourse!") == 0) {
        return true;
    }
    bool flag = true;
    for (int i = 0; i < sizeof(prefixes); i++) {
        if (checkPrefix(name, prefixes[i])) {
            flag = true;
        }
    }
    if (!flag) {
        return false;
    }
    int n = strlen(name);
    for (int i = 0; i < n; i++) {
        flag = false;
        if ('a' <= name[i] && name[i] <= 'z') {
            flag = true;
        }
        if (isDigit(name[i])) {
            flag = true;
        }
        if (name[i] == '_') {
            flag = true;
        }
        if (!flag) {
            return false;
        }
    }
    return true;
}

public void GetCurrentMapName(char[] buffer, int n) {
    char tmp[MAX_MAP_NAME_LENGTH + 30];
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
    num_maps = 0;
    num_feasible_maps = 0;
    num_unfeasible_maps = 0;
    num_impossible_maps = 0;
    updateCompletedTier();
    updateUncompletedTier();
}

public void updateCompletedTier() {
    char url[MAX_URL_LENGTH];
    Format(url, sizeof(url), "%s/values/'Map%%20Tiers'!A:C/?key=%s", base_url, sheets_api_key);
    Handle handle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    SteamWorks_SetHTTPCallbacks(handle, HTTPCompletedTier);
    SteamWorks_SendHTTPRequest(handle);
}

public int HTTPCompletedTier(Handle HTTPRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) {
    if (eStatusCode != k_EHTTPStatusCode200OK) {
        PrintToServer("VNLTier: HTTP request not successful. Status code %d.", eStatusCode);
    }
    else {
        int size;
        static char body[MAX_BODY_LENGTH];
        SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);
        PrintToServer("VNLTier: Received %d bytes.", size);
        SteamWorks_GetHTTPResponseBodyData(HTTPRequest, body, size);
        body[size] = 0;

        JSON_Object obj = json_decode(body);
        JSON_Array values = view_as<JSON_Array>(obj.GetObject("values"));
        int n = values.Length;
        char buffer[MAX_MAP_NAME_LENGTH];
        for (int i = 0; i < n; i++) {
            JSON_Array row = view_as<JSON_Array>(values.GetObject(i));
            if (row.Length != 3) {
                continue;
            }
            row.GetString(0, buffer, sizeof(buffer));
            TrimString(buffer);
            if (isValidMapName(buffer)) {
                strcopy(map_names[num_maps], MAX_MAP_NAME_LENGTH, buffer);

                row.GetString(1, buffer, sizeof(buffer));
                if (isDigit(buffer[0])) {
                    tp_tiers[num_maps] = buffer[0] - '0';
                }
                else {
                    tp_tiers[num_maps] = -1;
                }
                
                row.GetString(2, buffer, sizeof(buffer));
                pro_tiers[num_maps] = buffer[0] - '0';

                num_maps++;
            }
        }
        json_cleanup_and_delete(obj);
    }
    CloseHandle(HTTPRequest);
}

public void updateUncompletedTier() {
    char url[MAX_URL_LENGTH];
    Format(url, sizeof(url), "%s/values/'Uncompleted%%20Maps'!A:A/?majorDimension=COLUMNS&key=%s", base_url, sheets_api_key);
    Handle handle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
    SteamWorks_SetHTTPCallbacks(handle, HTTPUncompletedTier);
    SteamWorks_SendHTTPRequest(handle);
}

public int HTTPUncompletedTier(Handle HTTPRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) {
    if (eStatusCode != k_EHTTPStatusCode200OK) {
        PrintToServer("VNLTier: HTTP request not successful. Status code %d.", eStatusCode);
    }
    else {
        int size;
        static char body[MAX_BODY_LENGTH];
        SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);
        PrintToServer("VNLTier: Received %d bytes.", size);
        SteamWorks_GetHTTPResponseBodyData(HTTPRequest, body, size);
        body[size] = 0;

        JSON_Object obj = json_decode(body);
        JSON_Array values = view_as<JSON_Array>(obj.GetObject("values"));
        JSON_Array value = view_as<JSON_Array>(values.GetObject(0));
        int n = value.Length;
        char buffer[MAX_MAP_NAME_LENGTH];
        int mode = FEASIBLE;
        for (int i = 0; i < n; i++) {
            value.GetString(i, buffer, sizeof(buffer));
            TrimString(buffer);
            if (strcmp(buffer, unfeasible) == 0) {
                mode = UNFEASIBLE;
            }
            else if (strcmp(buffer, impossible) == 0) {
                mode = IMPOSSIBLE;
            }
            else if (isValidMapName(buffer)) {
                if (mode == FEASIBLE) {
                    strcopy(feasible_map_names[num_feasible_maps], MAX_MAP_NAME_LENGTH, buffer);
                    num_feasible_maps++;
                }
                else if (mode == UNFEASIBLE) {
                    strcopy(unfeasible_map_names[num_unfeasible_maps], MAX_MAP_NAME_LENGTH, buffer);
                    num_unfeasible_maps++;
                }
                else {
                    strcopy(impossible_map_names[num_impossible_maps], MAX_MAP_NAME_LENGTH, buffer);
                    num_impossible_maps++;
                }
            }
        }
        json_cleanup_and_delete(obj);
    }
    CloseHandle(HTTPRequest);
}

public Action VanillaTier(int client, int args) {
    char name[MAX_MAP_NAME_LENGTH];
    if (args == 0) {
        GetCurrentMapName(name, sizeof(name));
    }
    else {
        GetCmdArg(1, name, sizeof(name));
    }
    for (int i = 0; i < num_maps; i++) {
        if (strcmp(name, map_names[i], false) == 0) {
            if (tp_tiers[i] != -1) {
                PrintToChat(client, "[VNL] TP Tier: %d", tp_tiers[i]);
            }
            PrintToChat(client, "[VNL] PRO Tier: %d", pro_tiers[i]);
            return;
        }
    }
    for (int i = 0; i < num_feasible_maps; i++) {
        if (strcmp(name, feasible_map_names[i], false) == 0) {
            PrintToChat(client, "[VNL] Map is feasible but uncompleted in vanilla.");
            return;
        }
    }
    for (int i = 0; i < num_unfeasible_maps; i++) {
        if (strcmp(name, unfeasible_map_names[i], false) == 0) {
            PrintToChat(client, "[VNL] Map is unfeasible in vanilla.");
            return;
        }
    }
    for (int i = 0; i < num_impossible_maps; i++) {
        if (strcmp(name, impossible_map_names[i], false) == 0) {
            PrintToChat(client, "[VNL] Map is impossible in vanilla.");
            return;
        }
    }
    PrintToChat(client, "[VNL] Map not found.");
}
