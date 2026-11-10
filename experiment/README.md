# TOMWare.M — reproducible experimental infrastructure

This directory is the measured evidence. Tables live in `results/`. How to
reproduce: repository-root README, **Reproduce** section. Do **not** mix the
two campaigns.

The layout measures, in an auditable way and without outcome-based selection,
the cost and effects of the five TOMWare.M countermeasures, separating: Intel
Pin cost, empty Pintool cost, TOMWare.M infrastructure (modules off), each
countermeasure, and joint activation.

Two campaigns in this tree — **do not mix cells**:

| Campaign | Samples | Window | Tables | DLL |
|----------|---------|--------|--------|-----|
| JCVHT 31-PE | 17 benign + 14 infected | 10 s | `experiment/results/corpus/` and `oracles/` | `4BBC6270` |
| Access 9 000 | 100 PE (50+50) × 9 × 10 | 120 s short / 60 s persistent | `experiment/results/campaign/corpus_aligned_10k/` | `4BBC6270` |

Access identities (SHA-256 + manifesto fields): `experiment/corpus/access_100_hashes.csv`.
Full catalog: `experiment/corpus/corpus.csv`. Software identity: root README,
**Reproduce**. Do not change `SkewMask.cpp`.

## Design decisions

1. **Isolation:** snapshot restore per **block** (sample + repetition),
   orchestrated **on the host** (`experiment/scripts/host/Run-HostCampaign.ps1`).
   The VM is disposable; JSON files are copied to the host before each revert.
   Do not run the campaign from an interactive guest window alone.
2. **Stack:** **runner + collectors in PowerShell** (on the VM; reuses
   `scripts/lib/TomwareBenchmark.ps1`); **plan + validators + statistics +
   figures in Python** (host). Split: PowerShell launches/collects; Python
   plans/validates/analyzes.
3. **Corpus:** `experiment/corpus/corpus.csv` is the catalog of the **100 PE**
   in the 9 000-run campaign. The JCVHT 17+14 pack is a different cut (10 s);
   do not substitute one for the other.
4. **PIN condition:** the probe tries `pin.exe` with no tool and records the
   error; if invalid, `EMPTY` is the minimum Pin baseline (⇒ 9 conditions).
   The decision is stored in the campaign manifest.

Nothing is invented: corpus attributes exist only if observed. Missing
family/packer/sandbox stays `unknown` (no inference). Commands are not
hardcoded: the plan comes from `protocol/conditions.csv` +
`config/experiment.config.json`. Oracles are matched (same `sample_id` in
native vs TOMWare). Metrics count only when valid (`protocol/validity_rules.md`).
SHA-256 is recorded for Pin, DLLs, scripts, configs, PEs, stdout, stderr, JSON,
and CSV. Infected samples run only on an isolated VM; do not execute
`samples/infected/` on a networked host.

## Layers

| Role | Technology | Path |
|------|------------|------|
| Randomized block plan | Python | `experiment/scripts/planner/` |
| Runner + collectors | PowerShell | `experiment/scripts/runner/`, `experiment/scripts/collectors/` |
| Validators | Python | `experiment/scripts/validators/` |
| Statistics + figures/tables | Python | `experiment/scripts/analysis/` |
| Unit and integration tests | Python | `experiment/scripts/tests/` |
| Internal module counters | C++ (`TOMWare.dll`) | `TOMWare/*.cpp` (optional instrumentation) |
| Empty Pintool | C++ | `EmptyPinTool/` (repository root) |

## Flow

```
corpus.csv + conditions.csv + experiment.config.json
        │  (Python planner, recorded seed)
        ▼
campaigns/<id>/execution_plan.csv  ──►  PowerShell runner (VM)
        │                                     │ per-run collection
        │                                     ▼
        │                         raw/runs/*.json  (atomic)  + resources/ behavior/ module_events/ stdout/ stderr/
        ▼                                     │
Python validators  ◄──────────────────────────┘
        │  (explicit failure on a critical rule)
        ▼
processed/*.csv  ──►  Python analysis  ──►  reports/tables + figures
```

## How to run (summary)

1. Fill `corpus/corpus.csv` (schema in `corpus.schema.md`).
2. Guest: Pin 3.28.98749, campaign `TOMWare.dll` `4BBC6270`, `EmptyPinTool.dll`.
3. `python experiment/scripts/generate_build_manifest.py`
4. `python experiment/scripts/planner/generate_plan.py --campaign-id <id>`
5. On the VM: `.\experiment\scripts\runner\Run-Campaign.ps1 -CampaignId <id>`
6. `python experiment/scripts/validators/validate_campaign.py --campaign-id <id>`
7. `python experiment/scripts/analysis/consolidate_and_analyze.py --campaign-id <id>`

9 000-run campaign: `experiment/scripts/host/Run-HostCampaign.ps1`.
Do not overwrite `results/campaign/` without a new `campaign_id`.

## Repository layout (what is what)

`TOMWare\TOMWare` is **not** a copy-paste error: the outer folder is the
repository root (Visual Studio solution + Pin + `experiment/`); the inner
folder is the Pintool C++ sources, as the `.sln` expects.

```
TOMWare/                           ← git root (RepoRoot / C:\TOMWare on the VM)
  TOMWare/                         ← Pintool C++ sources (.vcxproj); not a second clone
  EmptyPinTool/  FidelityProbe/
  pin/                             ← Intel Pin 3.28
  x64/Release/                     ← compiled DLLs (**not in git**; copy 4BBC6270)
  samples/benign|infected          ← corpus (benign exe; packed malware)
  experiment/                      ← campaign + oracles + measured tables
  Resultados/Apps-Teste/           ← functional oracles (not the paper tables)
  config/signatures.txt
```

The workspace folder `tomware-melhorias/` (zips, submission PDFs, `_archive`)
is **not** part of git. Do not mix it with the repository root.

Experimental infrastructure lives in `experiment/`:

```
experiment/
  config/
    experiment.config.json           # paths, repetitions, timeouts, sampling, seed
  protocol/
    protocol.md                      # full formal experiment design
    conditions.csv                   # condition → command template (no hardcoded command)
    oracle_conditions.csv            # matched pairing of functional oracles
    validity_rules.md                # a priori metric-validity rules
    empty_tool_and_pin_probe.md      # EmptyTool and PIN probe documentation
    randomization_seeds.csv          # persistent seed record per campaign
  corpus/
    corpus.csv                       # samples + metadata (filled, never invented)
    access_100_hashes.csv            # Access 100 SHA-256 + manifesto fields
    corpus.schema.md                 # schema of the 22 attributes
    exclusions.csv                   # justified exclusion record
  environment/
    build_manifest.json              # tool and environment hashes
  schemas/
    run_record.schema.json           # formal JSON schema per run
  campaigns/<campaign_id>/           # plan and manifest (campaign.json, execution_plan.csv)
  results/                           # only place for tables (corpus / oracles / campaign)
    oracles/ctrl_progress/           # TestRecoverWork + 5 Table-9 benigns (not a case study)
  validation/
    scripts/                         # Run-Oracles.ps1, Run-CtrlProgress.ps1
    manuscript/jcvht_revision/       # CURRENT.pdf (article) + REVISION.tex
  scripts/
    planner/                         # generate_plan.py
    runner/                          # Run-Campaign.ps1, Invoke-SingleRun.ps1
    collectors/                      # ProcessCollector.ps1
    validators/                      # validate_campaign.py
    analysis/                        # consolidate_and_analyze.py
    tests/                           # test_planner.py, test_validator.py, test_analysis.py, test_integration_benign.py
    sanitize_ps1_ascii.py            # PowerShell 5.1 compatibility helper
    generate_build_manifest.py       # build-manifest generator
```

Each run writes one JSON file (first to `.tmp`, then an atomic `move`) and one
line in the consolidated index. SHA-256 hashes are produced for executables,
`TOMWare.dll`, `EmptyPinTool.dll`, Pin, configs, scripts, raw traces, and
tables.

Measured tables: `experiment/results/`. How to reproduce: repository-root
README (**Reproduce**). `raw/` and `ev_*` traces are not in git.
