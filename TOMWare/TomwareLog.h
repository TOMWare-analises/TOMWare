#pragma once
#ifndef TOMWARE_LOG_H
#define TOMWARE_LOG_H

#include "pin.H"
#include <string>

void TomwareSetQuietMode(BOOL quiet);
BOOL TomwareIsQuiet();

// Sempre emitido (erros, exceções, avisos críticos).
void TomwareLogErr(const std::string& msg);

// Suprimido quando o modo silencioso (-q) está ativo.
void TomwareLogInfo(const std::string& msg);
void TomwareLogInfoW(const std::wstring& msg);

#endif // TOMWARE_LOG_H
