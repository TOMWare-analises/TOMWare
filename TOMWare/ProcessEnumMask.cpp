#include "ProcessEnumMask.h"
#include "TomwareLog.h"
#include "utils.h"

#include <algorithm>
#include <cctype>
#include <cwctype>
#include <string>

static BOOL(WINAPI* pProcess32First)(WindowsAPI::HANDLE, WindowsAPI::LPPROCESSENTRY32) = nullptr;
static BOOL(WINAPI* pProcess32Next)(WindowsAPI::HANDLE, WindowsAPI::LPPROCESSENTRY32) = nullptr;
static BOOL(WINAPI* pProcess32FirstW)(WindowsAPI::HANDLE, WindowsAPI::LPPROCESSENTRY32W) = nullptr;
static BOOL(WINAPI* pProcess32NextW)(WindowsAPI::HANDLE, WindowsAPI::LPPROCESSENTRY32W) = nullptr;
static BOOL(WINAPI* pModule32First)(WindowsAPI::HANDLE, WindowsAPI::LPMODULEENTRY32) = nullptr;
static BOOL(WINAPI* pModule32Next)(WindowsAPI::HANDLE, WindowsAPI::LPMODULEENTRY32) = nullptr;
static BOOL(WINAPI* pModule32FirstW)(WindowsAPI::HANDLE, WindowsAPI::LPMODULEENTRY32W) = nullptr;
static BOOL(WINAPI* pModule32NextW)(WindowsAPI::HANDLE, WindowsAPI::LPMODULEENTRY32W) = nullptr;
static WindowsAPI::HMODULE(WINAPI* pGetModuleHandleA)(WindowsAPI::LPCSTR) = nullptr;
static WindowsAPI::HMODULE(WINAPI* pGetModuleHandleW)(WindowsAPI::LPCWSTR) = nullptr;

static std::string ToLowerCopyA(const char* value)
{
    if (!value)
        return std::string();
    std::string out(value);
    std::transform(out.begin(), out.end(), out.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return out;
}

static std::wstring ToLowerCopyW(const wchar_t* value)
{
    if (!value)
        return std::wstring();
    std::wstring out(value);
    std::transform(out.begin(), out.end(), out.begin(),
        [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
    return out;
}

static std::string BaseNameA(const char* path)
{
    if (!path || !*path)
        return std::string();
    const char* slash = strrchr(path, '\\');
    if (!slash)
        slash = strrchr(path, '/');
    return slash ? std::string(slash + 1) : std::string(path);
}

static std::wstring BaseNameW(const wchar_t* path)
{
    if (!path || !*path)
        return std::wstring();
    const wchar_t* slash = wcsrchr(path, L'\\');
    if (!slash)
        slash = wcsrchr(path, L'/');
    return slash ? std::wstring(slash + 1) : std::wstring(path);
}

static bool IsHiddenProcessNameA(const char* exeFile)
{
    return ToLowerCopyA(BaseNameA(exeFile).c_str()) == "pin.exe";
}

static bool IsHiddenProcessNameW(const wchar_t* exeFile)
{
    return ToLowerCopyW(BaseNameW(exeFile).c_str()) == L"pin.exe";
}

static bool IsHiddenModuleNameA(const char* moduleName)
{
    const std::string base = ToLowerCopyA(BaseNameA(moduleName).c_str());
    return base == "pinvm.dll"
        || base == "pinipc.dll"
        || base == "tomware.dll";
}

static bool IsHiddenModuleNameW(const wchar_t* moduleName)
{
    const std::wstring base = ToLowerCopyW(BaseNameW(moduleName).c_str());
    return base == L"pinvm.dll"
        || base == L"pinipc.dll"
        || base == L"tomware.dll";
}

static BOOL WINAPI Hook_Process32First(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPPROCESSENTRY32 entry)
{
    while (pProcess32First(snapshot, entry))
    {
#ifdef UNICODE
        if (!IsHiddenProcessNameW(entry->szExeFile))
#else
        if (!IsHiddenProcessNameA(entry->szExeFile))
#endif
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Process32Next(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPPROCESSENTRY32 entry)
{
    while (pProcess32Next(snapshot, entry))
    {
#ifdef UNICODE
        if (!IsHiddenProcessNameW(entry->szExeFile))
#else
        if (!IsHiddenProcessNameA(entry->szExeFile))
#endif
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Process32FirstW(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPPROCESSENTRY32W entry)
{
    while (pProcess32FirstW(snapshot, entry))
    {
        if (!IsHiddenProcessNameW(entry->szExeFile))
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Process32NextW(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPPROCESSENTRY32W entry)
{
    while (pProcess32NextW(snapshot, entry))
    {
        if (!IsHiddenProcessNameW(entry->szExeFile))
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Module32First(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPMODULEENTRY32 entry)
{
    while (pModule32First(snapshot, entry))
    {
#ifdef UNICODE
        if (!IsHiddenModuleNameW(entry->szModule))
#else
        if (!IsHiddenModuleNameA(entry->szModule))
#endif
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Module32Next(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPMODULEENTRY32 entry)
{
    while (pModule32Next(snapshot, entry))
    {
#ifdef UNICODE
        if (!IsHiddenModuleNameW(entry->szModule))
#else
        if (!IsHiddenModuleNameA(entry->szModule))
#endif
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Module32FirstW(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPMODULEENTRY32W entry)
{
    while (pModule32FirstW(snapshot, entry))
    {
        if (!IsHiddenModuleNameW(entry->szModule))
            return TRUE;
    }
    return FALSE;
}

static BOOL WINAPI Hook_Module32NextW(
    WindowsAPI::HANDLE snapshot,
    WindowsAPI::LPMODULEENTRY32W entry)
{
    while (pModule32NextW(snapshot, entry))
    {
        if (!IsHiddenModuleNameW(entry->szModule))
            return TRUE;
    }
    return FALSE;
}

static WindowsAPI::HMODULE WINAPI Hook_GetModuleHandleA(WindowsAPI::LPCSTR moduleName)
{
    if (moduleName && IsHiddenModuleNameA(moduleName))
    {
        TomwareLogInfo("[ProcessEnumMask] GetModuleHandleA ocultou: " + std::string(moduleName));
        return nullptr;
    }
    return pGetModuleHandleA(moduleName);
}

static WindowsAPI::HMODULE WINAPI Hook_GetModuleHandleW(WindowsAPI::LPCWSTR moduleName)
{
    if (moduleName && IsHiddenModuleNameW(moduleName))
    {
        TomwareLogInfoW(L"[ProcessEnumMask] GetModuleHandleW ocultou: " + std::wstring(moduleName));
        return nullptr;
    }
    return pGetModuleHandleW(moduleName);
}

static void PatchApi(IMG img, const char* name, AFUNPTR hook, AFUNPTR* save)
{
    RTN rtn = RTN_FindByName(img, name);
    if (!RTN_Valid(rtn))
        return;
    *save = RTN_Replace(rtn, hook);
}

static VOID ProcessEnumMask_ImageLoad(IMG img, VOID*)
{
    const std::string& imgName = IMG_Name(img);
    if (imgName.find("kernel32") == std::string::npos
        && imgName.find("KERNEL32") == std::string::npos
        && imgName.find("Kernel32") == std::string::npos)
        return;

    PatchApi(img, "Process32First", AFUNPTR(Hook_Process32First),
        reinterpret_cast<AFUNPTR*>(&pProcess32First));
    PatchApi(img, "Process32Next", AFUNPTR(Hook_Process32Next),
        reinterpret_cast<AFUNPTR*>(&pProcess32Next));
    PatchApi(img, "Process32FirstW", AFUNPTR(Hook_Process32FirstW),
        reinterpret_cast<AFUNPTR*>(&pProcess32FirstW));
    PatchApi(img, "Process32NextW", AFUNPTR(Hook_Process32NextW),
        reinterpret_cast<AFUNPTR*>(&pProcess32NextW));
    PatchApi(img, "Module32First", AFUNPTR(Hook_Module32First),
        reinterpret_cast<AFUNPTR*>(&pModule32First));
    PatchApi(img, "Module32Next", AFUNPTR(Hook_Module32Next),
        reinterpret_cast<AFUNPTR*>(&pModule32Next));
    PatchApi(img, "Module32FirstW", AFUNPTR(Hook_Module32FirstW),
        reinterpret_cast<AFUNPTR*>(&pModule32FirstW));
    PatchApi(img, "Module32NextW", AFUNPTR(Hook_Module32NextW),
        reinterpret_cast<AFUNPTR*>(&pModule32NextW));
    PatchApi(img, "GetModuleHandleA", AFUNPTR(Hook_GetModuleHandleA),
        reinterpret_cast<AFUNPTR*>(&pGetModuleHandleA));
    PatchApi(img, "GetModuleHandleW", AFUNPTR(Hook_GetModuleHandleW),
        reinterpret_cast<AFUNPTR*>(&pGetModuleHandleW));
}

VOID ProcessEnumMask_Init()
{
    IMG_AddInstrumentFunction(ProcessEnumMask_ImageLoad, 0);
}
