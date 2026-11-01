# Overleaf patches for the current Access PDF (V-B, VI-C, VII-A + memcmp + 22/30)

The PDF still in Portuguese in these places. **Delete** the sentences that deny a Module32 positive control. **Paste** the English below. Do not mix JCVHT cells.

CSV sources (campaign DLL `4BBC6270`):
- `experiment/results/oracles/module32_fixture.csv`
- `experiment/results/oracles/da_n10.csv` (five rows; the `n10` in the filename is the parent campaign id `t2_n10_v7b`, **not** ten `-da` repetitions)
- `experiment/results/oracles/memcmp_n10.csv` and `memcmp_controls_n10.txt`
- `experiment/results/oracles/fidelity_by_run.csv`

---

## DELETE (Portuguese — still in V-B, VI-C, VII-A)

V-B (ProcessEnum, complementary TestModule32 paragraph):

> Esses registros verificam o término da enumeração e a disponibilidade de uma entrada não filtrada, mas não demonstram a ocultação de um módulo monitorado. […] Os registros apresentados não incluem controles positivos específicos para a ocultação de módulos por Module32* ou GetModuleHandleA/W.

VI-C:

> em particular, a ausência de módulos monitorados na referência não constitui controle positivo de sua ocultação.

VII-A:

> ProcessEnum ocultou as entradas de processo monitoradas; a ausência dos módulos-alvo na referência impede confirmar sua filtragem por Module32.

Also delete any remaining claim that InstMemcmpMask was validated **only** through `memcmp` in `TestMemoryScan.exe` without naming `_memicmp` and `RtlCompareMemory`.

---

## 1. REPLACE V-B — ProcessEnum functional validation (after Table 6)

Keep Table 6 (`pin.exe` 3 / 0 / 0). Then replace the TestModule32 paragraph with:

The process oracle `TestProcessEnum.exe` enumerates processes through the Unicode Tool Help path. One run per configuration reported three `pin.exe` entries under `-q` and zero under `-dp -q` and `-da -q` (Table 6).

A separate positive control exercised Module32 filtering (`module32_fixture.csv`). A copy of `C:\Windows\System32\version.dll` was loaded as `%TEMP%\pinvm.dll`. That file is a dummy name; it is **not** the real Pin module. Native and TMW0 (`-q`) enumerated the fixture (`fixture_pinvm=1`, `pinish=1`). With `-dp -q` and `-da -q` the fixture name was hidden (`fixture_pinvm=0`, `pinish=0`). `kernel32.dll` remained visible in all four runs. Enumeration terminated (`ENUM_OK`). Module counts were 32 (native), 31 (TMW0), and 30 (`-dp` and `-da`).

**Table (Module32 fixture, one run per configuration)**

| Configuration | Knobs | Exit | Modules | `kernel32.dll` | fixture `pinvm.dll` | Terminated |
|---|---|---|---|---|---|---|
| Native | (none) | 0 | 32 | visible | visible | yes |
| TMW0 | `-q` | 0 | 31 | visible | visible | yes |
| ProcessEnum | `-dp -q` | 0 | 30 | visible | hidden | yes |
| Combined | `-da -q` | 0 | 30 | visible | hidden | yes |

This fixture does **not** validate `NtQuerySystemInformation` and does **not** individually validate every `GetModuleHandleA`/`GetModuleHandleW` calling pattern. ANSI and Unicode Process32/Module32 variants were not exercised as a full matrix.

---

## 2. INSERT after the five oracle subsections (or as VI-C paragraph + table) — combined `-da`

The filename `da_n10.csv` belongs to campaign id `t2_n10_v7b`. It contains **five rows, one execution per oracle**, not ten repetitions of combined mode.

| Oracle | Knobs | Exit | Timed out | Duration (ms) | Observed indicator |
|---|---|---|---|---|---|
| TestAntiDebug | `-gdb -da -q` | 0 | no | 10316 | PEB fields 0 |
| TestProcessEnum | `-da -q` | 0 | no | 13413 | `pin.exe` 0 |
| TestGetEnvironments | `-da -q` | 0 | no | 13324 | `PIN_*` 0 |
| TestMemoryScan | `-da -q` | 0 | no | 44062 | monitored signatures 0 |
| TestOverhead | `-da -q` | 0 | no | 14658 | 2042.56 < 3000 |

This is a basic functional smoke test. It does not prove the absence of module interactions on the 100-binary corpus. TMW_ALL in the 9,000 attempts is a separate operational arm.

---

## 3. REPLACE V InstMemcmpMask “1) Validação funcional controlada”

Keep the `TestMemoryScan.exe` / Table 12 `memcmp` signature counts. Then add the family controls from `memcmp_n10.csv` (campaign DLL `4BBC6270`, campaign id `t2_n10_v7b`, one run per configuration):

On the campaign DLL, intercepted **PIN-string** comparisons were PASS under native and TMW0 and MASKED under `-dm -q` and `-da -q` for `memcmp`, `_memicmp`, and `RtlCompareMemory`. Legitimate equality and inequality (pass-through) remained OK on those three routines. Length-zero `memcmp` returned 0.

| Configuration | Knobs | Exit | `memcmp` PIN | `_memicmp` PIN | `RtlCompareMemory` PIN |
|---|---|---|---|---|---|
| Native | (none) | 0 | PASS (ret=0) | PASS (ret=0) | PASS (n=4) |
| TMW0 | `-q` | 0 | PASS | PASS | PASS |
| InstMemcmpMask | `-dm -q` | 2 | MASKED (ret=1) | MASKED (ret=1) | MASKED (n=0) |
| Combined | `-da -q` | 2 | MASKED | MASKED | MASKED |

`RtlEqualMemory`, `wmemcmp`, `memcmp_s`, `wmemcmp_s`, and `bcmp` were ABSENT / NOT_EXERCISED (`GetProcAddress` did not yield a usable export). They are implemented in the Pintool but were **not** individually validated in this revision.

`_memicmp_l` is exported by `msvcrt.dll` (`FOUND`). Under native and TMW0 the PIN-string control was PASS. Under `-dm` and `-da` the PIN-string path printed MASKED and the subsequent pass-through control aborted with `RECEIVED_ACCESS_FAULT` at `0xffffffffffffffff` (exit 2). The campaign wrapper treated `_memicmp_l` as a three-argument routine; the CRT export takes a fourth locale argument. A later build (`D55EC952`, four-argument hook) is a **different DLL identity** and does **not** retroactively validate the 9,000-attempt campaign, which used `4BBC6270`.

---

## 4. INSERT in Results (VI), not only the Introduction — 22/30

A separate diagnostic, **not** part of the 9,000-attempt corpus, compared TMW0 (`-q`) with TMW_ALL (`-da`) under an external observer (`external_ps`). The observer recorded the process exit code and the SHA-256 of standard output. It did not record API traces, code coverage, or kernel events. FidelityProbe was not run. Guest timeout: 45 s. Raw: `fidelity_by_run.csv`.

Ten executables (BEN_05, BEN_06, BEN_10, BEN_12, BEN_14, MAL_01, MAL_02, MAL_06, MAL_07, MAL_11) × three independent repetitions = 30 TMW0–TMW_ALL pairs.

**Agreement criterion:** equal exit code **and** equal stdout SHA-256. An empty stdout is hashed as the empty buffer; agreement on an empty buffer remains an external observable only.

**Result:** 22 of 30 pairs agreed; 8 disagreed.

| Pair | TMW0 | TMW_ALL | Reading |
|---|---|---|---|
| BEN_06 × 3 | exit 3 | timeout (`-2`) | Combined activation changed the recorded outcome |
| BEN_12 × 2 | exit 0, stdout 754 B | timeout; the finished attempt kept the same 754 B hash | Text matched when the process exited; two attempts did not exit in time |
| MAL_06 × 1 | exit 0 | exit 2 | One of three repetitions differed |
| MAL_07 × 2 | exit 0 | `0xC0000005` | Combined activation worsened termination |

This diagnostic does **not** demonstrate equivalence of APIs, control flow, or external effects (files, registry, or network). Longer wall-clock under TMW_ALL in several agreeing pairs is cost, not a fidelity gain.

---

## REPLACE VI-C sentence and VII-A sentence

**VI-C** (replace the “ausência de módulos” clause):

The five oracles tested debugging, enumeration, environment variables, memory comparison, and timing. Those results are not evidence that corpus binaries performed the same checks. ProcessEnum now includes a Module32 positive control on a dummy `%TEMP%\pinvm.dll` copy of `version.dll` (hidden under `-dp` and `-da`; `kernel32.dll` remained visible). Combined activation was smoke-tested once per oracle (`da_n10.csv`; the filename does not mean ten repetitions). InstMemcmpMask family controls cover `memcmp`, `_memicmp`, and `RtlCompareMemory`; `_memicmp_l` faulted on the campaign DLL; several comparison exports were not exercised.

**VII-A** (replace the Module32 denial):

ProcessEnum hid the `pin.exe` process entries on the Tool Help path that the process oracle exercised, and hid the dummy `pinvm.dll` fixture on the Module32 path. The fixture is not the real Pin module. `GetModuleHandleA`/`W` and native `NtQuerySystemInformation` remain without individual validation.
