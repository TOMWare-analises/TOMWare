/* TestOverhead.cpp — padrao de saida alinhado ao artigo SBSeg 2025 */

#include <windows.h>
#include <iostream>
#include <vector>
#include "Measurement.h"
#include "..\..\TomwareLoop.h"

static uint64_t KernelClockNs()
{
    FILETIME ft;
    GetSystemTimePreciseAsFileTime(&ft);
    ULARGE_INTEGER u;
    u.LowPart = ft.dwLowDateTime;
    u.HighPart = ft.dwHighDateTime;
    return u.QuadPart * 100ULL;
}

static void TestOverheadOnce(double* elapsedOut, DWORD* thresholdOut, bool verbose)
{
    const DWORD SLEEP_MS = 50;
    const int SCALE_FACTOR = 40;
    const DWORD THRESHOLD = static_cast<DWORD>((SLEEP_MS * SCALE_FACTOR) * 1.5);

    if (verbose)
        std::cout << "Sleep invocado\n";

    uint64_t t0 = KernelClockNs();
    Sleep(SLEEP_MS);
    double delta = (KernelClockNs() - t0) / 1e6;
    double elapsed = delta * SCALE_FACTOR;

    *elapsedOut = elapsed;
    *thresholdOut = THRESHOLD;
}

int main()
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);

    TomwarePrintLoopHeader("TestOverhead");
    const ULONGLONG t0 = TomwareNowMs();

    double sumElapsed = 0.0;
    DWORD threshold = 0;
    double lastElapsed = 0.0;

    for (int iter = 0; iter < TOMWARE_LOOP_COUNT; ++iter) {
        const bool verbose = (TOMWARE_LOOP_COUNT == 1);
        double elapsed = 0.0;
        TestOverheadOnce(&elapsed, &threshold, verbose);
        sumElapsed += elapsed;
        lastElapsed = elapsed;
    }

    const double reportElapsed =
        (TOMWARE_LOOP_COUNT > 1) ? (sumElapsed / TOMWARE_LOOP_COUNT) : lastElapsed;

    if (TOMWARE_LOOP_COUNT > 1)
        std::cout << "Sleep invocado\n";

    std::cout << "Ticks + Latencia: " << reportElapsed << ", Limite: " << threshold << "\n";

    if (reportElapsed > threshold)
        std::cout << "*** Overhead anomalo / possivel DBI ***\n";
    else
        std::cout << "OK - nenhuma anomalia\n";

    std::cout << "-------------------------------\n";
    TomwarePrintLoopFooter(t0);
    return 0;
}
