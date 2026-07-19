@echo off
setlocal EnableExtensions
REM baseline vs contramedida (de|dm|do|dd|dp|da)
REM Uso:
REM   scripts\run-baseline-dm-one.cmd SHA256 dm
REM   scripts\run-baseline-dm-one.cmd SHA256 do show
REM   scripts\run-baseline-dm-one.cmd SHA256 do loop
REM   scripts\run-baseline-dm-one.cmd SHA256 dm loop show

set "SHA=%~1"
if "%SHA%"=="" set "SHA=36685efcf34c7a7a6f6dd2e48199e4700b5ab8fe3945a50297703dd8daced74f"

set "KNOB=%~2"
if "%KNOB%"=="" set "KNOB=dm"

set "A3=%~3"
set "A4=%~4"

cd /d "%~dp0.."
mode con cols=110 lines=58

set "PS1=%~dp0run-baseline-dm-one.ps1"
set "LOOP="
set "SHOW="

if /I "%A3%"=="loop" set "LOOP=-Loop1000"
if /I "%A4%"=="loop" set "LOOP=-Loop1000"
if /I "%A3%"=="show" set "SHOW=-ShowOnly"
if /I "%A4%"=="show" set "SHOW=-ShowOnly"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Sha256 "%SHA%" -Countermeasure "%KNOB%" %LOOP% %SHOW%

endlocal
