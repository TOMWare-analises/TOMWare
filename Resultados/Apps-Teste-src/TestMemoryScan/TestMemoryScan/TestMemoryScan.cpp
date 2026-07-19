#include <windows.h>
#include <iostream>
#include <string>
#include <cctype>
#include "Measurement.h"
#include "..\..\TomwareLoop.h"

struct SigInfo {
    const char* pat;
    size_t len;
    size_t count;
    size_t alertThreshold;
};

static void ScanMemoryForPinStrings(SigInfo* sigs, size_t nSigs, bool verbose)
{
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    BYTE* addr = static_cast<BYTE*>(si.lpMinimumApplicationAddress);

    MEMORY_BASIC_INFORMATION mbi;
    while (addr < static_cast<BYTE*>(si.lpMaximumApplicationAddress)) {
        if (VirtualQuery(addr, &mbi, sizeof(mbi)) == 0)
            break;

        if (mbi.State == MEM_COMMIT &&
            !(mbi.Protect & (PAGE_GUARD | PAGE_NOACCESS)))
        {
            const BYTE* base = static_cast<const BYTE*>(mbi.BaseAddress);
            const SIZE_T regionLen = mbi.RegionSize;

            for (size_t s = 0; s < nSigs; ++s) {
                if (regionLen < sigs[s].len) continue;
                const SIZE_T maxOff = regionLen - sigs[s].len;

                for (SIZE_T i = 0; i <= maxOff; ++i) {
                    if (memcmp(base + i, sigs[s].pat, sigs[s].len) == 0) {
                        ++sigs[s].count;
                        if (verbose) {
                            const BYTE* regionEnd = base + regionLen;
                            const char* p = reinterpret_cast<const char*>(base + i);
                            char buf[260] = { 0 };
                            size_t k = 0;
                            while (p < reinterpret_cast<const char*>(regionEnd) && *p && k < sizeof(buf) - 1) {
                                buf[k++] = std::isprint(static_cast<unsigned char>(*p)) ? *p : '.';
                                ++p;
                            }
                            printf("  \"%s\"\n", buf);
                        }
                    }
                }
            }
        }
        addr += mbi.RegionSize;
    }
}

static void PrintResumo(const SigInfo* sigs, size_t nSigs)
{
    printf("Ocorr\xC3\xAAncias:\n\n");
    printf("Resumo de ocorr\xC3\xAAncias:\n");
    printf("PIN_     : %zu\n", sigs[0].count);
    printf("pin.exe  : %zu\n", sigs[1].count);
    printf("pinvm.dll : %zu\n", sigs[2].count);
    printf("pinipc.dll : %zu\n", sigs[3].count);

    for (size_t i = 0; i < nSigs; ++i) {
        if (sigs[i].count > sigs[i].alertThreshold) {
            printf("Alerta: mais de %zu ocorr\xC3\xAAncias de \"%s\" encontradas!\n",
                sigs[i].alertThreshold, sigs[i].pat);
        }
    }
    fflush(stdout);
}

int wmain()
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);

    TomwarePrintLoopHeader("TestMemoryScan");
    const ULONGLONG t0 = TomwareNowMs();

    const size_t nSigs = 4;
    SigInfo firstPass[] = {
        { "PIN_",      4,  0, 4 },
        { "pin.exe",   7,  0, 2 },
        { "pinvm.dll", 9,  0, 2 },
        { "pinipc.dll", 10, 0, 2 }
    };

    // 1a iteracao: evidencia completa (padrao do artigo) — imprime Resumo cedo
    // para nao perder contagens se o restante do loop sofrer timeout sob Pin.
    const bool verboseFirst = (TOMWARE_LOOP_COUNT == 1);
    ScanMemoryForPinStrings(firstPass, nSigs, verboseFirst);
    PrintResumo(firstPass, nSigs);

    // Iteracoes restantes: varreduras reais, sem reimprimir o Resumo.
    // Isso preserva o experimento Loop_X_1000; o Resumo antecipado serve apenas
    // para nao perder a evidencia caso a execucao seja interrompida por timeout.
    for (int iter = 1; iter < TOMWARE_LOOP_COUNT; ++iter) {
        SigInfo pass[] = {
            { "PIN_",      4,  0, 4 },
            { "pin.exe",   7,  0, 2 },
            { "pinvm.dll", 9,  0, 2 },
            { "pinipc.dll", 10, 0, 2 }
        };
        ScanMemoryForPinStrings(pass, nSigs, false);
    }

    TomwarePrintLoopFooter(t0);
    return 0;
}
