/**********************************************************************
 *  InstMemcmpMask.cpp – contramedida para varreduras de assinaturas  *
 *  (versão optimizada: verifica a assinatura antes de chamar memcmp) *
 *********************************************************************/
#include "InstMemcmpMask.h"
#include <cctype>     // std::tolower
#include <cstring>    // std::memcmp / wmemcmp

 /*--------------------------------------------------------------------
  *  Redefinição local de _memicmp (algumas CRTs não exportam)         */
#ifndef _MEMICMP_DEFINED
#define _MEMICMP_DEFINED
static int __cdecl _memicmp(const void* a, const void* b, size_t n)
{
    const unsigned char* p1 = static_cast<const unsigned char*>(a);
    const unsigned char* p2 = static_cast<const unsigned char*>(b);
    for (size_t i = 0; i < n; ++i)
    {
        int c1 = std::tolower(p1[i]);
        int c2 = std::tolower(p2[i]);
        if (c1 != c2) return c1 - c2;
    }
    return 0;
}
#endif

/*--------------------------------------------------------------------
 *  Assinaturas sensíveis                                             */
constexpr const char  P0[] = "PIN_";
constexpr const char  P1[] = "pin.exe";
constexpr const char  P2[] = "pinvm.dll";
constexpr const char  P3[] = "pinipc.dll";

constexpr const wchar_t W0[] = L"PIN_";
constexpr const wchar_t W1[] = L"pin.exe";
constexpr const wchar_t W2[] = L"pinvm.dll";
constexpr const wchar_t W3[] = L"pinipc.dll";

/*--------------------------------------------------------------------
 *  Wrappers optimizados                                              */
#define WRAP(name) static auto name

 /*--- memcmp ANSI ---------------------------------------------------*/
WRAP(wMemcmpA)(const void* a, const void* b, size_t n, AFUNPTR orig)->int
{
    /* shortcut para tamanhos de interesse */
    switch (n)
    {
    case 4:  if (memcmp(b, P0, 4) == 0) return 1;  break;
    case 7:  if (memcmp(b, P1, 7) == 0) return 1;  break;
    case 9:  if (memcmp(b, P2, 9) == 0) return 1;  break;
    case 10: if (memcmp(b, P3, 10) == 0) return 1;  break;
    }
    using fn = int(__cdecl*)(const void*, const void*, size_t);
    return reinterpret_cast<fn>(orig)(a, b, n);         /* caminho normal */
}

/*--- memicmp ANSI (case‑insensitive) -------------------------------*/
WRAP(wMemcmpI)(const void* a, const void* b, size_t n, AFUNPTR orig)->int
{
    auto ci = (int(__cdecl*)(const void*, const void*, size_t))_memicmp;
    switch (n)
    {
    case 4:  if (ci(b, P0, 4) == 0) return 1;  break;
    case 7:  if (ci(b, P1, 7) == 0) return 1;  break;
    case 9:  if (ci(b, P2, 9) == 0) return 1;  break;
    case 10: if (ci(b, P3, 10) == 0) return 1;  break;
    }
    using fn = int(__cdecl*)(const void*, const void*, size_t);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

/*--- memcmp_s (CRT segura) -----------------------------------------*/
WRAP(wMemcmpS)(const void* a, size_t as, const void* b, size_t bs,
    int* out, AFUNPTR orig)->errno_t
{
    if ((bs == 4 && memcmp(b, P0, 4) == 0)
        || (bs == 7 && memcmp(b, P1, 7) == 0)
        || (bs == 9 && memcmp(b, P2, 9) == 0)
        || (bs == 10 && memcmp(b, P3, 10) == 0))
    {
        if (out) *out = 1;           /* força “diferente” */
        return 0;
    }
    using fn = errno_t(__cdecl*)(const void*, size_t,
        const void*, size_t, int*);
    return reinterpret_cast<fn>(orig)(a, as, b, bs, out);
}

/*--- wmemcmp UTF‑16 -------------------------------------------------*/
WRAP(wWmemcmp)(const wchar_t* a, const wchar_t* b, size_t n, AFUNPTR orig)->int
{
    switch (n)
    {
    case 4:  if (wmemcmp(b, W0, 4) == 0) return 1;  break;
    case 7:  if (wmemcmp(b, W1, 7) == 0) return 1;  break;
    case 9:  if (wmemcmp(b, W2, 9) == 0) return 1;  break;
    case 10: if (wmemcmp(b, W3, 10) == 0) return 1;  break;
    }
    using fn = int(__cdecl*)(const wchar_t*, const wchar_t*, size_t);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

/*--- wmemcmp_s UTF‑16 segura ---------------------------------------*/
WRAP(wWmemcmpS)(const wchar_t* a, size_t as, const wchar_t* b, size_t bs,
    int* out, AFUNPTR orig)->errno_t
{
    if ((bs == 4 && wmemcmp(b, W0, 4) == 0)
        || (bs == 7 && wmemcmp(b, W1, 7) == 0)
        || (bs == 9 && wmemcmp(b, W2, 9) == 0)
        || (bs == 10 && wmemcmp(b, W3, 10) == 0))
    {
        if (out) *out = 1;
        return 0;
    }
    using fn = errno_t(__cdecl*)(const wchar_t*, size_t,
        const wchar_t*, size_t, int*);
    return reinterpret_cast<fn>(orig)(a, as, b, bs, out);
}

/*--- RtlCompareMemory / RtlEqualMemory ------------------------------*/
WRAP(wRtlCmpMem)(const void* a, const void* b, SIZE_T n, AFUNPTR orig)->SIZE_T
{
    if ((n == 4 && memcmp(b, P0, 4) == 0)
        || (n == 7 && memcmp(b, P1, 7) == 0)
        || (n == 9 && memcmp(b, P2, 9) == 0)
        || (n == 10 && memcmp(b, P3, 10) == 0))
        return 0;                                   /* “diferente” */
    using fn = SIZE_T(NTAPI*)(const void*, const void*, SIZE_T);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

WRAP(wRtlEqMem)(const void* a, const void* b, SIZE_T n, AFUNPTR orig)->WindowsAPI::BOOLEAN
{
    if ((n == 4 && memcmp(b, P0, 4) == 0)
        || (n == 7 && memcmp(b, P1, 7) == 0)
        || (n == 9 && memcmp(b, P2, 9) == 0)
        || (n == 10 && memcmp(b, P3, 10) == 0))
        return FALSE;
    using fn = WindowsAPI::BOOLEAN(NTAPI*)(const void*, const void*, SIZE_T);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

/*--------------------------------------------------------------------
 *  Tabela de ganchos                                                 */
struct Hook { const char* name; AFUNPTR wrap; int argc; };
static const Hook gTable[] = {
    { "memcmp",            (AFUNPTR)wMemcmpA,   3 },
    { "_memcmp",           (AFUNPTR)wMemcmpA,   3 },
    { "__acrt_memcmp",     (AFUNPTR)wMemcmpA,   3 },
    { "bcmp",              (AFUNPTR)wMemcmpA,   3 },
    { "memicmp",           (AFUNPTR)wMemcmpI,   3 },
    { "_memicmp",          (AFUNPTR)wMemcmpI,   3 },
    { "_memicmp_l",        (AFUNPTR)wMemcmpI,   3 },
    { "memcmp_s",          (AFUNPTR)wMemcmpS,   5 },
    { "wmemcmp",           (AFUNPTR)wWmemcmp,   3 },
    { "wmemcmp_s",         (AFUNPTR)wWmemcmpS,  5 },
    { "RtlCompareMemory",  (AFUNPTR)wRtlCmpMem, 3 },
    { "RtlEqualMemory",    (AFUNPTR)wRtlEqMem,  3 },
    { nullptr, nullptr, 0 }
};

/*--------------------------------------------------------------------
 *  InstrumentFunction                                                */
VOID InstMemcmpMask::InstrumentFunction(RTN rtn, VOID*)
{
    if (!RTN_Valid(rtn)) return;

    const std::string& name = RTN_Name(rtn);
    for (const Hook* h = gTable; h->name; ++h)
        if (name == h->name)
        {
            AFUNPTR orig = RTN_Funptr(rtn);
            if (h->argc == 3)
            {
                RTN_ReplaceSignature(rtn, h->wrap,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 0,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 1,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 2,
                    IARG_PTR, orig,
                    IARG_END);
            }
            else /* argc == 5 */
            {
                RTN_ReplaceSignature(rtn, h->wrap,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 0,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 1,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 2,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 3,
                    IARG_FUNCARG_ENTRYPOINT_VALUE, 4,
                    IARG_PTR, orig,
                    IARG_END);
            }
            return;            /* já “hookado” */
        }
}
