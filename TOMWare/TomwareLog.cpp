#include "TomwareLog.h"

#include <iostream>

static BOOL s_quietMode = FALSE;

void TomwareSetQuietMode(BOOL quiet)
{
    s_quietMode = quiet;
}

BOOL TomwareIsQuiet()
{
    return s_quietMode;
}

void TomwareLogErr(const std::string& msg)
{
    std::cerr << msg << std::endl;
}

void TomwareLogInfo(const std::string& msg)
{
    if (s_quietMode)
        return;
    std::cout << msg << std::endl;
}

void TomwareLogInfoW(const std::wstring& msg)
{
    if (s_quietMode)
        return;
    std::wcout << msg << std::endl;
}
