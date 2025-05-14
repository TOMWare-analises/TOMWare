#pragma once
#ifndef INST_ENV_RESET_H
#define INST_ENV_RESET_H

#include "pin.H"
#include <iostream>
#include "utils.h"
#include "Instrumentation.h"
#include "NtStructures.h"
#include <utility>      // std::pair

//-------------------------------------------------------------
//  ENUM que descreve o resultado de cada tentativa de limpeza
//-------------------------------------------------------------
enum class EnvScrubResult
{
    VAR_NOT_FOUND,        // 1) nenhuma alteração; a variável nem existia
    CLEARED_IN_PLACE,     // 2) bloco não realocado; resíduos limpos no mesmo buffer
    CLEARED_REALLOC       // 3) bloco realocado; buffer antigo limpo
};

static SIZE_T EnvSizeBytes(const PWCHAR env);
static EnvScrubResult UnsetAndScrub(const wchar_t* nameW);
void SanitizePinEnvVars();

#endif // INST_ENV_RESET_H