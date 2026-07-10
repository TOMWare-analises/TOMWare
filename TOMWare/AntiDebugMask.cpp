#include "AntiDebugMask.h"
#include "TomwareLog.h"
#include "utils.h"

#if defined(TARGET_IA32E) || defined(_WIN64)
#define TOMWARE_PEB_OFFSET_NTGLOBALFLAG 0xBC
#else
#define TOMWARE_PEB_OFFSET_NTGLOBALFLAG 0x68
#endif

static PPEB TomwareCurrentPeb()
{
    return reinterpret_cast<PPEB>(WindowsAPI::NtCurrentTeb()->ProcessEnvironmentBlock);
}

static void SanitizePeb(PPEB peb)
{
    if (!peb)
        return;

    peb->BeingDebugged = 0;

    PULONG ntGlobalFlag = reinterpret_cast<PULONG>(
        reinterpret_cast<PUCHAR>(peb) + TOMWARE_PEB_OFFSET_NTGLOBALFLAG);
    if (PIN_CheckWriteAccess(ntGlobalFlag))
        *ntGlobalFlag = 0;
}

static void SimulateDebugPeb(PPEB peb)
{
    if (!peb)
        return;

    peb->BeingDebugged = 1;

    PULONG ntGlobalFlag = reinterpret_cast<PULONG>(
        reinterpret_cast<PUCHAR>(peb) + TOMWARE_PEB_OFFSET_NTGLOBALFLAG);
    if (PIN_CheckWriteAccess(ntGlobalFlag))
        *ntGlobalFlag |= 0x70;
}

static VOID AntiDebugMask_ApplicationStart(VOID*)
{
    SanitizePeb(TomwareCurrentPeb());
    TomwareLogInfo("[AntiDebugMask] ApplicationStart: PEB sanitizado");
}

static VOID AntiDebugMask_SimulateDebug_ApplicationStart(VOID*)
{
    SimulateDebugPeb(TomwareCurrentPeb());
    TomwareLogInfo("[AntiDebugMask] ApplicationStart: indicadores de debug simulados no PEB");
}

VOID AntiDebugMask_OnMainExecutable()
{
    SanitizePeb(TomwareCurrentPeb());
    TomwareLogInfo("[AntiDebugMask] PEB do processo alvo sanitizado na carga");
}

VOID AntiDebugMask_Init()
{
    PIN_AddApplicationStartFunction(AntiDebugMask_ApplicationStart, 0);
}

VOID AntiDebugMask_SimulateDebug_Init()
{
    PIN_AddApplicationStartFunction(AntiDebugMask_SimulateDebug_ApplicationStart, 0);
}
