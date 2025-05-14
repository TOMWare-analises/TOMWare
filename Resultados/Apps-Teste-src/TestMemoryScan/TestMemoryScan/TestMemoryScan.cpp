#include <windows.h>
#include <iostream>
#include <string>
#include "Measurement.h"

struct SigInfo {
    const char* pat;
    size_t len;
    size_t count;      // contador
};


void PrintAsciiString(const char* p, const MEMORY_BASIC_INFORMATION& mbi)
{
    const BYTE* regionEnd = static_cast<const BYTE*>(mbi.BaseAddress) + mbi.RegionSize;
    char buf[260] = { 0 };         // corta em 259 chars
    size_t i = 0;

    while (p < reinterpret_cast<const char*>(regionEnd) && *p && i < sizeof(buf) - 1)
    {
        buf[i++] = std::isprint(static_cast<unsigned char>(*p)) ? *p : '.';
        ++p;
    }
    printf("  \"%s\"\n", buf);
}

void ScanMemoryForPinStrings()
{
    SYSTEM_INFO si;  GetSystemInfo(&si);
    BYTE* addr = static_cast<BYTE*>(si.lpMinimumApplicationAddress);

    SigInfo sigs[] = {
        { "PIN_",   4, 0 }, // inclui nomes de funções (ex. PIN_StartProgram) e nomes de variáveis (ex. PIN_CRT_TZDATA), evita falsos positivos como "COPING"
        { "pin.exe", 7, 0 },
        { "pinvm.dll", 9, 0 },
        { "pinipc.dll", 10, 0 }
    };

    printf("\nOcorrências:\n");

    MEMORY_BASIC_INFORMATION mbi;
    while (addr < static_cast<BYTE*>(si.lpMaximumApplicationAddress)) {
        if (VirtualQuery(addr, &mbi, sizeof(mbi)) == 0) // estrategia pode ser interceptar dados que contenham os nomes presente numa lista e embaralhar na resposta a função Virtualquery
            break;

        if (mbi.State == MEM_COMMIT &&
            !(mbi.Protect & (PAGE_GUARD | PAGE_NOACCESS)))
        {
            const BYTE* base = static_cast<const BYTE*>(mbi.BaseAddress);
            const SIZE_T regionLen = mbi.RegionSize;

            for (SigInfo& s : sigs) {
                if (regionLen < s.len) continue;
                const SIZE_T maxOff = regionLen - s.len;

                for (SIZE_T i = 0; i <= maxOff; ++i) {
                    if (memcmp(base + i, s.pat, s.len) == 0) {
                        ++s.count;
                        //printf("Possível resíduo \"%s\" em %p\n", s.pat, base + i);
                        PrintAsciiString(reinterpret_cast<const char*>(base + i), mbi);
                    }
                }
            }
        }
        addr += mbi.RegionSize;
    }

    // --------------------- relatório final ---------------------
    printf("\nResumo de ocorrências:\n");
    printf("  PIN_    : %zu\n", sigs[0].count);
    printf("  pin.exe : %zu\n", sigs[1].count);
    printf("  pinvm.dll : %zu\n", sigs[2].count);
    printf("  pinipc.dll : %zu\n", sigs[3].count);

    if (sigs[0].count > 4)
        printf("Alerta: mais de 4 ocorrências de \"PIN_\" encontradas!\n");
    if (sigs[1].count > 3)
        printf("Alerta: mais de 2 ocorrências de \"pin.exe\" encontradas!\n");
    if (sigs[2].count > 3)
        printf("Alerta: mais de 2 ocorrências de \"pinvm.dll\" encontradas!\n");
    if (sigs[3].count > 3)
        printf("Alerta: mais de 2 ocorrências de \"pinipc.dll\" encontradas!\n");
}

int wmain()
{
    SetConsoleOutputCP(CP_UTF8);

    testGetTickCountConsistency(1000, &ScanMemoryForPinStrings, L"tick_test_log-MemoryScan.txt");

    system("pause");
    return 0;
}
