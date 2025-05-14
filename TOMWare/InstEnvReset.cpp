#include "InstEnvReset.h"

// obtem o tamanho (bytes) do bloco UNICODE terminado em \0\0
static SIZE_T EnvSizeBytes(const PWCHAR env)
{
    SIZE_T bytes = 0;
    for (PWCHAR p = env; *p; )
    {
        SIZE_T w = wcslen(p) + 1;          // +1 p/ NUL
        bytes += w * sizeof(WCHAR);
        p += w;
    }
    return bytes + sizeof(WCHAR);          // \0\0 final
}

// remove variável e limpa resíduos conforme o caso
static EnvScrubResult UnsetAndScrub(const wchar_t* nameW)
{
    // Verifica se existe
    if (WindowsAPI::GetEnvironmentVariableW(nameW, nullptr, 0) == 0 &&
        WindowsAPI::GetLastError() == ERROR_ENVVAR_NOT_FOUND)
        return EnvScrubResult::VAR_NOT_FOUND;          // ---- caso 1

    PPEB  peb = (PPEB)WindowsAPI::NtCurrentTeb()->ProcessEnvironmentBlock;
    PWCHAR oldEnv = reinterpret_cast<PWCHAR>(peb->ProcessParameters->Environment);
    SIZE_T oldSz = EnvSizeBytes(oldEnv);

    // Remove
    WindowsAPI::SetEnvironmentVariableW(nameW, nullptr);

    PWCHAR newEnv = reinterpret_cast<PWCHAR>(peb->ProcessParameters->Environment);
    SIZE_T newSz = EnvSizeBytes(newEnv);

    if (newEnv == oldEnv)                              // ---- caso 2
    {
        if (newSz < oldSz)
            WindowsAPI::SecureZeroMemory(reinterpret_cast<BYTE*>(newEnv) + newSz, oldSz - newSz);
        return EnvScrubResult::CLEARED_IN_PLACE;
    }
    else                                               // ---- caso 3, do heap
    {
        WindowsAPI::SecureZeroMemory(oldEnv, oldSz);
        //Opcional -> RtlFreeHeap(peb->Reserved4, 0, oldEnv); // peb->Reserved4 = peb->ProcessHeap <- não documentado
        return EnvScrubResult::CLEARED_REALLOC;
    }
}

// sanitiza as variáveis “PIN_*” e mostra o status de cada uma
void SanitizePinEnvVars()
{
    static const wchar_t* vars[] = {
        L"PIN_CRT_TZDATA",
        L"PIN_APP_LD_LIBRARY_PATH",
        L"PIN_VM_LD_LIBRARY_PATH",
        L"PIN_VMLOG",
        L"PIN_APP_SHORTNAME",
        L"PIN_LOG",
        nullptr
    };

    for (const wchar_t** v = vars; *v; ++v)
    {
        EnvScrubResult r = UnsetAndScrub(*v);

        switch (r)
        {
        case EnvScrubResult::VAR_NOT_FOUND:
            wprintf(L"[=] %ls: inexistente\n", *v);
            break;
        case EnvScrubResult::CLEARED_IN_PLACE:
            wprintf(L"[=] %ls: removida (in‑place)\n", *v);
            break;
        case EnvScrubResult::CLEARED_REALLOC:
            wprintf(L"[=] %ls: removida (bloco realocado)\n", *v);
            break;
        }
    }
}