// TestAntiDebug.cpp — padrao de saida alinhado ao artigo SBSeg 2025
#include <windows.h>
#include <winternl.h>
#include <cstdio>
#include "..\TomwareLoop.h"

#pragma comment(lib, "ntdll.lib")

#ifndef ProcessDebugObjectHandle
#define ProcessDebugObjectHandle ((PROCESSINFOCLASS)30)
#endif

#if defined(_WIN64)
#define TOMWARE_PEB_OFFSET_NTGLOBALFLAG 0xBC
#else
#define TOMWARE_PEB_OFFSET_NTGLOBALFLAG 0x68
#endif

using NtQueryInformationProcessFn = NTSTATUS(NTAPI*)(
    HANDLE, PROCESSINFOCLASS, PVOID, ULONG, PULONG);

struct AntiDebugCounts {
    size_t isDebuggerPresent;
    size_t remoteDebugger;
    size_t debugPort;
    size_t debugObject;
    size_t beingDebugged;
    size_t ntGlobalFlag;
};

static AntiDebugCounts RunOnce(bool verbose)
{
    AntiDebugCounts c = {};

    if (IsDebuggerPresent()) {
        c.isDebuggerPresent = 1;
        if (verbose) printf("  \"IsDebuggerPresent\"\n");
    }

    BOOL remote = FALSE;
    CheckRemoteDebuggerPresent(GetCurrentProcess(), &remote);
    if (remote) {
        c.remoteDebugger = 1;
        if (verbose) printf("  \"CheckRemoteDebuggerPresent\"\n");
    }

    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    auto query = reinterpret_cast<NtQueryInformationProcessFn>(
        GetProcAddress(ntdll, "NtQueryInformationProcess"));

    if (query) {
        HANDLE hPort = nullptr;
        query(GetCurrentProcess(), ProcessDebugPort, &hPort, sizeof(hPort), nullptr);
        if (hPort != nullptr) {
            c.debugPort = 1;
            if (verbose) printf("  \"ProcessDebugPort\"\n");
        }

        HANDLE hObj = nullptr;
        query(GetCurrentProcess(), ProcessDebugObjectHandle, &hObj, sizeof(hObj), nullptr);
        if (hObj != nullptr) {
            c.debugObject = 1;
            if (verbose) printf("  \"ProcessDebugObjectHandle\"\n");
        }
    }

    PPEB peb = reinterpret_cast<PPEB>(NtCurrentTeb()->ProcessEnvironmentBlock);
    if (peb->BeingDebugged) {
        c.beingDebugged = 1;
        if (verbose) printf("  \"PEB.BeingDebugged\"\n");
    }

    PULONG pNtGlobalFlag = reinterpret_cast<PULONG>(
        reinterpret_cast<PUCHAR>(peb) + TOMWARE_PEB_OFFSET_NTGLOBALFLAG);
    if (*pNtGlobalFlag & 0x70) {
        c.ntGlobalFlag = 1;
        if (verbose) printf("  \"PEB.NtGlobalFlag\"\n");
    }

    return c;
}

static void PrintResumo(const AntiDebugCounts& c)
{
    printf("Ocorr\xC3\xAAncias:\n\n");
    printf("Resumo de ocorr\xC3\xAAncias:\n");
    printf("IsDebuggerPresent          : %zu\n", c.isDebuggerPresent);
    printf("CheckRemoteDebuggerPresent : %zu\n", c.remoteDebugger);
    printf("ProcessDebugPort           : %zu\n", c.debugPort);
    printf("ProcessDebugObjectHandle   : %zu\n", c.debugObject);
    printf("PEB.BeingDebugged          : %zu\n", c.beingDebugged);
    printf("PEB.NtGlobalFlag           : %zu\n", c.ntGlobalFlag);

    bool anyAlert = false;
    if (c.isDebuggerPresent > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"IsDebuggerPresent\" encontradas!\n");
        anyAlert = true;
    }
    if (c.remoteDebugger > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"CheckRemoteDebuggerPresent\" encontradas!\n");
        anyAlert = true;
    }
    if (c.debugPort > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"ProcessDebugPort\" encontradas!\n");
        anyAlert = true;
    }
    if (c.debugObject > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"ProcessDebugObjectHandle\" encontradas!\n");
        anyAlert = true;
    }
    if (c.beingDebugged > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"PEB.BeingDebugged\" encontradas!\n");
        anyAlert = true;
    }
    if (c.ntGlobalFlag > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"PEB.NtGlobalFlag\" encontradas!\n");
        anyAlert = true;
    }

    if (!anyAlert)
        printf("OK - nenhuma anomalia\n");

    printf("-------------------------------\n");
}

int main()
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);

    TomwarePrintLoopHeader("TestAntiDebug");
    const ULONGLONG t0 = TomwareNowMs();

    AntiDebugCounts totals = {};
    for (int iter = 0; iter < TOMWARE_LOOP_COUNT; ++iter) {
        const bool verbose = (TOMWARE_LOOP_COUNT == 1);
        AntiDebugCounts pass = RunOnce(verbose);
        totals.isDebuggerPresent += pass.isDebuggerPresent;
        totals.remoteDebugger += pass.remoteDebugger;
        totals.debugPort += pass.debugPort;
        totals.debugObject += pass.debugObject;
        totals.beingDebugged += pass.beingDebugged;
        totals.ntGlobalFlag += pass.ntGlobalFlag;
    }

    if (TOMWARE_LOOP_COUNT > 1) {
        // Indicadores 0/1: qualquer deteccao nas iteracoes conta como 1 no resumo.
        totals.isDebuggerPresent = totals.isDebuggerPresent ? 1 : 0;
        totals.remoteDebugger = totals.remoteDebugger ? 1 : 0;
        totals.debugPort = totals.debugPort ? 1 : 0;
        totals.debugObject = totals.debugObject ? 1 : 0;
        totals.beingDebugged = totals.beingDebugged ? 1 : 0;
        totals.ntGlobalFlag = totals.ntGlobalFlag ? 1 : 0;
    }

    PrintResumo(totals);
    TomwarePrintLoopFooter(t0);
    return 0;
}
