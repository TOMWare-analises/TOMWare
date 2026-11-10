# Empty Pintool specification and PIN-condition probe protocol

This document states the technical basis for isolating the minimum Intel Pin
baseline in TOMWare.M, answering protocol Question 2 and specification Section 13.

---

## 1. EmptyPinTool (condition `EMPTY`)

### 1.1 Source

Source is `EmptyPinTool/EmptyPinTool.cpp`:
```cpp
#include "pin.H"

int main(int argc, char* argv[])
{
    if (PIN_Init(argc, argv))
        return 1;
    PIN_StartProgram();
    return 0;
}
```

### 1.2 Technical properties
- **No API or library hooks:** Does not intercept any OS or application call.
- **No JIT instrumentation:** Does not register TRACE, BBL, or INS callbacks.
- **No structure manipulation:** Does not touch PEB, TEB, heap, or process tables.
- **No bulky logging:** Does not write a continuous disk log; it only initializes and transfers control.
- **Binary identity:**
  - Relative path: `x64/Release/EmptyPinTool.dll`
  - Build SHA-256: `804BE19BF7924B641FE25F07EA89DEC26DC9DAA36C49638F407FF96E2AB153C8`

### 1.3 Scientific role
`EmptyPinTool` is not zero-cost: it includes loading the tool DLL into the process
address space, Pin symbol resolution, and injection-subsystem overhead. It isolates
the strict cost of the TOMWare.M infrastructure through the contrast:
$$\Delta_{TMW0} = \text{TMW0} - \text{EMPTY}$$

---

## 2. Probe of condition `PIN` (Pin engine with no tool)

### 2.1 Experimental hypothesis
Intel Pin is designed as a tool-driven dynamic instrumentation engine. In many
Windows Pin configurations and versions, invoking the executable without
`-t <tool>` is rejected or aborted by the loader.

### 2.2 Automated probe protocol
Before starting a campaign execution plan:
1. The runner runs a controlled probe:
   ```cmd
   pin.exe -- <target_benign_oracle>
   ```
2. The runner captures return code, stdout, and stderr.
3. **Validation criterion:**
   - If the process runs and completes successfully with no tool, condition `PIN` is marked `valid = true` in manifest `campaign.json` and joins the full plan (10 conditions).
   - If Pin emits an error message or invalid exit code indicating that a tool is mandatory, condition `PIN` is marked `valid = false`.
4. **Formal scientific decision:**
   - If invalid, `EMPTY` becomes the proven minimum baseline of execution under Pin.
   - The campaign operates with 9 conditions ($100 \times 9 \times 10 = 9{,}000$ runs on the main corpus).
   - Contrast `PIN - NAT` is recorded as `not_supported_by_engine` with the probe evidence attached to the audit report, without fabricating missing data.
