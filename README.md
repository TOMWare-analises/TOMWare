# **TOMWare.M — Mitigating Anti-Instrumentation Techniques in DBI Environments**

**TOMWare.M** (*Transparency and Overhead Measurement for Malware*) is a modular Dynamic Binary Instrumentation (DBI) tool built on **Intel Pin**, aimed at mitigating anti-instrumentation techniques in Windows x64 executables.

Repository: [https://github.com/TOMWare-analises/TOMWare](https://github.com/TOMWare-analises/TOMWare)

---

## Abstract

TOMWare.M is a modular DBI pintool built on Intel Pin to mitigate anti-instrumentation techniques. It implements five selectively activatable countermeasures targeting debugging indicators, process enumeration, environment variables, memory signatures, and execution-time discrepancies. The five modules were validated through controlled test applications; execution times were recorded before and after activation. Results indicate that the countermeasures reduce the corresponding instrumentation indicators in the evaluated scenarios, while temporal impact varies according to the intercepted mechanism and its activation frequency.

TOMWare.M implements five selectively activatable countermeasures (`-dd`, `-dp`, `-de`, `-dm`, `-do`), validated with controlled test applications and exercisable on real samples under Pin. It provides an experimental platform to investigate the relationship between **transparency** and **temporal impact** in DBI environments.

---

## Table of Contents

* [1. Structure of this README](#1-structure-of-this-readme)
  * [1.1 Organization](#11-organization)
  * [1.2 Distributed artifacts](#12-distributed-artifacts)
  * [1.3 Repository layout](#13-repository-layout)
  * [1.4 Demonstration videos (playlist)](#14-demonstration-videos-playlist)
* [2. Artifact badges considered](#2-artifact-badges-considered)
* [3. Basic information](#3-basic-information)
  * [3.1 Introduction to execution and experiments](#31-introduction-to-execution-and-experiments)
  * [3.2 Main features](#32-main-features)
  * [3.3 Architecture](#33-architecture)
  * [3.4 How execution is structured](#34-how-execution-is-structured)
  * [3.5 Recommended environment](#35-recommended-environment)
* [4. Dependencies](#4-dependencies)
* [5. Security](#5-security)
* [6. Installation](#6-installation)
* [7. Minimal test](#7-minimal-test)
* [8. Experiments](#8-experiments)
* [9. License](#9-license)

---

# 1. Structure of this README

## 1.1 Organization

This README is organized into the following main sections:

1. **Structure of this README** — overview of the document, repository, and **video playlist** (§1.4).
2. **Artifact badges considered** — the four CTA artifact badges (D / F / S / R).
3. **Basic information** — introduction, modules, architecture, and environment.
4. **Dependencies** — host, build, and VM requirements (+ installers on Drive; samples in `samples/`).
5. **Security** — mandatory isolation when running real samples.
6. **Installation** — optional build and basic pintool syntax.
7. **Minimal test** — quick validation with test apps (no malware).
8. **Experiments** — baseline vs countermeasure, corpus, timing, and evidence (§8.6).
9. **License** — terms of use.

## 1.2 Distributed artifacts

* Source code of the **TOMWare** pintool (`TOMWare/`).
* Pre-built test binaries (`Resultados/Apps-Teste/`), including `Loop_X_1000/` variants.
* Sources of the test applications (`Resultados/Apps-Teste-src/`).
* Intel Pin 3.28 MSVC x64 (`pin/`), when included in the distribution.
* Signatures for memory masking (`config/signatures.txt`).
* Execution and benchmark scripts (`scripts/`).
* Current execution-flow diagram (`imgs/tomware-fluxo-execucao-23072026.png`).
* Experiment captures and results (`Resultados/`), including consolidated evidence under `Resultados/evidencias_VM/` — see §8.6.
* Installer package (Git, Visual Studio, 7-Zip, VMware, Pin, TOMWare, ISO) on [Google Drive — Installers](https://drive.google.com/drive/folders/18bq-fFzjVcBa1-KuJIoL5KAmS_AHkAtB?usp=sharing) — see §4.4.
* Corpus of **benign** and **infected** samples in `samples/` in this repository — see §4.5.
  (Google Drive blocks public sharing of these files by policy; therefore the corpus is shipped via Git.)
* Video playlist (download → installation → configuration → execution → results) in the Drive folder **`demonstracao`** — see §1.4.

> The goal of the artifacts is to enable: (1) exploring the code; (2) verifying functionality (minimal test); (3) reproducing the paper experiments (test apps + real samples under Pin); (4) assessing the temporal impact of the countermeasures.

## 1.3 Repository layout

```text
TOMWare/                              ← repository root (this README)
├── TOMWare/                          ← pintool source (.cpp/.h)
├── pin/                              ← Intel Pin 3.28 (x64, MSVC)
├── config/                           ← signatures (-sf), corpus, mappings
├── scripts/                          ← execution and benchmarks
│   ├── run-sample.ps1
│   ├── run-baseline-dm-one.ps1/.cmd  ← baseline vs one countermeasure (same print)
│   ├── benchmark-poc.ps1
│   ├── benchmark-corpus.ps1
│   ├── benchmark-infected.ps1
│   └── lib/TomwareBenchmark.ps1
├── imgs/                             ← README / architecture figures
├── samples/                          ← experiment corpus (§4.5)
│   ├── benign/                       ← <SHA256>.exe (benign)
│   └── infected/                     ← <SHA256>.zip (infected; password in password.txt)
├── Resultados/
│   ├── Apps-Teste/                   ← test-app executables
│   │   └── Loop_X_1000/              ← same apps with 1000 iterations
│   ├── Apps-Teste-src/               ← test-app sources
│   ├── Capturas-Tela/                ← experiment screenshots
│   ├── Avaliacao/                    ← benchmark outputs (when generated)
│   ├── benchmarks/                   ← per-run CSV/JSON (generated on the VM)
│   └── evidencias_VM/                ← published evidence (PDF/CSV/JSON) — §8.6
│       ├── benign/                   ← benign corpus (per hash + consolidated)
│       ├── malign/                   ← infected corpus (per hash + consolidated)
│       └── comparativo/              ← benign vs infected
├── TOMWare.sln
├── LICENSE
└── README.md
```

> **Important:** when downloading the GitHub `.zip`, the folder may be named `TOMWare-main`. Adjust example paths to your extraction location.  
> On the VM, copy/extract samples from `samples/` into `C:\TOMWare\malwares\benign\` and `C:\TOMWare\malwares\infected\` (§4.5).

## 1.4 Demonstration videos (playlist)

Screencasts with **burned-in subtitles** (PT-BR). The playlist is a **flow demonstration** (download → installation → configuration → sample run → collection), aligned with this README — it does **not** cover every experiment in §8.

Drive folder: **`demonstracao`** (next to the [installer package](https://drive.google.com/drive/folders/18bq-fFzjVcBa1-KuJIoL5KAmS_AHkAtB?usp=sharing)).

### Watch order

| # | Phase | What the video shows | File | README |
|---|-------|----------------------|------|--------|
| 01 | Download | Git for Windows | `01-download-git.mp4` (+ `.srt`) | §4.4 |
| 02 | Download | Visual Studio Community | `02-download-visual-studio.mp4` (+ `.srt`) | §4.2 / §4.4 |
| 03 | Download | 7-Zip | `03-download-7zip.mp4` (+ `.srt`) | §4.3 / §4.4 |
| 04 | Download | VMware Workstation | `04-download-vmware.mp4` (+ `.srt`) | §3.5 / §4.4 |
| 05 | Download | Windows 10/11 **x64** ISO | `05-download-windows-iso-x64.mp4` (+ `.srt`) | §3.5 / §4.4 |
| 06 | Installation | Install Git | `06-instalacao-git.mp4` | §6.1.1 |
| 07 | Installation | Install Visual Studio (C++ + **v142**) | `07-instalacao-visual-studio.mp4` | §6.1.2 |
| 08 | Installation | Install 7-Zip | `08-instalacao-7zip.mp4` | §4.3 |
| 09 | Installation | Install VMware + create Windows VM | `09-instalacao-vmware-e-criacao-vm.mp4` | §3.5 / §8.1 |
| 10 | Configuration | VM network disabled (before samples) | `10-config-vm-rede-desligada.mp4` | §5.2 / §8.1 |
| 11 | Configuration | Copy `pin.7z` + `TOMWare.7z` (Drive → host → VM) | `11-config-copia-pin-tomware-para-vm.mp4` | §4.1 / §8.1 |
| 12 | Execution | Example: **benign** sample + **`-dm`** countermeasure | `12-execucao-amostra-benigna-dm.mp4` | §5 / §8.1–§8.2 |
| 13 | Results | Collect CSV/JSON under `Resultados\benchmarks\` (+ copy to host) | `13-coleta-resultados-benchmark.mp4` | §8.2–§8.3 |

Naming convention: `NN-phase-topic.mp4` (lexicographic order = watch order). Items **01–05** may ship a sidecar `.srt`; **06–13** have burned-in subtitles.

---

# 2. Artifact badges considered

Badges from the SBSeg **Artifact Technical Committee (CTA)** ([official guidance](https://doc-artefatos.github.io/sbseg2026/)). This artifact **competes for all four**:

| Badge | Criterion (CTA summary) | How this repository addresses it |
|-------|-------------------------|----------------------------------|
| **Available (SeloD)** | Code/data in a stable repository with a minimal README | Public GitHub; this README; corpus in `samples/`; [Installers](https://drive.google.com/drive/folders/18bq-fFzjVcBa1-KuJIoL5KAmS_AHkAtB?usp=sharing) and playlist on Drive; evidence under `Resultados/evidencias_VM/` |
| **Functional (SeloF)** | Runnable artifact; deps, environment, install, and minimal example | §3.5 / §4 (deps and versions), §6 (install), §7 (minimal test with apps in `Resultados/Apps-Teste/`) |
| **Sustainable (SeloS)** | Modular, readable code mapped to paper claims | `TOMWare/` + `scripts/` layout; knobs `-dd/-dp/-de/-dm/-do`; diagram §3.3; evidence under `Resultados/` |
| **Reproducible (SeloR)** | Reproduce the main paper claims | §8 (VM/snapshot protocol, scripts, corpus); evidence under `Resultados/evidencias_VM/` (§8.6); playlist §1.4 as a flow demo |

Base work: SBSeg 2025 (TOMWare). Current extension (**TOMWare.M**, SBSeg 2026 Tools Fair): **AntiDebug** (`-dd`) and **ProcessEnum** (`-dp`) modules.

---

# 3. Basic information

## 3.1 Introduction to execution and experiments

Context-aware malware can detect Intel Pin via: debugging indicators, process enumeration (`pin.exe`), `PIN_*` environment variables, in-memory signatures, and timing discrepancies (overhead). TOMWare.M masks these surfaces to enable more transparent dynamic analysis.

Experiments in this repository have two goals:

1. **Validate functionality** — show that each module reduces the corresponding indicator on the test application (controlled oracle).
2. **Assess impact** — record wall-clock execution times under Pin **without** and **with** the countermeasure (`Result` field), including on real samples.

> **Isolated environment:** malware experiments must run **only in a VM**, restored from a clean snapshot after each sample.

> **Benign binaries:** test apps and legitimate tools may run on the host, without disabling antivirus, to validate the installation.

## 3.2 Main features

The architecture distinguishes **modules** (wrappers activated by command-line parameters) from **countermeasures** (mechanisms that mask a detection surface). The names are **distinct**: the module is the wrapper; the countermeasure is the mechanism it triggers.

```text
Parameters (-da -dd -de -dm -do -dp)
        │
        ▼
 Instrumentation ──► Modules (wrappers) ──► Countermeasures
                           AntiDeb                    AntiDebug
                           ProcessE                   ProcessEnum
                           SanitizePin                SanitizePinEnvVars
                           InstMem                    InstMemcmpMask
                           SkewM                      SkewMask
```

| Parameter | Module (wrapper) | Countermeasure triggered | Mechanism (implementation) |
|-----------|------------------|--------------------------|----------------------------|
| `-dd` | **AntiDeb** | **AntiDebug** | PEB: `BeingDebugged`, `NtGlobalFlag` (`AntiDebugMask.cpp`) |
| `-dp` | **ProcessE** | **ProcessEnum** | Filter on `Process32*` / `Module32*` / `GetModuleHandle*` |
| `-de` | **SanitizePin** | **SanitizePinEnvVars** | Sanitize the PEB environment block (`PIN_*`) |
| `-dm` | **InstMem** | **InstMemcmpMask** | `memcmp*` wrappers + **Signatures** (`-sf`) |
| `-do` | **SkewM** | **SkewMask** | Timing hooks + **Calibrate Mask** (Sleep/QPC…) |
| `-da` | *(all modules)* | all five countermeasures | Equivalent to `-de -dm -do -dd -dp` (**does not** include `-go`) |

**Auxiliary knobs**

| Knob | Description |
|------|-------------|
| `-sf PATH` | Extra signatures for **InstMem** / **InstMemcmpMask** (default: `config/signatures.txt`) |
| `-q` | Quiet mode (suppresses informational logs) |
| `-me N` | Exception limit before abort (`0` = unlimited) |
| `-go` | **Artificial** overhead — demos with `TestOverhead.exe` only (outside `-da`) |
| `-gdb` | Simulate PEB debug indicators — baseline demo for **AntiDeb** |

> **Modules** are complementary and selectively activatable via **parameters**, without rebuilding. Current support: **native 64-bit PE** (and x86 builds depending on configuration); no direct support for .NET/Java/scripts.

## 3.3 Architecture

<p align="center">
  <img src="imgs/tomware-fluxo-execucao-23072026.png" alt="TOMWare.M execution flow diagram" width="90%">
</p>

**Reading the diagram (execution flow)**

The figure organizes the pintool lifecycle into three phases, aligned with `TOMWare.cpp` / `Instrumentation.cpp` and the countermeasure sources:

1. **Initialization** — `PIN_Init` + `InitInstrumentation()` reads the **parameters** (`-dd`, `-dp`, `-de`, `-dm`, `-do`; `-da` enables all) and wires the matching **modules/countermeasures**; then **activates hooks and wrappers** (`IMG_AddInstrumentFunction`, RTN replace, image callbacks).
2. **Active execution and interception** — the **analyzed application** makes calls; the central band of **modular countermeasures** returns masked/filtered data; underneath, the OS/DBI layer implements, among others:
   - **(1) Process-list filtering** — **ProcessEnum** hides `pin.exe` / Pin artifacts in `Process32*` / `Module32*` / `GetModuleHandle*`.
   - **(2) Memory masking** — **InstMemcmpMask** (`memcmp*` wrappers + **Signatures** `-sf`) avoids hits on Pin strings/modules.
   - **(3) Skew compensation** — **SkewMask** measures accumulated overhead and compensates timing queries (Sleep/QPC…).
   - In parallel (not detailed in panels 1–3, but active when enabled): **AntiDebug** and **SanitizePinEnvVars** act mainly on the **PEB** (`BeingDebugged` / `NtGlobalFlag`; `PIN_*` variables).
3. **Finalization** — end of the Pin run; **data collection and reporting** (`Result`: outcome, time, output) come from the **evaluation harness** (`scripts/run-baseline-dm-one.ps1` and related), not from a generator embedded in the DLL.

| Parameter | Countermeasure in the flow | Implementation |
|-----------|----------------------------|----------------|
| `-de` | SanitizePinEnvVars | `SanitizePinEnvVars.cpp` |
| `-dp` | ProcessEnum | `ProcessEnumMask.cpp` |
| `-dd` | AntiDebug | `AntiDebugMask.cpp` |
| `-dm` | InstMemcmpMask | InstMemcmp* + `config/signatures.txt` |
| `-do` | SkewMask | `SkewMask.cpp` (timing calibration) |
| `-da` | all five | equivalent to `-de -dm -do -dd -dp` |

| Component | Role | Location |
|-----------|------|----------|
| **Main / TOMWare.M** | `PIN_Init` → start instrumentation | `TOMWare/TOMWare.cpp` |
| **Instrumentation** | Parse parameters and register hooks | `TOMWare/Instrumentation.cpp` |
| **Countermeasures** | Selective masking per surface | sources above |
| **Test apps** | Functional oracles (console evidence) | `Resultados/Apps-Teste/` |
| **Harness** | Experiment `Result` / CSV / JSON report | `scripts/` |

**Consistency with the code (verified):** parameter→init mapping matches `InitInstrumentation()`; ProcessEnum / InstMemcmpMask / SkewMask match panels (1)–(3); AntiDebug and SanitizePinEnvVars exist and are enabled by `-dd`/`-de`, though the figure emphasizes them more at initialization than in the lower panels. The **Result Report** block corresponds to the benchmark protocol (§3.4 / §8), not to an internal pintool module.

Equivalent Mermaid diagram (flow): `imgs/tomware-architecture-current.mmd`.  
Earlier structural figure (modules → countermeasures): `imgs/tomware_pintool_20072026.png`.  
Annotated variant (PEB / Signatures / Calibrate): `imgs/tomware-architecture-annotated.png`.

## 3.4 How execution is structured

Each experiment run follows **two stages**:

| Stage | Target | Goal |
|-------|--------|------|
| **[1] Test app** | `TestAntiDebug.exe`, `TestProcessEnum.exe`, … | Functional evidence on the console (`Resumo` / alerts box) |
| **[2] Real sample** | `malwares\infected\<SHA256>.exe` | Exercise the sample under Pin ± countermeasure; time in the `Result` field |

Comparison protocol:

1. **Native** (behavioral reference, no Pin).
2. **Pin + TOMWare without the countermeasure** (baseline — indicator appears).
3. **Pin + TOMWare with the countermeasure** (indicator masked).

Recommended script for side-by-side output:

```powershell
.\scripts\run-baseline-dm-one.cmd <SHA256> <de|dm|do|dd|dp|da>
```

> **Note (ProcessEnum / timing):** effectiveness of the **ProcessEnum** countermeasure (**ProcessE** module, `-dp`) is shown by the test-app box (`pin.exe : N → 0`). If the real sample reaches `outcome=timeout`, wall-clock time **must not** be treated as an effectiveness metric for that countermeasure.

## 3.5 Recommended environment

| Layer | Suggested specification |
|-------|-------------------------|
| **Host** | CPU with VT-x/AMD-V; RAM ≥ 16 GB; SSD |
| **Hypervisor** | VMware Workstation / VirtualBox 7.x |
| **VM (guest)** | Windows 10/11 x64; ≥ 4 vCPU; 6–8 GB RAM; Host-only or disconnected network during malware |
| **Snapshot** | Restore a clean snapshot **after each sample** |

> To validate the install only, use the minimal test (§7) on the host with the test apps — **no** malware.

---

# 4. Dependencies

## 4.1 Runtime

* **Intel Pin** 3.28 (x64, MSVC): [official download](https://software.intel.com/sites/landingpage/pintool/downloads/pin-3.28-98749-g6643ecee5-msvc-windows.zip) — repository `pin/` folder (when provided) or a local install.
* **TOMWare.dll** — `x64\Release\TOMWare.dll` after building.

## 4.2 Build (Windows host)

| Tool | Version / note |
|------|----------------|
| Visual Studio 2019 or 2022 | *Desktop development with C++* workload |
| Toolset | **v142** (required, including on VS 2022) |
| Windows 10 SDK | ≥ 10.0.19041 |
| Intel Pin | 3.28 x64 **MSVC** (not Clang) |

## 4.3 VM

| Tool | Use |
|------|-----|
| VMware / VirtualBox | Isolation and snapshots |
| 7-Zip (optional) | Extract password-protected samples |

## 4.4 Installer package (Google Drive)

To ease reproduction, environment installers are collected in the shared folder:

**[TOMWare Installers (Google Drive)](https://drive.google.com/drive/folders/18bq-fFzjVcBa1-KuJIoL5KAmS_AHkAtB?usp=sharing)**

Drive is a **mirror** of the official sites (Git, Microsoft, 7-Zip, Broadcom/VMware, Intel Pin). Prefer official pages when possible; use Drive to set up the environment faster.

### Contents of the `Instaladores` folder

| # | Drive file | What it is | Where to use | Note |
|---|------------|------------|--------------|------|
| 1 | `7z2602-x64.exe` | 7-Zip (x64) | **Host** and **VM** | Extracts `.7z` / `.zip` (`pin.7z`, `TOMWare.7z`, samples) |
| 2 | `Git-*-64-bit.exe` | Git for Windows | **Host** (and VM if cloning) | Needed for `git clone` of the repository |
| 3 | `VisualStudioSetup.exe` | Visual Studio Installer | **Host** (build) | C++ workload + **v142** toolset (§4.2 / §6.1) |
| 4 | `VMware-Workstation-Full-*.exe` | VMware Workstation | **Host** | Hypervisor for the experiment VM (§3.5) |
| 5 | `Windows.iso` | Windows **x64** ISO | **Host** → create VM | **Use this** for Pin/TOMWare.M (Intel/AMD) |
| 6 | `MediaCreationTool_22H2.exe` | Media Creation Tool (Win 10 22H2) | **Host** (optional) | Official alternative to download/generate an x64 ISO |
| 7 | `Win11_25H2_*_Arm64.iso` | Windows 11 **Arm64** ISO | — | **Do not use** with Pin 3.28 MSVC x64 / TOMWare.M |
| 8 | `pin.7z` | Intel Pin 3.28 (MSVC x64) | Extract on the VM (or host) under `C:\TOMWare\pin\` | Must contain `pin.exe`, `intel64\`, etc. |
| 9 | `TOMWare.7z` | TOMWare code / artifact | Extract on the VM under `C:\TOMWare\` | Includes scripts, `TOMWare.dll` (if pre-built), test apps |
| 10 | `TOMware_pin_samples_benign.7z` | (Optional) packed benign set | Extract on the VM under `malwares\benign\` | Prefer `samples/benign/` from the repository (§4.5) |

> **Arm64:** the `Win11_*_Arm64.iso` is only for ARM machines. For the experiments in this README, the VM must be **Windows 10/11 x64**. Use `Windows.iso` (or an x64 ISO from the Media Creation Tool).

### Correct installation sequence

Order aligned with the playlist (§1.4) and the host → VM flow:

| Step | Where | Action | File(s) |
|-----:|-------|--------|---------|
| 1 | Host | Install **7-Zip** | `7z2602-x64.exe` |
| 2 | Host | Install **Git** | `Git-*-64-bit.exe` |
| 3 | Host | Install **Visual Studio** (C++ + **v142**) | `VisualStudioSetup.exe` |
| 4 | Host | Install **VMware Workstation** | `VMware-Workstation-Full-*.exe` |
| 5 | Host | Create VM with **x64** ISO (not Arm64) | `Windows.iso` (or MCT → x64 ISO) |
| 6 | VM | (Optional) install 7-Zip / Git in the guest | same `.exe` files |
| 7 | VM | Extract **Pin** under `C:\TOMWare\pin\` | `pin.7z` |
| 8 | VM | Extract **TOMWare** under `C:\TOMWare\` | `TOMWare.7z` |
| 9 | VM | Prepare samples | Copy/extract from `samples/` → `malwares\benign\` and `malwares\infected\` (§4.5) |
| 10 | VM | Before running samples: network / Internet / AV / firewall **disabled** | — (§5 / §8.1) |

Pintool build (if `x64\Release\TOMWare.dll` is not already in the package): §6.1 on the **host** or on a VM with VS installed.

Videos: download/install of items 1–5 → playlist §1.4 (01–09); copy Pin/TOMWare → item **11**; benign run → **12**; collection → **13**.

## 4.5 Experiment samples (`samples/`)

Samples used in the tests (**benign** and **infected**) are distributed **in the repository**, under:

```text
samples/
├── benign/      ← <SHA256>.exe
└── infected/    ← <SHA256>.zip  (+ password.txt)
```

> **Why not Google Drive?** Public sharing of files classified as malware on Drive violates the platform policy and gets blocked. Therefore the corpus is versioned under `samples/` (academic use / Tools Fair).

| Repo folder | Destination on the VM | Format | Use |
|-------------|----------------------|--------|-----|
| `samples/benign/` | `C:\TOMWare\malwares\benign\<SHA256>.exe` | `.exe` | Benign corpus (`-SampleType benign`) |
| `samples/infected/` | `C:\TOMWare\malwares\infected\<SHA256>.exe` | `.zip` → extract `.exe` | Infected corpus (script default) |

**Infected samples:** ZIPs are password-protected. The password is in `samples/infected/password.txt` (value: `infected`). Extract with 7-Zip and keep/rename the executable as `<SHA256>.exe` at the destination.

Example (on the VM, after cloning/copying the repo to `C:\TOMWare`):

```powershell
New-Item -ItemType Directory -Force -Path C:\TOMWare\malwares\benign, C:\TOMWare\malwares\infected | Out-Null
Copy-Item C:\TOMWare\samples\benign\*.exe C:\TOMWare\malwares\benign\ -Force
# Extract each ZIP under samples\infected\ with password "infected" into malwares\infected\
# (7-Zip GUI or: 7z x -pinfected file.zip -oC:\TOMWare\malwares\infected\)
```

> **Security:** prepare and run infected samples **only in the VM**, with network/AV/firewall disabled (§5). Do not run them on the host.

---

# 5. Security

TOMWare.M **does not contain malicious code** — it is a C/C++ pintool that masks Pin traces. **Risk comes from the real samples** used in the experiments.

## 5.1 Risk vectors

| Vector | Description |
|--------|-------------|
| Sample execution | VM escape may infect the host |
| Network | Payload download / exfiltration |
| Shared folders / clipboard | Escape channel to the host |

## 5.2 Mandatory measures

1. Do not run real samples on the host.
2. Dedicated VM; network disabled or Host-only during execution.
3. Clean snapshot; restore after each sample.
4. Disable shared folders/clipboard while malware runs; enable them only to copy logs **before** restoring.
5. Test apps under `Resultados/Apps-Teste/` are benign and may run on the host.

## 5.3 Legal notice

Samples and instructions are intended for **academic purposes**. The authors are not liable for damage from misuse or use outside a controlled environment.

---

# 6. Installation

## 6.1 Build (optional, if `TOMWare.dll` does not already exist)

### 6.1.1 Get the code

```powershell
git clone https://github.com/TOMWare-analises/TOMWare.git
cd TOMWare
```

### 6.1.2 Dependencies

1. Visual Studio with toolset **v142**.
2. Windows SDK ≥ 10.0.19041.
3. Pin 3.28 MSVC extracted under `pin\` (direct contents: `pin.exe`, `intel64\`, etc.).

Installers (Git, VS, 7-Zip, VMware, Pin, TOMWare) are also on [Google Drive TOMWare](https://drive.google.com/drive/folders/18bq-fFzjVcBa1-KuJIoL5KAmS_AHkAtB?usp=sharing) — see §4.4.

### 6.1.3 Build

1. Open `TOMWare.sln`.
2. If VS offers a toolset upgrade → **No** (keep v142).
3. Configuration **`Release | x64`**.
4. Build (**Ctrl+Shift+B**).

Expected output:

```text
x64\Release\TOMWare.dll
```

<details>
<summary>Screenshots — building with VS 2022</summary>

<p align="center"><img src="imgs/01.png" alt="C++ workload" width="75%"></p>
<p align="center"><img src="imgs/02.png" alt="Toolset v142" width="75%"></p>
<p align="center"><img src="imgs/04.png" alt="Solution open" width="75%"></p>
<p align="center"><img src="imgs/10.png" alt="Release x64" width="75%"></p>
<p align="center"><img src="imgs/12.png" alt="Build OK" width="75%"></p>
<p align="center"><img src="imgs/13.png" alt="TOMWare.dll" width="75%"></p>

</details>

**MSBuild (command line):**

```powershell
& "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" `
    TOMWare.sln /p:Configuration=Release /p:Platform=x64
```

## 6.2 Execution

### 6.2.1 Basic syntax

```powershell
.\pin\pin.exe -t .\x64\Release\TOMWare.dll [KNOBS] -- <target.exe>
```

Examples:

```powershell
# AntiDebug
.\pin\pin.exe -t .\x64\Release\TOMWare.dll -dd -q -- .\Resultados\Apps-Teste\TestAntiDebug.exe

# ProcessEnum
.\pin\pin.exe -t .\x64\Release\TOMWare.dll -dp -q -- .\Resultados\Apps-Teste\TestProcessEnum.exe

# All countermeasures + follow child (real sample)
.\scripts\run-sample.ps1 -Sample C:\TOMWare\malwares\infected\<SHA256>.exe -DefendAll -Quiet -FollowChild
```

---

# 7. Minimal test

Validates the installation **without malware**, using test apps on the host.

## 7.1 Prerequisites

* Windows 10/11 x64
* `pin\` and `x64\Release\TOMWare.dll`
* `Resultados\Apps-Teste\TestGetEnvironments.exe` (or another app from the table)

## 7.2 Step by step

```powershell
cd C:\path\to\TOMWare

# (1) Without Pin — reference
.\Resultados\Apps-Teste\TestGetEnvironments.exe

# (2) Pin without countermeasure — should alert / detect traces
.\pin\pin.exe -t .\x64\Release\TOMWare.dll -q -- .\Resultados\Apps-Teste\TestGetEnvironments.exe

# (3) Pin with countermeasure — indicator masked
.\pin\pin.exe -t .\x64\Release\TOMWare.dll -de -q -- .\Resultados\Apps-Teste\TestGetEnvironments.exe
```

| Test app | Knob |
|----------|------|
| `TestGetEnvironments.exe` | `-de` |
| `TestMemoryScan.exe` | `-dm` |
| `TestOverhead.exe` | `-do` (+ `-go` in demos) |
| `TestAntiDebug.exe` | `-dd` |
| `TestProcessEnum.exe` | `-dp` |

Via wrapper:

```powershell
.\scripts\run-sample.ps1 -Sample .\Resultados\Apps-Teste\TestProcessEnum.exe -ProcessEnumDefend -Quiet
.\scripts\run-sample.ps1 -Sample .\Resultados\Apps-Teste\TestAntiDebug.exe -DebugDefend -Quiet
```

---

# 8. Experiments

## 8.1 Prepare the VM

1. Create a Windows 10/11 x64 VM (clean snapshot).
2. Copy the repository (or artifacts) to `C:\TOMWare`.
3. Build or copy `x64\Release\TOMWare.dll`.
4. Prepare samples from `samples/` (§4.5):
   - `C:\TOMWare\malwares\benign\<SHA256>.exe`
   - `C:\TOMWare\malwares\infected\<SHA256>.exe` (extract the `.zip` files with the password in `samples/infected/password.txt`)
5. Disable network / Host-only; disable AV and firewall if the paper protocol requires it.

Video demo: §1.4 items **10–12** (network off → copy Pin/TOMWare → benign `-dm` run).

## 8.2 Reproduce baseline vs countermeasure comparison

```powershell
# Prefer a single line (avoid "^" in CMD — avoids the "More?" prompt)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\TOMWare\scripts\run-baseline-dm-one.ps1" `
  -Sha256 "36685efcf34c7a7a6f6dd2e48199e4700b5ab8fe3945a50297703dd8daced74f" `
  -Countermeasure dd

# Other modules
.\scripts\run-baseline-dm-one.cmd a0aeb837 dp
.\scripts\run-baseline-dm-one.cmd 17c79863 dm
.\scripts\run-baseline-dm-one.cmd 36685efc da -Loop1000

# Benign sample: 10 independent runs for each countermeasure
.\scripts\run-baseline-dm-one.ps1 `
  -Sha256 "4D6937E8D7D58CD1D9224A11E48549A08505836EFABD6FED17A67D42466265BB" `
  -SampleType benign -AllCountermeasures
```

The script prints, on the same console:

* sample path (hash);
* Pin command for the test app;
* evidence box (baseline vs `-xx`);
* `Result` line for the real sample.

## 8.3 Corpus / benchmark

```powershell
.\scripts\benchmark-poc.ps1
.\scripts\benchmark-corpus.ps1 -SamplesDir C:\TOMWare\malwares\infected -FollowChild -TimeoutSeconds 120
```

Typical outputs: `Resultados\Avaliacao\`, `Resultados\baseline-<cm>-<hash8>.log`.

With `-Repeat N`, each baseline and countermeasure starts as an independent
process. Order alternates per round to reduce warm-up bias.
Detailed reports are written to:

* `Resultados\benchmarks\benchmark-<type>-<cm>-<hash8>-<date>.csv` — one row per run,
  including status, response, and a functional-evidence summary;
* `Resultados\benchmarks\benchmark-<type>-<cm>-<hash8>-<date>.json` — runs, full
  functional evidence, and performance evaluation with mean, median, p95, standard
  deviation, min, max, and outcome counts;
* `Resultados\benchmarks\benchmark-<type>-all-<hash8>-<date>.csv|json` — automatic
  consolidation of all five countermeasures when using `-AllCountermeasures`.

`-AllCountermeasures` runs `de`, `dm`, `do`, `dd`, and `dp` sequentially.
It does not include `da`, because `da` measures all protections enabled at once,
not each countermeasure in isolation.

Each report answers separately:

* **Functional:** “Did the countermeasure hide Pin?” (`PASS`, `FAIL`, or `INCONCLUSIVE`);
* **Performance:** “What was the performance impact?” (`VALID` or `INCONCLUSIVE`).

A functional result may be `PASS` even when performance is inconclusive:
the two conclusions use different evidence.

By default, each sample gets a 10-second observation window
(`-SampleObservationSeconds 10`). Applications that exit naturally keep
outcome `complete`; GUI or persistent applications are terminated at the end
of the window and receive outcome `observed`. During the window, the benchmark
collects accumulated CPU, equivalent single-core utilization, average/peak
working-set memory, and peak private memory for Pin and the sample. Persistent
applications can therefore still get a valid paired **resource** comparison,
even when total wall-time comparison is invalid because duration was capped.

These metrics represent startup plus the observed state during the window.
They do not measure latency of a specific GUI action; that would require
automating the same action in every run.

## 8.4 Timing measurement (loop apps)

```powershell
Measure-Command {
  .\pin\pin.exe -t .\x64\Release\TOMWare.dll -dm -q -- `
    .\Resultados\Apps-Teste\Loop_X_1000\TestMemoryScan.exe
}
```

## 8.5 Quick interpretation of results

| Observation | Interpretation |
|-------------|----------------|
| Baseline: alert / count > 0; with knob: `OK` / zeros | Countermeasure is **functional** on the tested surface |
| `Result … outcome=complete` | Sample time may enter quantitative comparison |
| `Result … outcome=timeout` | Sample did not finish within the limit — **do not** use as a valid effectiveness time (common with `-dp`) |

## 8.6 Published result evidence

Besides CSV/JSON generated on the VM under `Resultados\benchmarks\` (§8.3 / video 13), the repository publishes consolidated run evidence under:

```text
Resultados/evidencias_VM/
├── benign/          ← per sample (hash) + consolidated benign corpus
├── malign/          ← per sample (hash) + consolidated infected corpus
└── comparativo/     ← benign vs infected comparison
```

| Content | Location |
|---------|----------|
| Per-sample report (PDF) | `evidencias_VM/benign/<SHA256>/` and `evidencias_VM/malign/<SHA256>/` |
| Benign consolidated (17 samples) | `evidencias_VM/benign/TOMWare-corpus-benigno-17-amostras.pdf` (+ CSV/JSON) |
| Infected consolidated (14 samples) | `evidencias_VM/malign/TOMWare-corpus-maligno-14-amostras.pdf` (+ CSV/JSON) |
| Benign × infected comparison | `evidencias_VM/comparativo/TOMWare-comparativo-benigno-vs-maligno.pdf` (+ CSV) |
| Raw outputs of a local run | `Resultados\benchmarks\benchmark-<type>-<cm>-<hash8>-<date>.{csv,json}` |

Samples used in these experiments: repository folder `samples/` (§4.5).

---

# 9. License

This project is distributed for academic and research purposes. See [`LICENSE`](LICENSE) at the repository root.

**Intel Pin** has its own license (see `pin/licensing/`).

**Suggested citation (TOMWare.M / SBSeg 2026 Tools Fair):**

```text
TOMWare.M: A Tool for Mitigating Anti-Instrumentation Techniques
in DBI Environments — Tools Fair, SBSeg 2026.
https://github.com/TOMWare-analises/TOMWare
```

---

## Quick reference

```text
TOMWare.M — Transparency and Overhead Measurement for Malware
Intel Pin 3.28 · Windows x64 · MSVC v142
Knobs: -dd -dp -de -dm -do | -da | -sf -q -go -gdb -me
```
