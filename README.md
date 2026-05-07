# itay-maploader (Stable VPS Edition)

A robust, high-performance map downloader for SourceMod designed specifically for Linux VPS environments. Unlike traditional map loaders that rely on unstable HTTP extensions, `itay-maploader` leverages system-level Linux commands to ensure 100% reliable downloads and decompression.

## 🚀 Why this plugin?
Most map loaders fail on Linux VPS servers because:
1. **Path Restrictions**: SourceMod often blocks access to absolute paths for security.
2. **IO Delays**: Filesystems on virtual servers can be slow, leading to "File Not Found" errors during decompression.
3. **Memory Limits**: Traditional unzipping can crash low-RAM servers.

`itay-maploader` solves this by bypassing SourceMod's file API and using the **Linux Shell** directly.

## ✨ Features
- **Linux-Native Transfer**: Uses `curl` for high-speed, resumable downloads.
- **Smart Decompression**: Uses `bzip2` with the `-s` (small memory) flag to protect your VPS.
- **FS-Sync Delay**: Implements a synchronization timer to wait for Linux to finish writing before attempting to unzip.
- **Absolute Path Bypass**: Uses `stat` commands to verify file integrity, bypassing SourcePawn's directory restrictions.
- **Duplicate Protection**: Automatically blocks redundant downloads if the map already exists.
- **Diagnostic Suite**: Built-in commands to check permissions and network connectivity.

## 🛠️ Requirements
- **SourceMod 1.11+**
- **System2 Extension** (Required for shell execution)
- **Linux VPS** with `curl` and `bzip2` installed (Standard on almost all distros).

## 📥 Installation
1. Install the [System2 Extension](https://github.com/derek-reese/system2).
2. Upload `itay-maploader.smx` to your `addons/sourcemod/plugins/` folder.
3. (Optional) Upload `itay_messages.phrases.txt` to your `translations/` folder.
4. Restart your server or load the plugin: `sm plugins load itay-maploader`.

## ⚙️ Configuration
The plugin will generate a config file in `cfg/sourcemod/itay-maploader.cfg`:

| ConVar | Default | Description |
| :--- | :--- | :--- |
| `itay_maploader_url` | `http://main.fastdl.me/maps/` | The base URL of your FastDL maps folder. |
| `itay_maploader_path` | `""` | The absolute path to your maps folder. Leave empty for auto-detection. |

## 🔍 Diagnostic Commands
If you encounter issues, use these root-admin commands:
- `sm_getmap <mapname>`: Manually trigger a download.
- `sm_checkperm`: Verifies if the server has "Write" permissions on the maps folder.
- `sm_mapdebug`: Shows current pathing and system info.
- `sm_dir`: Lists files in the maps directory (via Linux).

## 🏗️ Building from Source
If you wish to compile it yourself, ensure you have the following includes:
- `system2.inc`
- `itay-colors.inc` (or any compatible color library)

---
*Created by Itay & Antigravity*
