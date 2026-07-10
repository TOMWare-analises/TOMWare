#include "SkewMask.h"
#include "TomwareLog.h"

#include <string>

/*──────────────── Estado global ────────────────*/
static volatile WindowsAPI::LONG g_qpcSkewTicks = 0;   // excesso acumulado (ticks QPC)
static double g_qpcFreqHz = 0.0; // frequência do QPC
static INT cGTCCalls = 0;
static INT cGTC64Calls = 0;

static inline void AccumulateSkewTicks(WindowsAPI::LONG d)
{
#if defined (WIN32)
    InterlockedExchangeAdd(&g_qpcSkewTicks, d);
#else
    InterlockedExchangeAdd64(&g_qpcSkewTicks, d);
#endif
}

static inline WindowsAPI::LONG CurrentSkewTicks()
{
#if defined (WIN32)
    return InterlockedCompareExchange(&g_qpcSkewTicks, 0, 0);
#else
    return InterlockedCompareExchange64(&g_qpcSkewTicks, 0, 0);
#endif

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

using NtDelayExecutionFn = NTSTATUS(NTAPI*)(WindowsAPI::BOOLEAN, WindowsAPI::PLARGE_INTEGER);
static NtDelayExecutionFn pNtDelayExecution = nullptr;

using RtlQueryPerformanceCounterFn = ULONG(NTAPI*)(WindowsAPI::PLARGE_INTEGER, WindowsAPI::PLARGE_INTEGER);
static RtlQueryPerformanceCounterFn pRtlQueryPerformanceCounter = nullptr;


static inline void EnsureQpcFrequency()
{
    if (g_qpcFreqHz <= 0.0)
    {
        WindowsAPI::LARGE_INTEGER fq;
        WindowsAPI::QueryPerformanceFrequency(&fq);
        g_qpcFreqHz = static_cast<double>(fq.QuadPart);
    }
}

static inline void MeasureAndAccumulateSkew(const WindowsAPI::LARGE_INTEGER& t0,
    const WindowsAPI::LARGE_INTEGER& t1,
    double expectedMs)
{
    if (g_qpcFreqHz <= 0.0)
        return;

    const WindowsAPI::LONG64 ticksExpected =
        static_cast<WindowsAPI::LONG64>(expectedMs * (g_qpcFreqHz / 1000.0));
    const WindowsAPI::LONG64 ticksReal = t1.QuadPart - t0.QuadPart;
    if (ticksReal > ticksExpected)
        AccumulateSkewTicks(static_cast<WindowsAPI::LONG>(ticksReal - ticksExpected));
}

/*──────────– núcleo de calibração ───────────────*/
static DWORD CalibratedSleep(DWORD ms, BOOL alertable)
{
    EnsureQpcFrequency();

    WindowsAPI::LARGE_INTEGER t0, t1;
    if (pQPC)
        pQPC(&t0);

    DWORD rv = alertable ? pSleepEx(ms, alertable)
        : (pSleep(ms), 0);

    if (pQPC)
    {
        pQPC(&t1);
        MeasureAndAccumulateSkew(t0, t1, static_cast<double>(ms));
    }

    return rv;
}

/*──────────── wrappers de suspensão ─────────────*/
static VOID  WINAPI Hook_Sleep(DWORD ms) {
    CalibratedSleep(ms, FALSE);
}
static DWORD WINAPI Hook_SleepEx(DWORD ms, BOOL alert) {
    return CalibratedSleep(ms, alert);
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
    TomwareLogInfo("Overhead GTC[" + std::to_string(cGTCCalls) + "]: " + std::to_string((DWORD)msOff));
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

static ULONG NTAPI Hook_RtlQueryPerformanceCounter(
    WindowsAPI::PLARGE_INTEGER performanceCounter,
    WindowsAPI::PLARGE_INTEGER performanceFrequency)
{
    ULONG result = pRtlQueryPerformanceCounter(performanceCounter, performanceFrequency);
    if (performanceCounter)
        performanceCounter->QuadPart -= CurrentSkewTicks();
    return result;
}

static NTSTATUS NTAPI Hook_NtDelayExecution(
    WindowsAPI::BOOLEAN alertable,
    WindowsAPI::PLARGE_INTEGER delayInterval)
{
    EnsureQpcFrequency();

    double expectedMs = 0.0;
    if (delayInterval && delayInterval->QuadPart < 0)
        expectedMs = static_cast<double>(-delayInterval->QuadPart) / 10000.0;

    WindowsAPI::LARGE_INTEGER t0 = {}, t1 = {};
    const BOOL measure = (expectedMs > 0.0 && pQPC != nullptr);
    if (measure)
        pQPC(&t0);

    const NTSTATUS status = pNtDelayExecution(alertable, delayInterval);

    if (measure)
    {
        pQPC(&t1);
        MeasureAndAccumulateSkew(t0, t1, expectedMs);
    }

    return status;
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
    EnsureQpcFrequency();

    PatchApi(img, "Sleep", AFUNPTR(Hook_Sleep), (AFUNPTR*)&pSleep);
    PatchApi(img, "SleepEx", AFUNPTR(Hook_SleepEx), (AFUNPTR*)&pSleepEx);
    PatchApi(img, "QueryPerformanceCounter", AFUNPTR(Hook_QPC), (AFUNPTR*)&pQPC);
    PatchApi(img, "GetTickCount", AFUNPTR(Hook_GTC), (AFUNPTR*)&pGTC);
    PatchApi(img, "GetTickCount64", AFUNPTR(Hook_GTC64), (AFUNPTR*)&pGTC64);
    PatchApi(img, "GetSystemTimePreciseAsFileTime", AFUNPTR(Hook_GSTPFT), (AFUNPTR*)&pGSTPFT);
    PatchApi(img, "QueryInterruptTimePrecise", AFUNPTR(Hook_QITP), (AFUNPTR*)&pQITP);

    const std::string& imgName = IMG_Name(img);
    if (imgName.find("ntdll") != std::string::npos
        || imgName.find("NTDLL") != std::string::npos
        || imgName.find("Ntdll") != std::string::npos)
    {
        PatchApi(img, "RtlQueryPerformanceCounter", AFUNPTR(Hook_RtlQueryPerformanceCounter),
            (AFUNPTR*)&pRtlQueryPerformanceCounter);
        PatchApi(img, "NtDelayExecution", AFUNPTR(Hook_NtDelayExecution),
            (AFUNPTR*)&pNtDelayExecution);
    }
}

VOID SkewMask_Init() {
    IMG_AddInstrumentFunction(SkewMask_ImageLoad, 0);
}