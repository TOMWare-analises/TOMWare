# Esquema do Corpus Experimental (`corpus.csv`)

O arquivo `corpus.csv` documenta individualmente cada executável avaliado pela infraestrutura TOMWare.M.
Nenhum valor é inventado. Amostras sem confirmação empírica de técnicas ativas têm `targeted_evasion` anotado como `not_observed` ou `unverified`.

## Campos Obrigatórios (Seção 7)

| Campo | Tipo | Valores Permitidos / Formato | Descrição |
|---|---|---|---|
| `sample_id` | String | Ex.: `BEN_01`, `MAL_01` | Identificador único e opaco no experimento |
| `sha256` | String | 64 caracteres hexadecimais (minúsculas) | Hash criptográfico verificado do executável |
| `file_name` | String | Ex.: `calc.exe`, `<sha256>.exe` | Nome do arquivo em disco |
| `group` | Enum | `benign` ou `malicious` | Grupo taxonômico |
| `source` | String | Ex.: `Windows_System32`, `DBI_Log_Corpus` | Proveniência do arquivo |
| `acquisition_date` | String | `YYYY-MM-DD` | Data de aquisição / inclusão no corpus |
| `family_or_product` | String | Nome do software ou família VT | Ex.: `Calculator`, `Trojan.Generic` |
| `classification_source` | String | Ex.: `Vendor_Microsoft`, `VirusTotal_Consensus` | Fonte da classificação |
| `malware_type` | String | Ex.: `none`, `backdoor`, `trojan`, `utility` | Tipo do executável |
| `architecture` | Enum | `x64` ou `x86` | Arquitetura do PE |
| `file_size_bytes` | Integer | $\ge 0$ | Tamanho real do arquivo em bytes |
| `digital_signature` | Enum | `signed_valid`, `unsigned`, `invalid` | Status da assinatura digital |
| `packer` | String | Ex.: `none`, `upx`, `unknown` | Packer detectado |
| `protector` | String | Ex.: `none`, `themida`, `unknown` | Protetor de código detectado |
| `execution_profile` | Enum | `short_lived` ou `persistent` | Perfil temporal a priori |
| `expected_behavior` | String | Descrição sucinta | Ex.: `completes_calculation`, `service_loop` |
| `command_line` | String | Argumentos adicionais se houver | Argumentos de execução (default: vazio) |
| `input_set_id` | String | Ex.: `none`, `input_01` | Identificador de arquivos de entrada requeridos |
| `targeted_evasion` | String | Ex.: `none`, `Sleep_QPC`, `unverified` | Técnica evasiva esperada pelo design |
| `notes` | String | Texto livre | Observações adicionais |
| `included` | Boolean | `true` ou `false` | Se incluído na campanha ativa |
| `exclusion_reason` | String | Ex.: `none`, `corrupted_pe`, `missing_file` | Motivo de exclusão quando `included=false` |

## Regras de Validação Automática
1. `sha256` recalculado antes de cada campanha; se divergir do arquivo físico, o pipeline aborta a amostra.
2. Não expor binários maliciosos desempacotados no repositório público — manter apenas identificadores e hashes.
3. Não classificar técnica evasiva como presente no malware sem evidência por amostra.
