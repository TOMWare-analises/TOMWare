/* detect_combo_avg.cpp  ·  Win8+  ·  compile: cl /O2 detect_combo_avg.cpp */

#include <windows.h>
#include <iostream>
#include <vector>
#include "Measurement.h"

static uint64_t KernelClockNs()                          /* 100‑ns → ns */
{
    FILETIME ft;  GetSystemTimePreciseAsFileTime(&ft);
    ULARGE_INTEGER u; u.LowPart = ft.dwLowDateTime; u.HighPart = ft.dwHighDateTime;
    return u.QuadPart * 100ULL;
}

VOID TestOverhead() {

    // Para 2s (2000ms)
    const DWORD SLEEP_MS = 50;  /* duração de cada Sleep              */
    const int SCALE_FACTOR = 40; // aumenta a escala e tambem o diferencial (margem do overhead)
    const DWORD  THRESHOLD = (SLEEP_MS * SCALE_FACTOR) * 1.5; // -> alerta

    uint64_t t0 = KernelClockNs();
    Sleep(SLEEP_MS);
    double delta = (KernelClockNs() - t0) / 1e6;

    double elapsed = delta * SCALE_FACTOR;   // ~ 2000ms - 3000 ticks

    std::cout << "Ticks + Latencia: " << elapsed << ", Limite: " << THRESHOLD << "\n";

    if (elapsed > THRESHOLD)
        std::cout << "*** Overhead anómalo / possível DBI ***\n";
    else
        std::cout << "OK – nenhuma anomalia\n";

    std::cout << "--------------------------------------\n";

}

int main()
{
    SetConsoleOutputCP(CP_UTF8);

    TestOverhead();

    return 0;
}
