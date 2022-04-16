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
    - Copy the API Key. The API key is a long string containing upper and lower case letters, numbers, and dashes, such as `a4db08b7-5729-4ba9-8c08-f2df493465a1`.
    - (Optional: edit the API Key so that it is only accessible from your server's IP.)
- Dump the API Key into a new file `csgo/addons/sourcemod/configs/vnltier.ini`.
- Compile the plugin yourself or use the provided `VanillaTier.smx` file in the latest release.
- Add the `VanillaTier.smx` file to `csgo/addons/sourcemod/plugins`.
- Enter `sm plugins refresh` into the server console.

## Usage
Type `!vnltier` into the chat.

Details on tiers:
- Uncompleted maps are still given tiers:
    - Feasible maps are given a TP tier of 8 and a PRO tier of 9.
    - Unfeasible maps are given a TP and PRO tier of 9.
- If a map is impossible in vanilla, the command will return "Map not possible in vanilla."

Checking the vanilla tier of any map (`!vnltier map_name`) will be implemented in the future.

## Contact
If you have any questions or concerns, contact me on Discord at `nobody#9768`.