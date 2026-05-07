# itay-maploader (Stable VPS Edition)

A robust, high-performance map downloader for SourceMod designed specifically for Linux VPS environments. This plugin leverages system-level Linux commands to ensure 100% reliable downloads and decompression, bypassing common filesystem restrictions.

## ✨ Features
- **Linux-Native Transfer**: Uses `curl` for high-speed, resumable downloads.
- **Smart Decompression**: Uses `bzip2` with the `-s` flag to protect low-RAM VPS servers.
- **FS-Sync Delay**: Implements a synchronization timer to wait for Linux to finish writing before attempting to unzip.
- **Duplicate Protection**: Automatically blocks redundant downloads if the map already exists.
- **Diagnostic Suite**: Built-in commands to check permissions and system health.

## 🛠️ Requirements
- **SourceMod 1.11+**
- **System2 Extension** (Required for shell execution)
- **Linux VPS** with `curl` and `bzip2` installed.

## 📥 Installation
1. Install the [System2 Extension](https://github.com/derek-reese/system2).
2. Upload `itay-maploader.smx` to your `addons/sourcemod/plugins/` folder.
3. Restart your server or load the plugin: `sm plugins load itay-maploader`.

---

## 🔐 VPS Permissions Setup (CRITICAL)

For this plugin to work, the Linux user running your game server **must** have permission to write files into the `maps/` directory. If permissions are not set correctly, `curl` will fail to save the map.

### 1. The "Easy Fix" (Recommended)
Run this command in your VPS terminal (replace the path with your actual maps folder):
```bash
chmod -R 777 /home/cssserver/serverfiles/cstrike/maps
```
*Note: `777` gives full read/write/execute permissions. If you are a power user, you can use `755` as long as the owner is the game server user.*

### 2. Verify within the Game
Once you have set the permissions, run this command in your game console (as a Root Admin):
```bash
sm_checkperm
```
The plugin will attempt to create a temporary test file. If you see **"Success! The folder is writable,"** you are ready to go!

---

## ⚙️ Configuration
The plugin generates a config file in `cfg/sourcemod/itay-maploader.cfg`:

| ConVar | Default | Description |
| :--- | :--- | :--- |
| `itay_maploader_url` | `http://main.fastdl.me/maps/` | The base URL of your FastDL maps folder. |
| `itay_maploader_path` | `""` | The absolute path to your maps folder. Leave empty for auto-detection. |

## 🔍 Diagnostic Commands
- `sm_getmap <mapname>`: Manually trigger a download.
- `sm_checkperm`: Verifies if the folder is writable.
- `sm_mapdebug`: Shows current pathing and system info.

---

## 🏗️ Developer: Deep Setup & Compilation Guide

### 1. The Include Files (`.inc`)
This plugin depends on two custom include files found in the `include/` directory of this repo:
*   `system2.inc`: Threaded shell execution API.
*   `itay-colors.inc`: Chat coloring library.

### 2. Setting up your Compiler
1. Copy `system2.inc` and `itay-colors.inc` from the `include/` folder into your compiler's `include/` directory.
2. Move `itay-maploader.sp` into your `scripting/` folder.
3. Run the compiler:
   ```bash
   ./spcomp itay-maploader.sp -o itay-maploader.smx
   ```

---
*Created by Itay & Antigravity*
