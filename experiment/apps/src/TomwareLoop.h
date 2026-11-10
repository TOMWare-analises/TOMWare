#pragma once
// Controle de repeticoes para evidencia de tempo (Loop_X_1000).
#ifndef TOMWARE_LOOP_COUNT
#define TOMWARE_LOOP_COUNT 1
#endif

#include <windows.h>
#include <cstdio>

static inline ULONGLONG TomwareNowMs()
{
    return GetTickCount64();
}

static inline void TomwarePrintLoopHeader(const char* name)
{
    if (TOMWARE_LOOP_COUNT > 1) {
        printf("Loop_X_%d | %s\n", TOMWARE_LOOP_COUNT, name);
        printf("-------------------------------\n");
    }
}

static inline void TomwarePrintLoopFooter(ULONGLONG t0Ms)
{
    if (TOMWARE_LOOP_COUNT > 1) {
        const ULONGLONG elapsed = TomwareNowMs() - t0Ms;
        printf("Iteracoes : %d\n", TOMWARE_LOOP_COUNT);
        printf("Tempo total (ms): %llu\n", static_cast<unsigned long long>(elapsed));
        printf("-------------------------------\n");
    }
}
