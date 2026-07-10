#pragma once
#ifndef ANTIDEBUG_MASK_H
#define ANTIDEBUG_MASK_H

#include "pin.H"

VOID AntiDebugMask_Init();
VOID AntiDebugMask_SimulateDebug_Init();
VOID AntiDebugMask_OnMainExecutable();

#endif // ANTIDEBUG_MASK_H
