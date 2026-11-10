# Experimental corpus schema (`corpus.csv`)

File `corpus.csv` documents each executable evaluated by the TOMWare.M
infrastructure individually. No value is invented. Samples without empirical
confirmation of active techniques have `targeted_evasion` annotated as
`not_observed` or `unverified`.

## Required fields (Section 7)

| Field | Type | Allowed values / format | Description |
|---|---|---|---|
| `sample_id` | String | E.g. `BEN_01`, `MAL_01` | Unique opaque identifier in the experiment |
| `sha256` | String | 64 lowercase hex characters | Verified cryptographic hash of the executable |
| `file_name` | String | E.g. `calc.exe`, `<sha256>.exe` | On-disk file name |
| `group` | Enum | `benign` or `malicious` | Taxonomic group |
| `source` | String | E.g. `Windows_System32`, `DBI_Log_Corpus` | File provenance |
| `acquisition_date` | String | `YYYY-MM-DD` | Acquisition / inclusion date in the corpus |
| `family_or_product` | String | Software name or VT family | E.g. `Calculator`, `Trojan.Generic` |
| `classification_source` | String | E.g. `Vendor_Microsoft`, `VirusTotal_Consensus` | Classification source |
| `malware_type` | String | E.g. `none`, `backdoor`, `trojan`, `utility` | Executable type |
| `architecture` | Enum | `x64` or `x86` | PE architecture |
| `file_size_bytes` | Integer | $\ge 0$ | Actual file size in bytes |
| `digital_signature` | Enum | `signed_valid`, `unsigned`, `invalid` | Digital-signature status |
| `packer` | String | E.g. `none`, `upx`, `unknown` | Detected packer |
| `protector` | String | E.g. `none`, `themida`, `unknown` | Detected code protector |
| `execution_profile` | Enum | `short_lived` or `persistent` | A priori temporal profile |
| `expected_behavior` | String | Short description | E.g. `completes_calculation`, `service_loop` |
| `command_line` | String | Extra arguments if any | Execution arguments (default: empty) |
| `input_set_id` | String | E.g. `none`, `input_01` | Identifier of required input files |
| `targeted_evasion` | String | E.g. `none`, `Sleep_QPC`, `unverified` | Evasive technique expected by design |
| `notes` | String | Free text | Additional remarks |
| `included` | Boolean | `true` or `false` | Whether included in the active campaign |
| `exclusion_reason` | String | E.g. `none`, `corrupted_pe`, `missing_file` | Exclusion reason when `included=false` |

## Automatic validation rules
1. `sha256` is recomputed before each campaign; if it diverges from the on-disk file, the pipeline aborts that sample.
2. Do not expose unpacked malicious binaries in the public repository — keep identifiers and hashes only.
3. Do not classify an evasive technique as present in the malware without per-sample evidence.
