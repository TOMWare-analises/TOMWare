// TestProcessEnum.cpp — PoC de deteccao de Pin via enumeracao (cl /EHsc /W4 TestProcessEnum.cpp)
#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>
#include <cstdio>

static std::wstring BaseNameW(const wchar_t* path)
{
    if (!path || !*path)
        return {};
    const wchar_t* slash = wcsrchr(path, L'\\');
    if (!slash)
        slash = wcsrchr(path, L'/');
    return slash ? std::wstring(slash + 1) : std::wstring(path);
}

static bool EqualsNoCaseW(const std::wstring& a, const std::wstring& b)
{
    if (a.size() != b.size())
        return false;
    for (size_t i = 0; i < a.size(); ++i)
        if (towlower(a[i]) != towlower(b[i]))
            return false;
    return true;
}

static void ScanProcesses()
{
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE)
    {
        std::cerr << "CreateToolhelp32Snapshot falhou\n";
        return;
    }

    PROCESSENTRY32W pe = { sizeof(pe) };
    bool foundPin = false;

    if (Process32FirstW(snap, &pe))
    {
        do
        {
            std::wstring name = BaseNameW(pe.szExeFile);
            if (EqualsNoCaseW(name, L"pin.exe"))
            {
                foundPin = true;
                printf("Processo Pin detectado: pid=%lu\n", pe.th32ProcessID);
            }
        } while (Process32NextW(snap, &pe));
    }

    CloseHandle(snap);

    if (!foundPin)
        std::cout << "Nenhum pin.exe na enumeracao de processos." << std::endl;
}

static void ScanModules()
{
    const char* targets[] = { "pinvm.dll", "pinipc.dll", "TOMWare.dll" };
    for (const char* target : targets)
    {
        HMODULE mod = GetModuleHandleA(target);
        std::cout << "GetModuleHandleA(" << target << ") = " << mod << std::endl;
        if (mod)
            std::cout << "*** Modulo Pin detectado: " << target << " ***" << std::endl;
    }
}

int main()
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);
    ScanProcesses();
    ScanModules();
    return 0;
}
