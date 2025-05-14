// Exemplo: enumerando variáveis de ambiente com GetEnvironmentStringsW
// Compilação (MSVC): cl /EHsc /W4 env_example.cpp

#include <windows.h>
#include <iostream>
#include <string>
#include "Measurement.h"

void GetEnvString() {
    // Obtém o bloco de strings de ambiente (Unicode)
    LPWCH envBlock = GetEnvironmentStringsW();
    if (envBlock == nullptr)
    {
        std::wcerr << L"Falha em GetEnvironmentStringsW. Erro = " << GetLastError() << std::endl;
        return;
    }

    BOOL detected = false;

    // Cada variável termina em '\0'; o bloco termina em '\0''\0'
    LPWCH current = envBlock;
    while (*current)
    {
        // Constrói um std::wstring a partir da string wide-char atual
        std::wstring envVar(current);

        // Exibe a variável encontrada
        if ((envVar.find(L"PIN_APP_LD_LIBRARY_PATH") != std::string::npos) || (envVar.find(L"PIN_VM_LD_LIBRARY_PATH") != std::string::npos) || (envVar.find(L"PIN_CRT_TZDATA") != std::string::npos)) {
            std::wcout << L"PIN Detectado com a variavel " << envVar << std::endl;
            detected = true;
        }

        //std::wcout << L"Variavel " << envVar << std::endl;

        // Avança para a próxima string (pula até o próximo '\0')
        current += envVar.size() + 1;
    }

    if (!detected) {
        std::wcout << L"Nenhuma variável do PIN detectada." << std::endl;
    }

    // Libera o bloco alocado pela API
    if (!FreeEnvironmentStringsW(envBlock))
    {
        std::wcerr << L"Falha em FreeEnvironmentStringsW. Erro = "
            << GetLastError() << std::endl;
    }
    std::wcout << L"----------------------------------------------------------" << std::endl;

}

void Dupenv() {
    char* pValue;
    size_t len;
    errno_t err = _dupenv_s(&pValue, &len, "PIN_CRT_TZDATA");
    if (!err && pValue) {
        printf("PIN_CRT_TZDATA = %s\n", pValue);
    }
    free(pValue);
}


void PrintAsciiString(const char* p, const MEMORY_BASIC_INFORMATION& mbi)
{
    const BYTE* regionEnd = static_cast<const BYTE*>(mbi.BaseAddress) + mbi.RegionSize;
    char buf[260] = { 0 };         // corta em 259 chars
    size_t i = 0;

    while (p < reinterpret_cast<const char*>(regionEnd) && *p && i < sizeof(buf) - 1)
    {
        buf[i++] = std::isprint(static_cast<unsigned char>(*p)) ? *p : '.';
        ++p;
    }
    printf("  \"%s\"\n", buf);
}

void testGetPinEnvs() {
    // ***** Método 1 *****
    GetEnvString();

    // ***** Método 2 *****
    Dupenv();
}

int wmain()
{
    //testGetTickCountConsistency(1000, &testGetPinEnvs, L"tick_test_log-GetEnvironments.txt");
    testGetPinEnvs();

    system("pause");
    return 0;
}
