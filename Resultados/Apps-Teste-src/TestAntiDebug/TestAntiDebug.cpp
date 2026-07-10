// TestAntiDebug.cpp — PoC de deteccao anti-debug
#include <windows.h>
#include <winternl.h>
#include <cstdio>

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

static bool CheckNtDebugPort(NtQueryInformationProcessFn query, bool* detected)
{
    HANDLE debugPort = nullptr;
    NTSTATUS status = query(
        GetCurrentProcess(),
        ProcessDebugPort,
        &debugPort,
        sizeof(debugPort),
        nullptr);

    printf("NtQueryInformationProcess(ProcessDebugPort): status=0x%lx port=%p\n",
        static_cast<unsigned long>(status), debugPort);

    if (debugPort != nullptr) {
        printf("*** Debug port detectado ***\n");
        *detected = true;
        return true;
    }
    return false;
}

static bool CheckNtDebugObject(NtQueryInformationProcessFn query, bool* detected)
{
    HANDLE debugObject = nullptr;
    NTSTATUS status = query(
        GetCurrentProcess(),
        ProcessDebugObjectHandle,
        &debugObject,
        sizeof(debugObject),
        nullptr);

    printf("NtQueryInformationProcess(ProcessDebugObjectHandle): status=0x%lx handle=%p\n",
        static_cast<unsigned long>(status), debugObject);

    if (debugObject != nullptr) {
        printf("*** Debug object detectado ***\n");
        *detected = true;
        return true;
    }
    return false;
}

static bool CheckPeb(bool* detected)
{
    PPEB peb = reinterpret_cast<PPEB>(NtCurrentTeb()->ProcessEnvironmentBlock);
    printf("PEB.BeingDebugged = %d\n", static_cast<int>(peb->BeingDebugged));

    if (peb->BeingDebugged) {
        printf("*** PEB.BeingDebugged ativo ***\n");
        *detected = true;
    }

    PULONG ntGlobalFlag = reinterpret_cast<PULONG>(
        reinterpret_cast<PUCHAR>(peb) + TOMWARE_PEB_OFFSET_NTGLOBALFLAG);
    printf("PEB.NtGlobalFlag = 0x%lx\n", static_cast<unsigned long>(*ntGlobalFlag));

    if (*ntGlobalFlag & 0x70) {
        printf("*** PEB.NtGlobalFlag indica heap de debug ***\n");
        *detected = true;
    }

    return peb->BeingDebugged != 0;
}

int main()
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);

    bool detected = false;

    BOOL present = IsDebuggerPresent();
    printf("IsDebuggerPresent = %d\n", present);
    if (present)
        detected = true;

    BOOL remote = FALSE;
    CheckRemoteDebuggerPresent(GetCurrentProcess(), &remote);
    printf("CheckRemoteDebuggerPresent = %d\n", remote);
    if (remote)
        detected = true;

    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    auto query = reinterpret_cast<NtQueryInformationProcessFn>(
        GetProcAddress(ntdll, "NtQueryInformationProcess"));

    if (query) {
        CheckNtDebugPort(query, &detected);
        CheckNtDebugObject(query, &detected);
    }
    else {
        printf("GetProcAddress(NtQueryInformationProcess) falhou\n");
    }

    CheckPeb(&detected);

    if (detected)
        printf("Resultado: ambiente de debug detectado\n");
    else
        printf("Resultado: nenhum indicador basico de debug\n");

    return 0;
}
