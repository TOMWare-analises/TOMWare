#pragma once
#ifndef INST_MEMCMP_MASK_H
#define INST_MEMCMP_MASK_H

#include "pin.H"
#include <cstring>
#include <cwchar>
#include <string.h>
#include "utils.h"
#include "Instrumentation.h"
#include "InstrumentationStrategy.h"

class InstMemcmpMask : public InstrumentationStrategy {
public:
    static VOID InstrumentFunction(RTN rtn, VOID* printFcn);
private:
    
};

#endif
