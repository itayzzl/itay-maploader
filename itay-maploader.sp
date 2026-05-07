#include <sourcemod>
#include <system2>
#include <itay-colors>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 1048576

ConVar g_cvFastDLURL;
ConVar g_cvMapsPath;
bool g_bHasBzip2 = true;
StringMap g_hActiveRequests;

public Plugin myinfo = 
{
    name = "itay-maploader",
    author = "itay & Antigravity",
    description = "Downloads maps from FastDL using Linux curl (Stable)",
    version = "1.7",
    url = ""
};

public void OnPluginStart()
{
    LoadTranslations("itay_messages.phrases");
    g_cvFastDLURL = CreateConVar("itay_maploader_url", "https://main.fastdl.me/maps/", "Base URL for FastDL maps folder");
    g_cvMapsPath = CreateConVar("itay_maploader_path", "", "Absolute path to maps folder (e.g. /home/server/cstrike/maps/). Empty = auto.");
    
    RegAdminCmd("sm_getmap", Command_GetMap, ADMFLAG_ROOT);
    RegAdminCmd("sm_mapdebug", Command_MapDebug, ADMFLAG_ROOT);
    RegAdminCmd("sm_checkperm", Command_CheckPerm, ADMFLAG_ROOT);
    RegAdminCmd("sm_dir", Command_Dir, ADMFLAG_ROOT);
    RegAdminCmd("sm_pwd", Command_Pwd, ADMFLAG_ROOT);
    RegAdminCmd("sm_curldebug", Command_CurlDebug, ADMFLAG_ROOT);
    RegAdminCmd("sm_bzipdebug", Command_BzipDebug, ADMFLAG_ROOT);
    
    AutoExecConfig(true, "itay-maploader");

    g_hActiveRequests = new StringMap();
    System2_ExecuteThreaded(OnBzip2Check, "which bzip2");
    System2_ExecuteThreaded(OnCurlCheck, "which curl");
}

public void OnCurlCheck(bool success, const char[] command, System2ExecuteOutput output, any data)
{
    if (!success || output == null || output.ExitStatus != 0)
    {
        PrintToServer("[itay-maploader] CRITICAL: 'curl' not found on this VPS! Downloads will fail.");
    }
}

public void OnBzip2Check(bool success, const char[] command, System2ExecuteOutput output, any data)
{
    if (!success || output == null || output.ExitStatus != 0)
    {
        g_bHasBzip2 = false;
        PrintToServer("[itay-maploader] WARNING: bzip2 not found! Downloads will fail if server only provides .bz2");
    }
}

// =============================================================================
// Download Logic (Now using System2)
// =============================================================================

public Action Command_GetMap(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[itay-maploader] Usage: sm_getmap <mapname>");
        return Plugin_Handled;
    }

    char mapname[128];
    GetCmdArg(1, mapname, sizeof(mapname));
    
    DownloadMap(client, mapname, true);
    return Plugin_Handled;
}

void DownloadMap(int client, const char[] mapname, bool tryBz2)
{
    // 1. Check if map already exists on the server
    char bspRelative[128];
    Format(bspRelative, sizeof(bspRelative), "maps/%s.bsp", mapname);
    if (FileExists(bspRelative))
    {
        if (client) CPrintToChat(client, "{red}Error: {lightgrey}Map {orange}%s {lightgrey}already exists on the server.", mapname);
        return;
    }

    // 2. Check if a download for this map is already active
    int dummy;
    if (g_hActiveRequests.GetValue(mapname, dummy))
    {
        if (client) CPrintToChat(client, "{red}Error: {lightgrey}A download for {orange}%s {lightgrey} is already in progress.", mapname);
        return;
    }

    char baseURL[256];
    g_cvFastDLURL.GetString(baseURL, sizeof(baseURL));
    ReplaceString(baseURL, sizeof(baseURL), "https://", "http://");
    
    char url[512];
    Format(url, sizeof(url), "%s%s.bsp%s", baseURL, mapname, tryBz2 ? ".bz2" : "");

    char gamePath[256];
    g_cvMapsPath.GetString(gamePath, sizeof(gamePath));
    if (gamePath[0] == '\0')
    {
        System2_GetGameDir(gamePath, sizeof(gamePath));
    }

    int pathLen = strlen(gamePath);
    if (pathLen > 0 && gamePath[pathLen-1] != '/' && gamePath[pathLen-1] != '\\')
    {
        StrCat(gamePath, sizeof(gamePath), "/");
    }

    char localPath[256];
    if (StrContains(gamePath, "/maps", false) != -1)
    {
        Format(localPath, sizeof(localPath), "%s%s.bsp%s", gamePath, mapname, tryBz2 ? ".bz2" : "");
    }
    else
    {
        Format(localPath, sizeof(localPath), "%smaps/%s.bsp%s", gamePath, mapname, tryBz2 ? ".bz2" : "");
    }

    // Use curl directly via System2 - Simple and stable version
    char command[1024];
    Format(command, sizeof(command), "curl -4 -k -L -s \"%s\" -o \"%s\"", url, localPath);

    PrintToServer("[itay-maploader] Executing: %s", command);

    DataPack pack = new DataPack();
    pack.WriteCell((client == 0) ? 0 : GetClientUserId(client));
    pack.WriteString(mapname);
    pack.WriteCell(tryBz2 ? 1 : 0);
    pack.WriteString(localPath);

    // Give the timer a CLONE of the pack so they don't fight over the same handle
    DataPack timerPack = new DataPack();
    timerPack.WriteCell((client == 0) ? 0 : GetClientUserId(client));
    timerPack.WriteString(mapname);
    timerPack.WriteCell(tryBz2 ? 1 : 0);
    timerPack.WriteString(localPath);

    System2_ExecuteThreaded(OnCurlDownloadComplete, command, pack);
    g_hActiveRequests.SetValue(mapname, 1);

    // Track progress by checking file size on disk
    CreateTimer(0.5, Timer_TrackCurlProgress, timerPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    PrintToServer("[itay-maploader] Linux downloading %s to %s", url, localPath);
    if (client) CPrintToChat(client, "{lightgrey}Downloading {orange}%s{lightgrey} using Linux curl...", mapname);
}

public Action Timer_TrackCurlProgress(Handle timer, DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    char mapname[128];
    pack.ReadString(mapname, sizeof(mapname));
    pack.ReadCell(); // skip tryBz2
    char localPath[256];
    pack.ReadString(localPath, sizeof(localPath));

    int client = GetClientOfUserId(userid);
    
    // Check if download is still active in StringMap
    int dummy;
    if (!g_hActiveRequests.GetValue(mapname, dummy)) 
    {
        delete pack;
        return Plugin_Stop;
    }

    if (client && IsClientInGame(client) && FileExists(localPath))
    {
        int size = FileSize(localPath);
        if (size > 0)
        {
            float mb = float(size) / 1048576.0;
            PrintCenterText(client, "Downloading %s: %.1f MB", mapname, mb);
        }
    }
    
    return Plugin_Continue;
}

public void OnCurlDownloadComplete(bool success, const char[] command, System2ExecuteOutput output, any data)
{
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();
    int userid = pack.ReadCell();
    char mapname[128];
    pack.ReadString(mapname, sizeof(mapname));
    bool wasBz2 = (pack.ReadCell() == 1);
    char localPath[256];
    pack.ReadString(localPath, sizeof(localPath));

    g_hActiveRequests.Remove(mapname);

    int exitCode = (output != null) ? output.ExitStatus : -1;
    
    // Create a new pack for the delayed check
    DataPack checkPack = new DataPack();
    checkPack.WriteCell(userid);
    checkPack.WriteString(mapname);
    checkPack.WriteCell(wasBz2 ? 1 : 0);
    checkPack.WriteString(localPath);
    checkPack.WriteCell(exitCode);
    checkPack.WriteCell(success ? 1 : 0);

    // Wait 1.5 seconds for the filesystem to catch up
    CreateTimer(1.5, Timer_CheckDownloadedFile, checkPack);
    delete pack;
}

public Action Timer_CheckDownloadedFile(Handle timer, DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    char mapname[128];
    pack.ReadString(mapname, sizeof(mapname));
    bool wasBz2 = (pack.ReadCell() == 1);
    char localPath[256];
    pack.ReadString(localPath, sizeof(localPath));
    int exitCode = pack.ReadCell();
    bool success = (pack.ReadCell() == 1);
    delete pack;

    // Use Linux 'stat' to get size since SourceMod might block absolute paths
    char statCmd[512];
    Format(statCmd, sizeof(statCmd), "stat -c%%s \"%s\" || echo -1", localPath);
    
    DataPack statPack = new DataPack();
    statPack.WriteCell(userid);
    statPack.WriteString(mapname);
    statPack.WriteCell(wasBz2 ? 1 : 0);
    statPack.WriteString(localPath);
    statPack.WriteCell(exitCode);
    statPack.WriteCell(success ? 1 : 0);

    System2_ExecuteThreaded(OnStatSizeDone, statCmd, statPack);
    return Plugin_Stop;
}

public void OnStatSizeDone(bool success, const char[] command, System2ExecuteOutput output, any data)
{
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();
    int userid = pack.ReadCell();
    char mapname[128];
    pack.ReadString(mapname, sizeof(mapname));
    bool wasBz2 = (pack.ReadCell() == 1);
    char localPath[256];
    pack.ReadString(localPath, sizeof(localPath));
    int exitCode = pack.ReadCell();
    bool curlSuccess = (pack.ReadCell() == 1);
    delete pack;

    char res[64];
    output.GetOutput(res, sizeof(res));
    TrimString(res);
    int size = StringToInt(res);

    int client = GetClientOfUserId(userid);
    bool wasSuccess = (curlSuccess && (exitCode == 0 || exitCode == 5888) && size > 1000);

    PrintToServer("[itay-maploader] Linux Size Check: %s (Size: %d bytes, Exit: %d)", mapname, size, exitCode);

    if (!wasSuccess)
    {
        if (wasBz2)
        {
            DownloadMap(client, mapname, false); 
        }
        else
        {
            if (client) CPrintToChat(client, "{red}Error: {lightgrey}Download failed (Size: %d, Exit: %d)", size, exitCode);
        }
        return;
    }

    if (wasBz2)
    {
        if (client) CPrintToChat(client, "{green}Download complete (%d KB)! {lightgrey}Decompressing...", size / 1024);
        DecompressMap(client, mapname, localPath);
    }
    else
    {
        if (client) CPrintToChat(client, "{green}Download complete! {lightgrey}Map is ready.");
    }
}

public Action Command_BzipDebug(int client, int args)
{
    System2_ExecuteThreaded(OnBzipDebugDone, "bzip2 --help", (client == 0) ? 0 : GetClientUserId(client));
    return Plugin_Handled;
}

public void OnBzipDebugDone(bool success, const char[] command, System2ExecuteOutput output, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!success || output == null) return;
    char res[2048];
    output.GetOutput(res, sizeof(res));
    ReplyToCommand(client, "[itay-maploader] Bzip2 Help/Version:\n%s", res);
}

void DecompressMap(int client, const char[] mapname, const char[] bz2Path)
{
    if (!g_bHasBzip2)
    {
        if (client) CPrintToChat(client, "{red}Error: {lightgrey}bzip2 is not installed on this VPS.");
        return;
    }

    char bspPath[256];
    strcopy(bspPath, sizeof(bspPath), bz2Path);
    ReplaceString(bspPath, sizeof(bspPath), ".bz2", "");

    // Clean up "ghost" files (0-byte bsps)
    if (FileExists(bspPath) && FileSize(bspPath) <= 0)
    {
        DeleteFile(bspPath);
    }

    // Force full permissions on the bz2
    char chmodCmd[512];
    Format(chmodCmd, sizeof(chmodCmd), "chmod 777 \"%s\"", bz2Path);
    System2_ExecuteThreaded(OnNullCallback, chmodCmd);

    // Extract directory from bz2Path
    char dir[256], file[128];
    int lastSlash = -1;
    for (int i = 0; bz2Path[i] != '\0'; i++)
    {
        if (bz2Path[i] == '/' || bz2Path[i] == '\\') lastSlash = i;
    }

    if (lastSlash != -1)
    {
        strcopy(dir, lastSlash + 1, bz2Path);
        strcopy(file, sizeof(file), bz2Path[lastSlash + 1]);
    }
    else
    {
        strcopy(dir, sizeof(dir), ".");
        strcopy(file, sizeof(file), bz2Path);
    }

    // CD into the maps directory and run bzip2 -dskf (decompress, small memory, keep, force)
    char command[1024];
    Format(command, sizeof(command), "cd \"%s\" && bzip2 -dskf \"%s\" 2>&1", dir, file);
    
    DataPack pack = new DataPack();
    pack.WriteCell(client ? GetClientUserId(client) : 0);
    pack.WriteString(mapname);
    pack.WriteString(bz2Path);

    System2_ExecuteThreaded(OnDecompressFinished, command, pack);
}

public void OnNullCallback(bool success, const char[] command, System2ExecuteOutput output, any data) {}

public void OnDecompressFinished(bool success, const char[] command, System2ExecuteOutput output, any data)
{
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();
    int userid = pack.ReadCell();
    char mapname[128];
    pack.ReadString(mapname, sizeof(mapname));
    char bz2Path[256];
    pack.ReadString(bz2Path, sizeof(bz2Path));
    delete pack;

    int client = GetClientOfUserId(userid);
    int exitCode = (output != null) ? output.ExitStatus : -1;

    // Trust the Linux exit code (0 = Success)
    if (success && exitCode == 0)
    {
        if (client) CPrintToChat(client, "{green}Map %s decompressed and ready!", mapname);
        CPrintToChatAll("{green}[itay-maploader] {lightgrey}Map {orange}%s {lightgrey}is now available!", mapname);
    }
    else
    {
        if (client) CPrintToChat(client, "{red}Error: {lightgrey}Decompression failed for %s (Code %d).", mapname, exitCode);
        if (output != null)
        {
            char out[1024];
            output.GetOutput(out, sizeof(out));
            PrintToServer("[itay-maploader] Decompression Error Output:\n%s", out);
        }
    }
}

// =============================================================================
// Debug Commands
// =============================================================================

public Action Command_MapDebug(int client, int args)
{
    char gamePath[256];
    System2_GetGameDir(gamePath, sizeof(gamePath));
    
    char mapsPath[256];
    g_cvMapsPath.GetString(mapsPath, sizeof(mapsPath));
    
    ReplyToCommand(client, "[itay-maploader] Debug Info:");
    ReplyToCommand(client, "Game Folder: %s", gamePath);
    ReplyToCommand(client, "Configured Maps Path: %s", mapsPath[0] == '\0' ? "AUTO" : mapsPath);
    ReplyToCommand(client, "bzip2 support: %s", g_bHasBzip2 ? "YES" : "NO");
    
    return Plugin_Handled;
}

public Action Command_FindMap(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[itay-maploader] Usage: sm_findmap <mapname>");
        return Plugin_Handled;
    }
    char mapname[128];
    GetCmdArg(1, mapname, sizeof(mapname));
    char command[256];
    Format(command, sizeof(command), "find . -name \"%s*\" -print", mapname);
    ReplyToCommand(client, "Searching for '%s'...", mapname);
    System2_ExecuteThreaded(OnFindMapDone, command, GetClientUserId(client));
    return Plugin_Handled;
}

public void OnFindMapDone(bool success, const char[] command, System2ExecuteOutput output, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!success || output == null) return;
    char res[1024];
    output.GetOutput(res, sizeof(res));
    if (client) ReplyToCommand(client, "[itay-maploader] Found:\n%s", res[0] == '\0' ? "NOT FOUND" : res);
}

public Action Command_Pwd(int client, int args)
{
    System2_ExecuteThreaded(OnPwdDone, "pwd", (client == 0) ? 0 : GetClientUserId(client));
    return Plugin_Handled;
}

public void OnPwdDone(bool success, const char[] command, System2ExecuteOutput output, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!success || output == null) return;
    char res[256];
    output.GetOutput(res, sizeof(res));
    ReplyToCommand(client, "[itay-maploader] Current Working Dir: %s", res);
}

public Action Command_Dir(int client, int args)
{
    char gamePath[256];
    g_cvMapsPath.GetString(gamePath, sizeof(gamePath));
    if (gamePath[0] == '\0') System2_GetGameDir(gamePath, sizeof(gamePath));
    
    int len = strlen(gamePath);
    if (len > 0 && gamePath[len-1] != '/') StrCat(gamePath, sizeof(gamePath), "/");

    char target[256];
    Format(target, sizeof(target), "%smaps", gamePath);
    
    char cmd[512];
    Format(cmd, sizeof(cmd), "ls -la \"%s\"", target);
    System2_ExecuteThreaded(OnDirDone, cmd, (client == 0) ? 0 : GetClientUserId(client));
    return Plugin_Handled;
}

public void OnDirDone(bool success, const char[] command, System2ExecuteOutput output, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!success || output == null) return;
    char res[2048];
    output.GetOutput(res, sizeof(res));
    ReplyToCommand(client, "[itay-maploader] Directory Listing:\n%s", res);
}

public Action Command_CurlDebug(int client, int args)
{
    System2_ExecuteThreaded(OnCurlDebugDone, "curl -V", (client == 0) ? 0 : GetClientUserId(client));
    return Plugin_Handled;
}

public void OnCurlDebugDone(bool success, const char[] command, System2ExecuteOutput output, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!success || output == null) return;
    char res[2048];
    output.GetOutput(res, sizeof(res));
    ReplyToCommand(client, "[itay-maploader] Curl Version:\n%s", res);
}

public Action Command_CheckPerm(int client, int args)
{
    char gamePath[256];
    g_cvMapsPath.GetString(gamePath, sizeof(gamePath));
    if (gamePath[0] == '\0') System2_GetGameDir(gamePath, sizeof(gamePath));
    
    int len = strlen(gamePath);
    if (len > 0 && gamePath[len-1] != '/') StrCat(gamePath, sizeof(gamePath), "/");

    char target[256];
    Format(target, sizeof(target), "%smaps", gamePath);

    ReplyToCommand(client, "[itay-maploader] Checking permissions for: %s", target);
    
    char command[512];
    Format(command, sizeof(command), "ls -ld \"%s\" && id && touch \"%s/test_itay.txt\" && rm \"%s/test_itay.txt\" && echo 'WRITE_SUCCESS' || echo 'WRITE_FAILED'", target, target, target);
    
    System2_ExecuteThreaded(OnCheckPermDone, command, (client == 0) ? 0 : GetClientUserId(client));
    return Plugin_Handled;
}

public void OnCheckPermDone(bool success, const char[] command, System2ExecuteOutput output, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!success || output == null) return;
    
    char res[2048];
    output.GetOutput(res, sizeof(res));
    
    if (client)
    {
        ReplyToCommand(client, "[itay-maploader] Permission Result:\n%s", res);
        if (StrContains(res, "WRITE_SUCCESS") != -1)
            CPrintToChat(client, "{green}Success! {lightgrey}The folder is writable.");
        else
            CPrintToChat(client, "{red}Failed! {lightgrey}The folder is NOT writable. Run 'chmod 777' on the maps folder.");
    }
}

public Action Command_DebugPath(int client, int args)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "");
    ReplyToCommand(client, "SM Path: %s", path);
    return Plugin_Handled;
}
