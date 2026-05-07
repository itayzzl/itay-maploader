# itay-maploader

A robust, high-performance map downloader for SourceMod designed for Linux-based game servers. This plugin leverages system-level Linux commands to ensure reliable downloads and decompression, bypassing common filesystem restrictions found on many game server hosts.

## Features
- Linux-Native Transfer: Uses curl for high-speed, resumable downloads.
- Smart Decompression: Uses bzip2 with the -s flag to protect low-RAM servers.
- FS-Sync Delay: Implements a synchronization timer to wait for Linux to finish writing before attempting to unzip.
- Duplicate Protection: Automatically blocks redundant downloads if the map already exists.
- Diagnostic Suite: Built-in commands to check permissions and system health.

## Requirements
- SourceMod 1.11+
- System2 Extension (Required for shell execution)
- Linux-based host with curl and bzip2 installed.

## Installation
1. Install the System2 Extension.
2. Upload itay-maploader.smx to your addons/sourcemod/plugins/ folder.
3. Restart your server or load the plugin: sm plugins load itay-maploader.

---

## Folder Permissions Setup (CRITICAL)

For this plugin to work, the user running your game server must have permission to write files into the maps directory. 

### 1. The Permissions Command
Run this command in your terminal (Note: You MUST replace the path below with your own actual server path):
```bash
chmod -R 777 /YOUR/ACTUAL/SERVER/PATH/cstrike/maps
```

### 2. Identifying your Path
The path `/home/cssserver/serverfiles/cstrike/maps` shown in examples is only a placeholder. To find your actual path, you can run the `pwd` command in your terminal while inside your maps folder, or use the `sm_mapdebug` command in-game after the plugin is loaded.

### 3. Verification
Once you have set the permissions, run this command in your game console (as a Root Admin):
```bash
sm_checkperm
```
The plugin will attempt to create a temporary test file. If you see "Success! The folder is writable," the setup is complete.

---

## Configuration
The plugin generates a config file in cfg/sourcemod/itay-maploader.cfg:

| ConVar | Default | Description |
| :--- | :--- | :--- |
| itay_maploader_url | http://main.fastdl.me/maps/ | The base URL of your FastDL maps folder. |
| itay_maploader_path | "" | The **absolute path** to your maps folder (e.g., /home/USER/server/cstrike/maps/). **You MUST use your own unique path here.** |

## Diagnostic Commands
- sm_getmap <mapname>: Manually trigger a download.
- sm_checkperm: Verifies if the folder is writable.
- sm_mapdebug: Shows current pathing and system info.

---

## Developer: Setup & Compilation Guide

### 1. Include Files (.inc)
This plugin depends on two custom include files found in the include/ directory of this repo:
- system2.inc: Threaded shell execution API.
- itay-colors.inc: Chat coloring library.

### 2. Setting up your Compiler
1. Copy system2.inc and itay-colors.inc from the include/ folder into your compiler's include/ directory.
2. Move itay-maploader.sp into your scripting/ folder.
3. Run the compiler:
   ```bash
   ./spcomp itay-maploader.sp -o itay-maploader.smx
   ```

---
Created by Itay
