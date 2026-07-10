#include "SanitizePinEnvVars.h"
#include "TomwareLog.h"
#include "utils.h"

#include <string>
#include <fstream>
#include <cwchar>

// -----------------------------------------------------------------------------
// Estrategia: sanitizar o BLOCO DE AMBIENTE no PEB do processo alvo, em contexto
// da aplicacao, ANTES do entry point (logo, antes da inicializacao do CRT).
//
// Por que no PEB e nao via RTN_Replace das APIs de ambiente?
//   - Exports como GetEnvironmentStringsW em kernel32/kernelbase sao
//     encaminhados/thunk; o RTN_Replace "instala" mas a chamada da aplicacao
//     nao e desviada (no-op silencioso) neste Pin/Windows. Comprovado: os hooks
//     nunca eram chamados em runtime.
//   - Sanitizar o bloco do PEB e agnostico ao metodo: cobre de uma vez
//       * GetEnvironmentStringsW/A (retornam copia do bloco do PEB),
//       * GetEnvironmentVariableW/A (consultam o bloco do PEB),
//       * _dupenv_s / _wenviron / getenv (copia do CRT, feita DEPOIS do
//         ApplicationStart, a partir do bloco ja sanitizado).
//
// O bloco e uma sequencia de "NOME=VALOR\0" (wide), terminada por "\0\0".
// Para cada entrada que comeca com "PIN_", reescrevemos o prefixo "PIN" para
// "ZZZ" in-place (mesmo tamanho => estrutura do bloco intacta). Assim a busca
// por "PIN_..." feita pelo malware nao casa.
// -----------------------------------------------------------------------------

static volatile long gMaskedTotal = 0;

static std::ofstream gLog;

static void LogEvent(const std::string& line)
{
    if (gLog.is_open())
        gLog << line << std::endl; // endl => flush a cada evento
    LOG(line + "\n");              // canal nativo do Pin (pintool.log)
}

static bool StartsWithPinW(const wchar_t* s)
{
    return s
        && (s[0] == L'P' || s[0] == L'p')
        && (s[1] == L'I' || s[1] == L'i')
        && (s[2] == L'N' || s[2] == L'n')
        && (s[3] == L'_');
}

// Nome da variavel (parte antes de '='), convertido para ASCII para log.
static std::string EnvNameAscii(const wchar_t* p)
{
    std::string name;
    for (const wchar_t* q = p; *q && *q != L'='; ++q)
    {
        const wchar_t c = *q;
        name += (c >= 32 && c < 127) ? static_cast<char>(c) : '?';
    }
    return name;
}

static bool ContainsPinCI(const wchar_t* p)
{
    for (const wchar_t* q = p; *q && *q != L'='; ++q)
    {
        if ((q[0] == L'P' || q[0] == L'p')
            && (q[1] == L'I' || q[1] == L'i')
            && (q[2] == L'N' || q[2] == L'n'))
            return true;
    }
    return false;
}

static int SanitizeEnvironmentBlock()
{
    PPEB peb = reinterpret_cast<PPEB>(WindowsAPI::NtCurrentTeb()->ProcessEnvironmentBlock);
    if (!peb)
        return -1;

    PRTL_USER_PROCESS_PARAMETERS pp = peb->ProcessParameters;
    if (!pp)
        return -2;

    wchar_t* env = reinterpret_cast<wchar_t*>(pp->Environment);
    if (!env)
        return -3;

    int masked = 0;
    for (wchar_t* p = env; *p; )
    {
        const size_t len = wcslen(p) + 1;

        // Diagnostico: qualquer entrada que contenha "PIN" no nome.
        if (ContainsPinCI(p))
            LogEvent("[SanitizePinEnvVars]   (scan) entrada com 'PIN' no nome: " + EnvNameAscii(p));

        if (StartsWithPinW(p) && PIN_CheckWriteAccess(p))
        {
            LogEvent("[SanitizePinEnvVars]   neutralizando: " + EnvNameAscii(p) + " -> ZZZ_...");
            p[0] = L'Z';
            p[1] = L'Z';
            p[2] = L'Z';
            ++masked;
        }
        p += len;
    }
    return masked;
}

static VOID OnApplicationStart(VOID*)
{
    const int masked = SanitizeEnvironmentBlock();
    if (masked >= 0)
    {
        gMaskedTotal = masked;
        LogEvent("[SanitizePinEnvVars] ApplicationStart: bloco de ambiente sanitizado, "
            + std::to_string(masked) + " variaveis PIN_ renomeadas para ZZZ_");
    }
    else
    {
        LogEvent("[SanitizePinEnvVars] ApplicationStart: falha ao acessar o bloco de ambiente (codigo "
            + std::to_string(masked) + ")");
    }
}

static VOID SanitizePinEnvVars_Fini(INT32, VOID*)
{
    LogEvent("[SanitizePinEnvVars] RESUMO: total de variaveis PIN_ neutralizadas no PEB: "
        + std::to_string(gMaskedTotal));
    if (gLog.is_open())
        gLog.close();
}

VOID SanitizePinEnvVars_Init()
{
    gLog.open("tomware-envvars.log", std::ios::trunc);
    if (gLog.is_open())
        gLog << "[SanitizePinEnvVars] log iniciado" << std::endl;

    PIN_AddApplicationStartFunction(OnApplicationStart, 0);
    PIN_AddFiniFunction(SanitizePinEnvVars_Fini, 0);
}
