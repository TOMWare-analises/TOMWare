/********************************************************************************
 *  InstMemcmpMask.cpp – contramedida para varreduras de assinaturas na memória *
 ********************************************************************************/
#include "InstMemcmpMask.h"
#include "TomwareLog.h"

#include <cctype>
#include <cstring>
#include <fstream>
#include <sstream>
#include <vector>

struct MemcmpSignature
{
    std::string ansi;
    std::wstring wide;
    size_t len;
};

static std::vector<MemcmpSignature> g_signatures;

#ifndef _MEMICMP_DEFINED
#define _MEMICMP_DEFINED
static int __cdecl LocalMemicmp(const void* a, const void* b, size_t n)
{
    const unsigned char* p1 = static_cast<const unsigned char*>(a);
    const unsigned char* p2 = static_cast<const unsigned char*>(b);
    for (size_t i = 0; i < n; ++i)
    {
        int c1 = std::tolower(p1[i]);
        int c2 = std::tolower(p2[i]);
        if (c1 != c2)
            return c1 - c2;
    }
    return 0;
}
#endif

static std::wstring AnsiToWide(const std::string& text)
{
    if (text.empty())
        return std::wstring();

    const int required = WindowsAPI::MultiByteToWideChar(
        CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
    if (required <= 0)
        return std::wstring();

    std::vector<wchar_t> buffer(static_cast<size_t>(required) + 1, L'\0');
    WindowsAPI::MultiByteToWideChar(
        CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), &buffer[0], required);
    return std::wstring(&buffer[0]);
}

static void AddSignature(const std::string& pattern)
{
    if (pattern.empty())
        return;

    for (const auto& existing : g_signatures)
    {
        if (existing.ansi == pattern)
            return;
    }

    MemcmpSignature sig;
    sig.ansi = pattern;
    sig.wide = AnsiToWide(pattern);
    sig.len = pattern.size();
    g_signatures.push_back(sig);
}

static void LoadDefaultSignatures()
{
    g_signatures.clear();
    AddSignature("PIN_");
    AddSignature("pin.exe");
    AddSignature("pinvm.dll");
    AddSignature("pinipc.dll");
}

static bool ShouldMaskAnsiNeedle(const void* needle, size_t len, bool caseInsensitive)
{
    for (const auto& sig : g_signatures)
    {
        if (len != sig.len)
            continue;

        if (caseInsensitive)
        {
            if (LocalMemicmp(needle, sig.ansi.c_str(), len) == 0)
                return true;
        }
        else if (std::memcmp(needle, sig.ansi.c_str(), len) == 0)
        {
            return true;
        }
    }
    return false;
}

static bool ShouldMaskWideNeedle(const wchar_t* needle, size_t len)
{
    for (const auto& sig : g_signatures)
    {
        if (len != sig.len || sig.wide.empty())
            continue;
        if (std::wmemcmp(needle, sig.wide.c_str(), len) == 0)
            return true;
    }
    return false;
}

void InstMemcmpMask_LoadSignatures(const char* path)
{
    LoadDefaultSignatures();

    if (!path || !*path)
        return;

    std::ifstream input(path);
    if (!input.is_open())
    {
        TomwareLogInfo("[InstMemcmpMask] Arquivo de assinaturas nao encontrado: " + std::string(path));
        return;
    }

    size_t added = 0;
    std::string line;
    while (std::getline(input, line))
    {
        const size_t comment = line.find('#');
        if (comment != std::string::npos)
            line.erase(comment);

        line.erase(0, line.find_first_not_of(" \t\r\n"));
        const size_t last = line.find_last_not_of(" \t\r\n");
        if (last == std::string::npos)
            continue;
        line.erase(last + 1);

        const size_t before = g_signatures.size();
        AddSignature(line);
        if (g_signatures.size() > before)
            ++added;
    }

    TomwareLogInfo("[InstMemcmpMask] Assinaturas carregadas: "
        + std::to_string(g_signatures.size()) + " (+" + std::to_string(added) + " de " + std::string(path) + ")");
}

#define WRAP(name) static auto name

WRAP(wMemcmpA)(const void* a, const void* b, size_t n, AFUNPTR orig)->int
{
    if (ShouldMaskAnsiNeedle(b, n, false))
        return 1;
    using fn = int(__cdecl*)(const void*, const void*, size_t);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

WRAP(wMemcmpI)(const void* a, const void* b, size_t n, AFUNPTR orig)->int
{
    if (ShouldMaskAnsiNeedle(b, n, true))
        return 1;
    using fn = int(__cdecl*)(const void*, const void*, size_t);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

WRAP(wMemcmpS)(const void* a, size_t as, const void* b, size_t bs,
    int* out, AFUNPTR orig)->errno_t
{
    if (ShouldMaskAnsiNeedle(b, bs, false))
    {
        if (out)
            *out = 1;
        return 0;
    }
    using fn = errno_t(__cdecl*)(const void*, size_t, const void*, size_t, int*);
    return reinterpret_cast<fn>(orig)(a, as, b, bs, out);
}

WRAP(wWmemcmp)(const wchar_t* a, const wchar_t* b, size_t n, AFUNPTR orig)->int
{
    if (ShouldMaskWideNeedle(b, n))
        return 1;
    using fn = int(__cdecl*)(const wchar_t*, const wchar_t*, size_t);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

WRAP(wWmemcmpS)(const wchar_t* a, size_t as, const wchar_t* b, size_t bs,
    int* out, AFUNPTR orig)->errno_t
{
    if (ShouldMaskWideNeedle(b, bs))
    {
        if (out)
            *out = 1;
        return 0;
    }
    using fn = errno_t(__cdecl*)(const wchar_t*, size_t, const wchar_t*, size_t, int*);
    return reinterpret_cast<fn>(orig)(a, as, b, bs, out);
}

WRAP(wRtlCmpMem)(const void* a, const void* b, SIZE_T n, AFUNPTR orig)->SIZE_T
{
    if (ShouldMaskAnsiNeedle(b, static_cast<size_t>(n), false))
        return 0;
    using fn = SIZE_T(NTAPI*)(const void*, const void*, SIZE_T);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

WRAP(wRtlEqMem)(const void* a, const void* b, SIZE_T n, AFUNPTR orig)->WindowsAPI::BOOLEAN
{
    if (ShouldMaskAnsiNeedle(b, static_cast<size_t>(n), false))
        return FALSE;
    using fn = WindowsAPI::BOOLEAN(NTAPI*)(const void*, const void*, SIZE_T);
    return reinterpret_cast<fn>(orig)(a, b, n);
}

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

VOID InstMemcmpMask::InstrumentFunction(RTN rtn, VOID*)
{
    if (!RTN_Valid(rtn))
        return;

    const std::string& name = RTN_Name(rtn);
    for (const Hook* h = gTable; h->name; ++h)
    {
        if (name != h->name)
            continue;

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
        else
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
        return;
    }
}
