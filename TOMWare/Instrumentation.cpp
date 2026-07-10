#include "Instrumentation.h"
#include "SanitizePinEnvVars.h"
#include "SkewMask.h"
#include "AntiDebugMask.h"
#include "ProcessEnumMask.h"
#include "TomwareLog.h"

#include <sstream>

PIN_LOCK lock;

std::map<std::string, RTNFunction> strategyMap;

KNOB<BOOL> KnobDefendAll(KNOB_MODE_WRITEONCE, "pintool", "da", "0", "Ativa todas as contramedidas (-de -dm -do -dd -dp, sem -go)");
KNOB<BOOL> KnobMemoryDefend(KNOB_MODE_WRITEONCE, "pintool", "dm", "0", "Ativa a contramedida InstMemcmpMask");
KNOB<BOOL> KnobEnvsDefend(KNOB_MODE_WRITEONCE, "pintool", "de", "0", "Ativa a contramedida SanitizePinEnvVars");
KNOB<BOOL> KnobOverheadDefend(KNOB_MODE_WRITEONCE, "pintool", "do", "0", "Ativa a contramedida SkewMask");
KNOB<BOOL> KnobDebugDefend(KNOB_MODE_WRITEONCE, "pintool", "dd", "0", "Ativa a contramedida AntiDebugMask");
KNOB<BOOL> KnobProcessEnumDefend(KNOB_MODE_WRITEONCE, "pintool", "dp", "0", "Ativa a contramedida ProcessEnumMask");
KNOB<std::string> KnobSignatureFile(KNOB_MODE_WRITEONCE, "pintool", "sf", "config/signatures.txt", "Arquivo de assinaturas extras para InstMemcmpMask");
KNOB<BOOL> KnobSimulateOverhead(KNOB_MODE_WRITEONCE, "pintool", "go", "0", "Gerador de overhead artificial (apenas demonstracoes; use com -do)");
KNOB<BOOL> KnobSimulateDebug(KNOB_MODE_WRITEONCE, "pintool", "gdb", "0", "Simula indicadores anti-debug no PEB (apenas demonstracoes; use com -dd no benchmark)");
KNOB<BOOL> KnobQuiet(KNOB_MODE_WRITEONCE, "pintool", "q", "0", "Modo silencioso (suprime logs informativos das contramedidas)");
KNOB<UINT32> KnobMaxExceptions(KNOB_MODE_WRITEONCE, "pintool", "me", "0", "Limite de excecoes antes de abortar (0 = ilimitado, continua execucao)");

static volatile WindowsAPI::LONG g_exceptionCount = 0;

BOOL memoryDefend = false;
BOOL envsDefend = false;
BOOL overheadDefend = false;
BOOL debugDefend = false;
BOOL processEnumDefend = false;
BOOL simulateOverhead = false;

void InitStrategies() {

    if (memoryDefend) {
        InstMemcmpMask_LoadSignatures(KnobSignatureFile.Value().c_str());
        // Estrategias para o scan de memoria. Todas na lógica da classe InstMemcmpMask
        strategyMap["memcmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["_memcmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["__acrt_memcmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["bcmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["memicmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["_memicmp_l"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["_memicmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["memcmp_s"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["wmemcmp"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["wmemcmp_s"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["RtlCompareMemory"] = &InstMemcmpMask::InstrumentFunction;
        strategyMap["RtlEqualMemory"] = &InstMemcmpMask::InstrumentFunction;
        // Fin estrategias para o scan de memoria.
    }
    

}

VOID InstrumentFunctions(IMG img, VOID* v) {
    if (IMG_IsMainExecutable(img)) {
        if (debugDefend) {
            AntiDebugMask_OnMainExecutable();
        }
    }

    std::string moduleName = IMG_Name(img);
    for (SYM sym = IMG_RegsymHead(img); SYM_Valid(sym); sym = SYM_Next(sym)) {
        RTN rtn = RTN_FindByAddress(IMG_LowAddress(img) + SYM_Value(sym));
        if (RTN_Valid(rtn)) {
            std::string funcName = RTN_Name(rtn);
            for (const auto& pair : strategyMap) {
                std::string strategyName = pair.first.c_str();
                if (strategyName == funcName) {
                    RTNFunction func = pair.second;
                    func(rtn, 0);

                }
            }
        }
    }
}

// Protecao contra loop infinito: se a mesma instrucao falhar repetidamente
// (EHR_HANDLED reexecuta o mesmo IP), abortamos apos um teto rigido para nao
// inundar o log com a mesma excecao indefinidamente.
static const UINT64 TOMWARE_SAME_FAULT_LIMIT = 64;

EXCEPT_HANDLING_RESULT ExceptionHandler(THREADID tid, EXCEPTION_INFO* pExceptInfo, PHYSICAL_CONTEXT* pPhysCtxt, VOID* v)
{
    const WindowsAPI::LONG count = WindowsAPI::InterlockedIncrement(&g_exceptionCount);

    const ADDRINT faultIp = PIN_GetExceptionAddress(pExceptInfo);
    static ADDRINT s_lastFaultIp = 0;
    static UINT64 s_sameFaultCount = 0;
    if (faultIp == s_lastFaultIp)
        ++s_sameFaultCount;
    else
    {
        s_lastFaultIp = faultIp;
        s_sameFaultCount = 1;
    }

    if (s_sameFaultCount <= TOMWARE_SAME_FAULT_LIMIT)
    {
        std::ostringstream oss;
        oss << "[TOMWare] Excecao no thread " << tid << " (#" << count << "): "
            << PIN_ExceptionToString(pExceptInfo);
        TomwareLogErr(oss.str());
    }

    if (s_sameFaultCount > TOMWARE_SAME_FAULT_LIMIT)
    {
        TomwareLogErr("[TOMWare] Excecao repetida na mesma instrucao; abortando para evitar loop.");
        exit(2);
    }

    const UINT32 limit = KnobMaxExceptions.Value();
    if (limit > 0 && static_cast<UINT32>(count) >= limit)
    {
        TomwareLogErr("[TOMWare] Limite de excecoes atingido (" + std::to_string(limit) + "), encerrando.");
        exit(1);
    }

    return EXCEPT_HANDLING_RESULT::EHR_HANDLED;
}


static VOID InstOverheadGen(THREADID, CONTEXT* ctx)
{
    for (int i = 0; i < 10000; ++i) __nop();
}

VOID SimulateOverhead(INS ins, VOID*)
{
    INS_InsertCall(ins, IPOINT_BEFORE, AFUNPTR(InstOverheadGen),
        IARG_THREAD_ID, IARG_CONST_CONTEXT, IARG_END);
}

int InitInstrumentation()
{
    TomwareSetQuietMode(KnobQuiet);

    if (KnobDefendAll) {
        memoryDefend = true;
        envsDefend = true;
        overheadDefend = true;
        debugDefend = true;
        processEnumDefend = true;
    }
    if (KnobMemoryDefend) {
        memoryDefend = true;
    }
    if (KnobEnvsDefend) {
        envsDefend = true;
    }
    if (KnobOverheadDefend) {
        overheadDefend = true;
    }
    if (KnobDebugDefend) {
        debugDefend = true;
    }
    if (KnobProcessEnumDefend) {
        processEnumDefend = true;
    }
    if (KnobSimulateOverhead) {
        simulateOverhead = true;
    }

    const BOOL simulateDebug = KnobSimulateDebug.Value();

    // Iniciar o PIN e instrumenta��o
    PIN_InitLock(&lock);
    PIN_InitSymbols();

    IMG_AddInstrumentFunction(InstrumentFunctions, 0);

    if (envsDefend) {
        SanitizePinEnvVars_Init();
    }

    PIN_AddInternalExceptionHandler(ExceptionHandler, NULL);

    InitStrategies();

    if (overheadDefend) {
        SkewMask_Init();
    }

    if (debugDefend) {
        AntiDebugMask_Init();
    }

    if (simulateDebug) {
        AntiDebugMask_SimulateDebug_Init();
    }

    if (processEnumDefend) {
        ProcessEnumMask_Init();
    }

    if (simulateOverhead) {
        INS_AddInstrumentFunction(SimulateOverhead, 0);
    }

    PIN_StartProgram();
    return 0;
}