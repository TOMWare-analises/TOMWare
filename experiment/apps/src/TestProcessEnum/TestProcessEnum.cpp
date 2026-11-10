// TestProcessEnum.cpp — padrao de saida alinhado ao artigo SBSeg 2025
#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>
#include <cstdio>
#include "..\TomwareLoop.h"

static std::wstring BaseNameW(const wchar_t* path)
{
    if (!path || !*path)
        return {};
    const wchar_t* slash = wcsrchr(path, L'\\');
    if (!slash)
        slash = wcsrchr(path, L'/');
    return slash ? std::wstring(slash + 1) : std::wstring(path);
}

static bool EqualsNoCaseW(const std::wstring& a, const std::wstring& b)
{
    if (a.size() != b.size())
        return false;
    for (size_t i = 0; i < a.size(); ++i)
        if (towlower(a[i]) != towlower(b[i]))
            return false;
    return true;
}

struct ProcessEnumCounts {
    size_t pinExe;
    size_t pinvm;
    size_t pinipc;
    size_t tomware;
};

static ProcessEnumCounts RunOnce(bool verbose)
{
    ProcessEnumCounts c = {};

    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap != INVALID_HANDLE_VALUE)
    {
        PROCESSENTRY32W pe = { sizeof(pe) };
        if (Process32FirstW(snap, &pe))
        {
            do
            {
                std::wstring name = BaseNameW(pe.szExeFile);
                if (EqualsNoCaseW(name, L"pin.exe"))
                {
                    ++c.pinExe;
                    if (verbose)
                        printf("  \"pin.exe\" pid=%lu\n", pe.th32ProcessID);
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
    }

    struct ModSig { const char* name; size_t* counter; };
    ModSig mods[] = {
        { "pinvm.dll", &c.pinvm },
        { "pinipc.dll", &c.pinipc },
        { "TOMWare.dll", &c.tomware }
    };
    for (const ModSig& m : mods)
    {
        HMODULE mod = GetModuleHandleA(m.name);
        if (mod)
        {
            ++(*m.counter);
            if (verbose)
                printf("  \"%s\"\n", m.name);
        }
    }

    return c;
}

static void PrintResumo(const ProcessEnumCounts& c)
{
    printf("Ocorr\xC3\xAAncias:\n\n");
    printf("Resumo de ocorr\xC3\xAAncias:\n");
    printf("pin.exe     : %zu\n", c.pinExe);
    printf("pinvm.dll   : %zu\n", c.pinvm);
    printf("pinipc.dll  : %zu\n", c.pinipc);
    printf("TOMWare.dll : %zu\n", c.tomware);

    bool anyAlert = false;
    if (c.pinExe > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"pin.exe\" encontradas!\n");
        anyAlert = true;
    }
    if (c.pinvm > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"pinvm.dll\" encontradas!\n");
        anyAlert = true;
    }
    if (c.pinipc > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"pinipc.dll\" encontradas!\n");
        anyAlert = true;
    }
    if (c.tomware > 0) {
        printf("Alerta: mais de 0 ocorr\xC3\xAAncias de \"TOMWare.dll\" encontradas!\n");
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

    TomwarePrintLoopHeader("TestProcessEnum");
    const ULONGLONG t0 = TomwareNowMs();

    ProcessEnumCounts totals = {};
    for (int iter = 0; iter < TOMWARE_LOOP_COUNT; ++iter) {
        const bool verbose = (TOMWARE_LOOP_COUNT == 1);
        ProcessEnumCounts pass = RunOnce(verbose);
        totals.pinExe += pass.pinExe;
        totals.pinvm += pass.pinvm;
        totals.pinipc += pass.pinipc;
        totals.tomware += pass.tomware;
    }

    if (TOMWARE_LOOP_COUNT > 1) {
        totals.pinExe = totals.pinExe / static_cast<size_t>(TOMWARE_LOOP_COUNT);
        totals.pinvm = totals.pinvm / static_cast<size_t>(TOMWARE_LOOP_COUNT);
        totals.pinipc = totals.pinipc / static_cast<size_t>(TOMWARE_LOOP_COUNT);
        totals.tomware = totals.tomware / static_cast<size_t>(TOMWARE_LOOP_COUNT);
    }

    PrintResumo(totals);
    TomwarePrintLoopFooter(t0);
    return 0;
}
