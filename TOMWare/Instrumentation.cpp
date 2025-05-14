#include "Instrumentation.h"
#include "InstEnvReset.h"
#include "SkewMask.h"

PIN_LOCK lock;

std::map<std::string, RTNFunction> strategyMap;

KNOB<BOOL> KnobDefendAll(KNOB_MODE_WRITEONCE, "pintool", "da", "0", "Ativa todas as contramedidas");
KNOB<BOOL> KnobMemoryDefend(KNOB_MODE_WRITEONCE, "pintool", "dm", "0", "Ativa a contramedida MemcmpMask");
KNOB<BOOL> KnobEnvsDefend(KNOB_MODE_WRITEONCE, "pintool", "de", "0", "Ativa a contramedida EnvReset");
KNOB<BOOL> KnobOverheadDefend(KNOB_MODE_WRITEONCE, "pintool", "do", "0", "Ativa a contramedida SkewMask"); // para testar a contramedida é necessário ativar a simulação de overhead -> simulateOverhead = true
KNOB<BOOL> KnobSimulateOverhead(KNOB_MODE_WRITEONCE, "pintool", "go", "0", "Gerador de overhead para testar a contramedida SkewMask");

BOOL memoryDefend = false;
BOOL envsDefend = false;
BOOL overheadDefend = false; // para testar a contramedida é necessário ativar a simulação de overhead -> simulateOverhead = true
BOOL simulateOverhead = false;

void InitStrategies() {

    if (memoryDefend) {
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
        if (envsDefend) {
            SanitizePinEnvVars();       
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

EXCEPT_HANDLING_RESULT ExceptionHandler(THREADID tid, EXCEPTION_INFO* pExceptInfo, PHYSICAL_CONTEXT* pPhysCtxt, VOID* v) {
    std::cerr << "Exce��o detectada no thread " << tid << ": "
        << PIN_ExceptionToString(pExceptInfo) << std::endl;
    exit(1);
    return EXCEPT_HANDLING_RESULT::EHR_HANDLED;
    // Pode-se modificar o contexto ou apenas registrar o erro
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

    if (KnobDefendAll) {
        memoryDefend = true;
        envsDefend = true;
        overheadDefend = true; 
        simulateOverhead = true;
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
    if (KnobSimulateOverhead) {
        simulateOverhead = true;
    }


    // Iniciar o PIN e instrumenta��o
    PIN_InitLock(&lock);
    PIN_InitSymbols();

    IMG_AddInstrumentFunction(InstrumentFunctions, 0);

    PIN_AddInternalExceptionHandler(ExceptionHandler, NULL);

    InitStrategies();

    if (overheadDefend) {
        SkewMask_Init();
    }

    if (simulateOverhead) {
        INS_AddInstrumentFunction(SimulateOverhead, 0);
    }

    PIN_StartProgram();
    return 0;
}