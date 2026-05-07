#if defined _itay_colors_included
    #endinput
#endif
#define _itay_colors_included

#include <sourcemod>

/**
 * Replaces our unified color tags with Source Engine's exact hex string bytes.
 */
stock void CColorize(char[] buffer, int maxlen)
{
    ReplaceString(buffer, maxlen, "{default}", "\x01", false);    // Default White/Yellow
    ReplaceString(buffer, maxlen, "{team}", "\x03", false);       // Team Color
    ReplaceString(buffer, maxlen, "{green}", "\x04", false);      // Light Green
    ReplaceString(buffer, maxlen, "{olive}", "\x05", false);      // Olive
    ReplaceString(buffer, maxlen, "{lime}", "\x06", false);       // Lime

    ReplaceString(buffer, maxlen, "{red}", "\x07FF4040", false);
    ReplaceString(buffer, maxlen, "{lightred}", "\x07FF8080", false);
    ReplaceString(buffer, maxlen, "{blue}", "\x0700A1FF", false);
    ReplaceString(buffer, maxlen, "{darkblue}", "\x0700008B", false);
    ReplaceString(buffer, maxlen, "{purple}", "\x07800080", false);
    ReplaceString(buffer, maxlen, "{yellow}", "\x07FFFF00", false);
    ReplaceString(buffer, maxlen, "{orange}", "\x07FFA500", false);
    ReplaceString(buffer, maxlen, "{grey}", "\x07808080", false);
    ReplaceString(buffer, maxlen, "{gray}", "\x07808080", false);
    ReplaceString(buffer, maxlen, "{lightgrey}", "\x07CCCCCC", false);
    ReplaceString(buffer, maxlen, "{cyan}", "\x0700FFFF", false);
    ReplaceString(buffer, maxlen, "{magenta}", "\x07FF00FF", false);
    ReplaceString(buffer, maxlen, "{white}", "\x07FFFFFF", false);
}

/**
 * Prints a colorized message to a specific client.
 * Pre-pends the standard timer prefix automatically.
 */
stock void CPrintToChat(int client, const char[] format, any...)
{
    if (!client || !IsClientInGame(client)) return;

    SetGlobalTransTarget(client);

    char prefix[128];
    if (!TranslationPhraseExists("ChatPrefix") || !Format(prefix, sizeof(prefix), "%T", "ChatPrefix", client))
    {
        Format(prefix, sizeof(prefix), "\x01\x04[TIMER]\x01 ");
    }

    // VFormat binds the variadic arguments (like the number inside {1}) synchronously.
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 3);

    char finalBuffer[1024];
    Format(finalBuffer, sizeof(finalBuffer), "\x01%s%s", prefix, buffer);

    CColorize(finalBuffer, sizeof(finalBuffer));

    Handle hBf = StartMessageOne("SayText2", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
    if (hBf != null)
    {
        BfWriteByte(hBf, client);
        BfWriteByte(hBf, true);
        BfWriteString(hBf, finalBuffer);
        EndMessage();
    }
}

/**
 * Prints a colorized message to a specific client WITHOUT a prefix.
 */
stock void CPrintToChatEx(int client, const char[] format, any...)
{
    if (!client || !IsClientInGame(client)) return;

    SetGlobalTransTarget(client);

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 3);

    char finalBuffer[1024];
    FormatEx(finalBuffer, sizeof(finalBuffer), "\x01%s", buffer);

    CColorize(finalBuffer, sizeof(finalBuffer));

    Handle hBf = StartMessageOne("SayText2", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
    if (hBf != null)
    {
        BfWriteByte(hBf, client);
        BfWriteByte(hBf, true);
        BfWriteString(hBf, finalBuffer);
        EndMessage();
    }
}

/**
 * Prints a colorized message globally.
 */
stock void CPrintToChatAll(const char[] format, any...)
{
    SetGlobalTransTarget(LANG_SERVER);

    char prefix[128];
    if (!TranslationPhraseExists("ChatPrefix") || !Format(prefix, sizeof(prefix), "%T", "ChatPrefix", LANG_SERVER))
    {
        Format(prefix, sizeof(prefix), "\x01\x04[TIMER]\x01 ");
    }

    // VFormat needs to compile the actual raw parameters first
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);

    char finalBuffer[1024];
    Format(finalBuffer, sizeof(finalBuffer), "\x01%s%s", prefix, buffer);

    CColorize(finalBuffer, sizeof(finalBuffer));

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            Handle hBf = StartMessageOne("SayText2", i, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
            if (hBf != null)
            {
                BfWriteByte(hBf, i);    // The sender logic triggers Team Color context
                BfWriteByte(hBf, true);
                BfWriteString(hBf, finalBuffer);
                EndMessage();
            }
        }
    }
}

/**
 * Prints a colorized message globally WITHOUT a prefix.
 */
stock void CPrintToChatAllEx(const char[] format, any...)
{
    SetGlobalTransTarget(LANG_SERVER);

    // VFormat needs to compile the actual raw parameters first
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);

    char finalBuffer[1024];
    FormatEx(finalBuffer, sizeof(finalBuffer), "\x01%s", buffer);

    CColorize(finalBuffer, sizeof(finalBuffer));

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            Handle hBf = StartMessageOne("SayText2", i, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
            if (hBf != null)
            {
                BfWriteByte(hBf, i);
                BfWriteByte(hBf, true);
                BfWriteString(hBf, finalBuffer);
                EndMessage();
            }
        }
    }
}

/**
 * Prints a colorized message ONLY to staff members (admins).
 * Pre-pends the admin [ADMIN] prefix automatically.
 */
stock void CPrintToAdmins(const char[] format, any...)
{
    SetGlobalTransTarget(LANG_SERVER);

    char prefix[128];
    // Attempt to load AdminPrefix, fall back if missing
    if (!Format(prefix, sizeof(prefix), "%T", "AdminPrefix", LANG_SERVER))
    {
        Format(prefix, sizeof(prefix), "\x01\x07FF0000[ADMIN]\x01 ");
    }

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);

    char finalBuffer[1024];
    Format(finalBuffer, sizeof(finalBuffer), "\x01%s%s", prefix, buffer);

    CColorize(finalBuffer, sizeof(finalBuffer));

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetUserFlagBits(i) != 0)
        {
            Handle hBf = StartMessageOne("SayText2", i, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
            if (hBf != null)
            {
                BfWriteByte(hBf, i);
                BfWriteByte(hBf, true);
                BfWriteString(hBf, finalBuffer);
                EndMessage();
            }
        }
    }
}
