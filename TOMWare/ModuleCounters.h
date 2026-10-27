#pragma once
#ifndef MODULE_COUNTERS_H
#define MODULE_COUNTERS_H

#include "pin.H"
#include <string>

// Contadores internos opcionais para verificar acionamento efetivo dos módulos (TOMWare.M)
// Desativados por padrão (-mc 0): overhead rigorosamente nulo.

void ModuleCounters_Init();
bool ModuleCounters_IsEnabled();
void ModuleCounters_DumpJson();

// AntiDebug
void ModuleCounters_AntiDebug_OnInit();
void ModuleCounters_AntiDebug_OnSanitize(int bdBefore, int bdAfter, unsigned long ntgBefore, unsigned long ntgAfter, bool fault);

// ProcessEnum
void ModuleCounters_ProcessEnum_OnCall();
void ModuleCounters_ProcessEnum_OnProcessExamined(bool filtered);
void ModuleCounters_ProcessEnum_OnModuleExamined(bool filtered);
void ModuleCounters_ProcessEnum_OnUnmodified();

// SanitizePinEnvVars
void ModuleCounters_Env_OnExamined();
void ModuleCounters_Env_OnPinFound();
void ModuleCounters_Env_OnSanitized();
void ModuleCounters_Env_OnFault();

// InstMemcmpMask
void ModuleCounters_Memcmp_OnIntercept();
void ModuleCounters_Memcmp_OnSignatureMatched();
void ModuleCounters_Memcmp_OnModified();
void ModuleCounters_Memcmp_OnForwarded();

// SkewMask
void ModuleCounters_Skew_OnSleep(double requestedMs, double observedMs);
void ModuleCounters_Skew_OnTimeQuery(INT64 skewTicksApplied);
void ModuleCounters_Skew_OnRegression();

#endif // MODULE_COUNTERS_H
