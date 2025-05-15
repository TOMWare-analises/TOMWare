#include "SkewMask.h"

/*──────────────── Estado global ────────────────*/
static volatile WindowsAPI::LONG64 g_qpcSkewTicks = 0;   // excesso acumulado (ticks QPC)
static double g_qpcFreqHz = 0.0; // frequência do QPC
static INT cGTCCalls = 0;
static INT cGTC64Calls = 0;

static inline void AccumulateSkewTicks(WindowsAPI::LONG64 d)
{
    InterlockedExchangeAdd64(&g_qpcSkewTicks, d);
}

static inline WindowsAPI::LONG64 CurrentSkewTicks()
{
    return InterlockedCompareExchange64(&g_qpcSkewTicks, 0, 0);
}

static inline ULONGLONG Skew100ns()
{
    /* 100 ns  = 10 000 000 × (1 s)             */
    /* offset  = ticks * 1e7 / freq             */
    return (ULONGLONG)(CurrentSkewTicks() * 10'000'000.0 / g_qpcFreqHz);
}

/*────────────── Ponteiros originais ─────────────*/
static BOOL(WINAPI* pQPC)(WindowsAPI::LARGE_INTEGER*) = nullptr;
static VOID(WINAPI* pSleep)(DWORD) = nullptr;
static DWORD(WINAPI* pSleepEx)(DWORD, BOOL) = nullptr;
static DWORD(WINAPI* pGTC)(void) = nullptr;
static ULONGLONG(WINAPI* pGTC64)(void) = nullptr;

static VOID(WINAPI* pGSTPFT)(WindowsAPI::LPFILETIME) = nullptr;    // GetSystemTimePreciseAsFileTime
static ULONGLONG(WINAPI* pQITP)(void) = nullptr;    // QueryInterruptTimePrecise (Win10+)


/*──────────– núcleo de calibração ───────────────*/
static DWORD CalibratedSleep(DWORD ms, BOOL alertable)
{
    WindowsAPI::LARGE_INTEGER t0, t1;
    pQPC(&t0);

    DWORD rv = alertable ? pSleepEx(ms, alertable)
        : (pSleep(ms), 0);

    pQPC(&t1);

    WindowsAPI::LONG64 ticksExpected = (WindowsAPI::LONG64)(ms * (g_qpcFreqHz / 1000.0));
    WindowsAPI::LONG64 ticksReal = t1.QuadPart - t0.QuadPart;
    if (ticksReal > ticksExpected)
        AccumulateSkewTicks(ticksReal - ticksExpected);

    return rv;
}

/*──────────── wrappers de suspensão ─────────────*/
static VOID  WINAPI Hook_Sleep(DWORD ms) { 
    CalibratedSleep(ms, FALSE); 
    std::cout << "Sleep invocado" << std::endl;
}
static DWORD WINAPI Hook_SleepEx(DWORD ms, BOOL alert) { 
    return CalibratedSleep(ms, alert); 
    std::cout << "SleepEx invocado" << std::endl;
}

/*──────────── wrappers de leitura de tempo ───────*/
static BOOL WINAPI Hook_QPC(WindowsAPI::LARGE_INTEGER* out)
{
    BOOL ok = pQPC(out);
    out->QuadPart -= CurrentSkewTicks();
    return ok;
}
static DWORD WINAPI Hook_GTC()
{
    cGTCCalls++;
    double msOff = CurrentSkewTicks() * 1000.0 / g_qpcFreqHz;
    std::cout << "Overhead GTC[" << cGTCCalls << "]: " << (DWORD)msOff << std::endl;
    return pGTC() - (DWORD)msOff;
}
static ULONGLONG WINAPI Hook_GTC64()
{
    cGTC64Calls++;
    double msOff = CurrentSkewTicks() * 1000.0 / g_qpcFreqHz;
    return pGTC64() - (ULONGLONG)(msOff);
}

static VOID WINAPI Hook_GSTPFT(WindowsAPI::LPFILETIME ft)
{
    pGSTPFT(ft);                                     // chama original
    WindowsAPI::ULARGE_INTEGER t; t.LowPart = ft->dwLowDateTime;
    t.HighPart = ft->dwHighDateTime;
    t.QuadPart -= Skew100ns();                       // compensa
    ft->dwLowDateTime = t.LowPart;
    ft->dwHighDateTime = t.HighPart;
}

static ULONGLONG WINAPI Hook_QITP()
{
    return pQITP() - Skew100ns();
}


/*──────────── helper de patch ───────────────────*/
static void PatchApi(IMG img, const char* name, AFUNPTR hook, AFUNPTR* save)
{
    RTN rtn = RTN_FindByName(img, name);
    if (!RTN_Valid(rtn)) return;
    *save = RTN_Replace(rtn, hook);
}

/*──────────── callback principal ────────────────*/
VOID SkewMask_ImageLoad(IMG img, VOID*)
{
    if (!g_qpcFreqHz) {
        WindowsAPI::LARGE_INTEGER fq; QueryPerformanceFrequency(&fq);
        g_qpcFreqHz = (double)fq.QuadPart;
    }

    PatchApi(img, "Sleep", AFUNPTR(Hook_Sleep), (AFUNPTR*)&pSleep);
    PatchApi(img, "SleepEx", AFUNPTR(Hook_SleepEx), (AFUNPTR*)&pSleepEx);
    PatchApi(img, "QueryPerformanceCounter", AFUNPTR(Hook_QPC), (AFUNPTR*)&pQPC);
    PatchApi(img, "GetTickCount", AFUNPTR(Hook_GTC), (AFUNPTR*)&pGTC);
    PatchApi(img, "GetTickCount64", AFUNPTR(Hook_GTC64), (AFUNPTR*)&pGTC64);
    PatchApi(img, "GetSystemTimePreciseAsFileTime", AFUNPTR(Hook_GSTPFT), (AFUNPTR*)&pGSTPFT);
    PatchApi(img, "QueryInterruptTimePrecise", AFUNPTR(Hook_QITP), (AFUNPTR*)&pQITP);
}

VOID SkewMask_Init() {
    IMG_AddInstrumentFunction(SkewMask_ImageLoad, 0);
}