# VanillaTier

This plugin displays vanilla tiers of KZ maps.

Vanilla tiers are pulled from [this spreadsheet](https://docs.google.com/spreadsheets/d/1avMaSsZ5h7u21LpRz04kk6cn-PPHucA95T745Jj21MM/edit#gid=0).

## Installation

- Create a Google Sheets API Key:
    - Open the [Google Cloud Console](https://console.cloud.google.com/projectselector2/apis/dashboard?supportedpurview=project).
    - Create a new project.
    - Open the [API Library](https://console.cloud.google.com/apis/library?supportedpurview=project).
    - Search for Sheets and enable the API.
    - Open your [Credentials](https://console.cloud.google.com/projectselector2/apis/credentials?supportedpurview=project).
    - Click "Create Credentials" and create a new API Key.
    - Copy the API Key. The API key is a long string containing numbers, letters, and symbols, such as `AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe`.
    - Click the API Key. Select "IP addresses" under "Application restrictions". Add your server's IP address below.
    - Select "Restrict key" under "API restrictions". Select "Google Sheets API" in the drop down menu below.
- Set up the initialization file `csgo/addons/sourcemod/configs/vnltier.ini`.
    - The file should contain a single JSON object with key `key` and value as your API Key.
    - Example:
  ```
    {
        "key": "AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe"
    }
  ```
- Compile the plugin yourself or use the provided `VanillaTier.smx` file in the latest release.
- Add the `VanillaTier.smx` file to `csgo/addons/sourcemod/plugins`.
- Enter `sm plugins refresh` into the server console.

## Usage
Type `!vnltier` or `!vnltier [map name]` into the chat.

Currently the full map name needs to be specified.
