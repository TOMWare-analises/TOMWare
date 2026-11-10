#pragma once
#ifndef TOMWARE_LOG_H
#define TOMWARE_LOG_H

#include "pin.H"
#include <string>

void TomwareSetQuietMode(BOOL quiet);
BOOL TomwareIsQuiet();

// Always emitted (errors, exceptions, critical warnings).
void TomwareLogErr(const std::string& msg);

// Suppressed when quiet mode (-q) is on.
void TomwareLogInfo(const std::string& msg);
void TomwareLogInfoW(const std::wstring& msg);

#endif // TOMWARE_LOG_H
