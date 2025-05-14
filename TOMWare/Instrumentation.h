#pragma once

#ifndef INSTRUMENTATION_H
#define INSTRUMENTATION_H

#include "pin.H"

#include <set>
#include <cctype>
#include <map>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <deque>
#include <cwctype> // Para fun��es de verifica��o de caracteres wide, como iswalnum
#include <cstdint>

#include "NtStructures.h"
#include "Utils.h"
#include "InstrumentationUtils.h"
#include "regvalue_utils.h"

#include "InstMemcmpMask.h"

extern KNOB<bool> KnobDetailLevel; // Assume que KnobDetailLevel est� definido em params.h

typedef void (*RTNFunction)(RTN, VOID*);

struct CallContext {
    ADDRINT rtnAddress;
    std::stringstream stringStream;
    VOID* functionArgs;
    THREADID threadId; // Identificador da thread

    // Construtor para inicializar o contexto com IDs
    CallContext(THREADID tid, ADDRINT rtnAddr, VOID* args) : threadId(tid), rtnAddress(rtnAddr), functionArgs(args) {}
};

BOOL IsMainExecutable(ADDRINT address);
ADDRINT GetRtnAddr(ADDRINT instAddress);
std::string getFileName(const std::string& filePath);
VOID PauseAtAddress(ADDRINT address);
void InitStrategies();
VOID InstrumentFunctions(IMG img, VOID* v);

int InitInstrumentation();

#endif // INSTRUMENTATION_H