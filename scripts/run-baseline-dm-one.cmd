@echo off
setlocal
REM baseline vs contramedida (de|dm|do|dd|dp|da)
REM Uso:
REM   scripts\run-baseline-dm-one.cmd SHA256 dm
REM   scripts\run-baseline-dm-one.cmd SHA256 do show

set "SHA=%~1"
if "%SHA%"=="" set "SHA=36685efcf34c7a7a6f6dd2e48199e4700b5ab8fe3945a50297703dd8daced74f"

set "KNOB=%~2"
if "%KNOB%"=="" set "KNOB=dm"

set "MODE=%~3"
cd /d "%~dp0.."
mode con cols=110 lines=58

set "PS1=%~dp0run-baseline-dm-one.ps1"
if /I "%MODE%"=="show" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Sha256 "%SHA%" -Countermeasure "%KNOB%" -ShowOnly
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Sha256 "%SHA%" -Countermeasure "%KNOB%"
)

endlocal
