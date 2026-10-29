// TestRecoverWork.cpp
// Controlled demonstrator for JCVHT c05a1271 (NOT a malware case).
// Check: Tool Help Process32W basename == L"pin.exe" (TOMWare ProcessEnum surface).
// WORK branch (pin_count==0): copy input -> output (output SHA-256 == input SHA-256).
// EVASIVE branch (pin_count>0): do not write output; exit 2.
// Compare Native / TMW0 (-q) / TMW_DP (-dp -q) on the campaign DLL (prefix 4BBC6270).

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <string.h>

static void ToUtf8Console(void)
{
    SetConsoleOutputCP(CP_UTF8);
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
}

static int EqualsNoCaseW(const wchar_t* a, const wchar_t* b)
{
    if (!a || !b) return 0;
    while (*a && *b) {
        wchar_t ca = *a, cb = *b;
        if (ca >= L'A' && ca <= L'Z') ca = (wchar_t)(ca - L'A' + L'a');
        if (cb >= L'A' && cb <= L'Z') cb = (wchar_t)(cb - L'A' + L'a');
        if (ca != cb) return 0;
        ++a; ++b;
    }
    return *a == 0 && *b == 0;
}

static const wchar_t* BaseNameW(const wchar_t* path)
{
    const wchar_t* slash = path;
    for (const wchar_t* p = path; *p; ++p) {
        if (*p == L'\\' || *p == L'/') slash = p + 1;
    }
    return slash;
}

static int CountPinExe(void)
{
    int count = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return -1;
    PROCESSENTRY32W pe;
    ZeroMemory(&pe, sizeof(pe));
    pe.dwSize = sizeof(pe);
    if (Process32FirstW(snap, &pe)) {
        do {
            if (EqualsNoCaseW(BaseNameW(pe.szExeFile), L"pin.exe"))
                ++count;
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return count;
}

static int CopyFileRaw(const wchar_t* src, const wchar_t* dst)
{
    HANDLE in = CreateFileW(src, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (in == INVALID_HANDLE_VALUE) return 0;
    HANDLE out = CreateFileW(dst, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (out == INVALID_HANDLE_VALUE) {
        CloseHandle(in);
        return 0;
    }
    unsigned char buf[4096];
    DWORD nread = 0, nwritten = 0;
    int ok = 1;
    for (;;) {
        if (!ReadFile(in, buf, sizeof(buf), &nread, NULL)) { ok = 0; break; }
        if (nread == 0) break;
        if (!WriteFile(out, buf, nread, &nwritten, NULL) || nwritten != nread) { ok = 0; break; }
    }
    CloseHandle(out);
    CloseHandle(in);
    return ok;
}

int wmain(int argc, wchar_t** argv)
{
    ToUtf8Console();
    printf("CTRL_PE v1\n");
    printf("CHECK=CreateToolhelp32Snapshot+Process32FirstW/Process32NextW name=pin.exe\n");
    printf("ROLE=controlled_demonstrator_not_malware\n");

    if (argc != 3) {
        fprintf(stderr, "usage: TestRecoverWork.exe <input> <output>\n");
        printf("BRANCH=ERROR\n");
        return 1;
    }

    const wchar_t* inputPath = argv[1];
    const wchar_t* outputPath = argv[2];
    DWORD inAttr = GetFileAttributesW(inputPath);
    if (inAttr == INVALID_FILE_ATTRIBUTES || (inAttr & FILE_ATTRIBUTE_DIRECTORY)) {
        fprintf(stderr, "input missing\n");
        printf("BRANCH=ERROR\n");
        return 1;
    }

    const int pinCount = CountPinExe();
    printf("pin_count=%d\n", pinCount);
    if (pinCount < 0) {
        printf("BRANCH=ERROR\n");
        return 1;
    }

    if (pinCount > 0) {
        printf("BRANCH=EVASIVE\n");
        printf("work_written=0\n");
        return 2;
    }

    if (!CopyFileRaw(inputPath, outputPath)) {
        fprintf(stderr, "copy failed\n");
        printf("BRANCH=ERROR\n");
        return 1;
    }
    printf("BRANCH=WORK\n");
    printf("work_written=1\n");
    return 0;
}
