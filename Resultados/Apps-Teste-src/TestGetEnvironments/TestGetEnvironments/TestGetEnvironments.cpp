// TestGetEnvironments.cpp — padrao de saida alinhado ao artigo SBSeg 2025
#include <windows.h>
#include <iostream>
#include <string>
#include <cstdio>
#include "Measurement.h"
#include "..\..\TomwareLoop.h"

struct EnvSig {
    const wchar_t* name;
    size_t count;
    size_t alertThreshold;
};

static void GetEnvString(EnvSig* sigs, size_t nSigs, bool verbose)
{
    LPWCH envBlock = GetEnvironmentStringsW();
    if (envBlock == nullptr)
    {
        fprintf(stderr, "Falha em GetEnvironmentStringsW. Erro = %lu\n", GetLastError());
        return;
    }

    LPWCH current = envBlock;
    while (*current)
    {
        std::wstring envVar(current);

        for (size_t i = 0; i < nSigs; ++i) {
            if (envVar.find(sigs[i].name) != std::wstring::npos) {
                ++sigs[i].count;
                if (verbose)
                    printf("  \"%ls\"\n", envVar.c_str());
            }
        }

        current += envVar.size() + 1;
    }

    if (!FreeEnvironmentStringsW(envBlock))
    {
        fprintf(stderr, "Falha em FreeEnvironmentStringsW. Erro = %lu\n", GetLastError());
    }
}

static void Dupenv(bool verbose)
{
    char* pValue = nullptr;
    size_t len = 0;
    errno_t err = _dupenv_s(&pValue, &len, "PIN_CRT_TZDATA");
    if (!err && pValue) {
        if (verbose)
            printf("  \"PIN_CRT_TZDATA=%s\" (_dupenv_s)\n", pValue);
        free(pValue);
    }
}

static void PrintResumo(const EnvSig* sigs, size_t nSigs)
{
    printf("Ocorr\xC3\xAAncias:\n\n");
    printf("Resumo de ocorr\xC3\xAAncias:\n");
    printf("PIN_APP_LD_LIBRARY_PATH : %zu\n", sigs[0].count);
    printf("PIN_VM_LD_LIBRARY_PATH  : %zu\n", sigs[1].count);
    printf("PIN_CRT_TZDATA          : %zu\n", sigs[2].count);

    bool anyAlert = false;
    for (size_t i = 0; i < nSigs; ++i) {
        if (sigs[i].count > sigs[i].alertThreshold) {
            printf("Alerta: mais de %zu ocorr\xC3\xAAncias de \"%ls\" encontradas!\n",
                sigs[i].alertThreshold, sigs[i].name);
            anyAlert = true;
        }
    }

    if (!anyAlert)
        printf("OK - nenhuma anomalia\n");

    printf("-------------------------------\n");
}

int wmain()
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);

    TomwarePrintLoopHeader("TestGetEnvironments");
    const ULONGLONG t0 = TomwareNowMs();

    EnvSig totals[] = {
        { L"PIN_APP_LD_LIBRARY_PATH", 0, 0 },
        { L"PIN_VM_LD_LIBRARY_PATH",  0, 0 },
        { L"PIN_CRT_TZDATA",          0, 0 }
    };
    const size_t nSigs = sizeof(totals) / sizeof(totals[0]);

    for (int iter = 0; iter < TOMWARE_LOOP_COUNT; ++iter) {
        EnvSig pass[] = {
            { L"PIN_APP_LD_LIBRARY_PATH", 0, 0 },
            { L"PIN_VM_LD_LIBRARY_PATH",  0, 0 },
            { L"PIN_CRT_TZDATA",          0, 0 }
        };
        const bool verbose = (TOMWARE_LOOP_COUNT == 1);
        GetEnvString(pass, nSigs, verbose);
        Dupenv(verbose);
        for (size_t i = 0; i < nSigs; ++i)
            totals[i].count += pass[i].count;
    }

    if (TOMWARE_LOOP_COUNT > 1) {
        for (size_t i = 0; i < nSigs; ++i)
            totals[i].count = totals[i].count / static_cast<size_t>(TOMWARE_LOOP_COUNT);
    }

    PrintResumo(totals, nSigs);
    TomwarePrintLoopFooter(t0);
    return 0;
}
