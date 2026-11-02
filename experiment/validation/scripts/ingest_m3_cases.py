# -*- coding: utf-8 -*-
"""Ingest access_m3_cases (3 SHA x TMW0/TMW_DP/TMW_DO). Never sets identified=true."""
from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path

ROOT = Path(r"d:\MMB\workspace\tomware-melhorias\TOMWare")
ORACLE = ROOT / "experiment" / "results" / "oracles"
MS = ROOT / "experiment" / "validation" / "manuscript" / "ieee_access_ressubmissao"
DOWNLOADS = Path(r"C:\Users\marge\Downloads")
EXPECTED_PIN = "920A730ABAC4E30D13F2ED75C92F0538FB53FD85273C40B64991A89DCE0BB819"
DLL = "4BBC62707EE0B2EF922D4E8659A6392D92814EA0FC74F4682F1187562AE7F0E6"
SAMPLES = ("MAL_08", "MAL_13", "MAL_07")
MODES = ("TMW0", "TMW_DP", "TMW_DO")
PIN_TREE = {"pin.exe", "pinbin.exe", "conhost.exe", "?"}


def find_dir(name: str) -> Path | None:
    for base in (DOWNLOADS / name, ORACLE / name, ORACLE / "guest" / name):
        if base.is_dir() and any(base.rglob("run_meta.json")):
            return base
    return None


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def load_runs(d: Path) -> list[dict]:
    rows = []
    for meta in sorted(d.glob("*/run_meta.json")):
        data = json.loads(meta.read_text(encoding="utf-8-sig"))
        data["run_dir"] = meta.parent.name
        stdout = (meta.parent / "stdout.txt").read_text(encoding="utf-8", errors="replace")
        stderr = (meta.parent / "stderr.txt").read_text(encoding="utf-8", errors="replace")
        blob = stdout + "\n" + stderr
        data["dll_map_failed"] = ("Failure to map DLL" in blob) or ("System error 216" in blob)
        if data["dll_map_failed"]:
            data["validity_note"] = "pin_failed_to_map_dll_win32_216"
        rows.append(data)
    return rows


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def as_int(v, default=0) -> int:
    try:
        if v is None or v == "":
            return default
        return int(v)
    except (TypeError, ValueError):
        return default


def pair_note(base: dict | None, treat: dict | None) -> dict:
    out = {
        "hook_seen": False,
        "result_changed": False,
        "extra_vs_tmw0": False,
        "chain_complete": False,
        "extra_why": "missing_arm",
    }
    if not treat:
        return out
    out["hook_seen"] = bool(treat.get("hook_seen"))
    out["result_changed"] = bool(treat.get("result_changed"))
    if not base:
        out["extra_why"] = "no_tmw0"
        return out
    extra_files = as_int(treat.get("n_new_files")) > as_int(base.get("n_new_files"))
    extra_reg = as_int(treat.get("n_registry_delta")) > as_int(base.get("n_registry_delta"))
    extra_app = as_int(treat.get("n_app_descendants")) > as_int(base.get("n_app_descendants"))
    extra_tcp = as_int(treat.get("n_tcp_established")) > as_int(base.get("n_tcp_established"))
    bits = []
    if extra_files:
        bits.append("files")
    if extra_reg:
        bits.append("registry")
    if extra_app:
        bits.append("app_child")
    if extra_tcp:
        bits.append("tcp")
    out["extra_vs_tmw0"] = bool(bits)
    out["extra_why"] = "|".join(bits) if bits else "no_extra_vs_tmw0"
    out["chain_complete"] = bool(out["hook_seen"] and out["result_changed"] and out["extra_vs_tmw0"])
    return out


def render_awaiting() -> str:
    return """# Resposta item a item — Access (cadeia 1–3 ainda sem guest)

Não enviar à IEEE. Não é o suplemento double-blind. Sem malware. Sem as 9.000.
Citação: git a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3. DLL 4BBC6270. Pin launcher 920A730A.

**Itens 1–3: protocolo pronto, evidência ainda não ingerida.**
Pasta esperada no host: `C:\\Users\\marge\\Downloads\\access_m3_cases`
Depois de copiar, correr `ingest_m3_cases.py`. Até lá, `identified=false`.

## 1. Relacionar malware, verificação e contramedida

**Ainda não demonstrado em runtime.** Nas 9.000, `-mc` esteve desligado. IAT/strings em `identify_summary.csv` não são ramo executado.

Protocolo a priori (não se acrescentam amostras):
| Amostra | SHA-256 | Pista IAT (não é caso) | Braços |
|---|---|---|---|
| MAL_08 | 1693df9d…417b6d38 | Toolhelp + timing | TMW0 / TMW_DP / TMW_DO |
| MAL_13 | 2a2b6b75…ebb9e24 | Toolhelp + timing | TMW0 / TMW_DP / TMW_DO |
| MAL_07 | 153e1147…19800d | SleepEx / QPC / IsDebuggerPresent | TMW0 / TMW_DP / TMW_DO |

N=1, 60 s, DLL 4BBC6270, launcher `pin\\pin.exe` 920A730A, `-mc` ligado, rede desligada, restore `tomware_go` entre modos.
TMW0 (`-q -mc`) não instala os hooks de `-dp`/`-do`; o “chamou a verificação” só pode aparecer em TMW_DP ou TMW_DO.

Isto **não** autoriza escrever que os 100 executáveis usam as cinco checagens.

## 2. Comportamento adicional em casos seleccionados

**Ainda não demonstrado.** r43d é benigno (BEN_28/46/47) e `behavioral_progress_observed=false`. Vivo a 60 s não conta.

O guest compara TMW0 com o knob e regista ficheiros com hash (0 bytes = campo vazio), delta de Run/RunOnce, filhos que não são pin/conhost, TCP estabelecido (deve ser 0 com rede off).
Caso só se: hook + resultado mudou + extra **versus TMW0** no mesmo PE. Sem os três, `identified` continua false.

## 3. Explicar comportamentalmente o SkewMask

**Ainda não demonstrado em malware.** Table 25/r43d não responde isto.

Braço TMW_DO (`-do -q -mc`) nas três SHA. Lê-se `sleep_calls_intercepted`, `time_queries_intercepted`, `corrections_applied`, duração, árvore, hashes, filhos.
Duração maior sob `-do` é custo/espera até haver artefacto extra versus TMW0. Sem chamadas de tempo, o item 3 fica: “SkewMask não foi acionado nestas amostras”.

## 4. Coerência temporal de SkewMask

**Não corrido. Limitação.** Timeouts sob Pin nas esperas concorrentes/sobrepostas/alertáveis continuam inconclusivos. Não se altera `SkewMask.cpp` (invalida Table 6 / N=30). Não se copiam células JCVHT (TickCount 4/10, SleepEx 0/10).

## 5. Pin sem Pintool no corpus

**Não é braço do corpus.** Existe só o controlo técnico guest N=3 em `TestAntiDebug.exe` (launcher 920A730A, 3/3 exit 0, 1900–2963 ms). Isso mostra que o launcher funciona; não dá duração/recursos/desfechos nos 100 PE. Pode permanecer limitação. `campaign.json` `pin_condition_valid=false` não foi invertido.

## 6. Metadados incompletos

**Limitação já declarada.** `corpus.csv`: família `Trojan_Bazaar` / `Backdoor_Bazaar` (rótulo MalwareBazaar, não família VirusTotal); packer/protector `unknown` nos 50 MAL; `targeted_evasion=unverified`. Os três SHA deste protocolo não mudam isso até haver verificação empírica da técnica **em runtime**.

## 7. Comparação experimental externa

**Limitação / trabalho futuro.** Arancino, COBAI e Peekaboo não foram executados. Arancino pede Pin 2.14 e é 32-bit; o corpus Access é 100% x64. A comparação actual é conceptual.

## 8. Critérios de elegibilidade prospectivos

**Limitação já concedida.** Os critérios foram explicados e são independentes da direcção do resultado, mas a recolha das 9.000 foi post hoc. Este protocolo **fixa as três SHA e os braços antes da corrida**. Não substitui uma campanha de confirmação do corpus.

## O que já está atendido (não repetir)

AntiDebug pareado; SkewMask fixed-N 90 tentativas; ICs; corpus 100 PE; 9.000; Module32 (oráculo); rotinas de comparação; modo combinado; referências; tipografia; Figura 1; moderação das conclusões; pin-bare N=3 técnico; árvores r43d (benignas); correcção 22/30.

## Frases proibidas neste fecho

- “os 100 executáveis usam as cinco checagens”
- IAT de MAL_08/13/07 = verificação executada
- TMW_DO / TMW_DP vivo a 60 s = comportamento recuperado
- árvore pin → sample + conhost = progresso
- r43d / BEN_28/46/47 como caso de malware
- `identified=true` sem os quatro elos
- bake-off Arancino
"""


def render_from_runs(rows: list[dict]) -> str:
    by = {(r.get("sample_id"), r.get("mode")): r for r in rows}
    lines = [
        "# Resposta item a item — Access após ingest access_m3_cases",
        "",
        "Não enviar à IEEE. Não é o suplemento double-blind. Sem malware. Sem as 9.000.",
        "Citação: git a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3. DLL 4BBC6270. Pin launcher 920A730A.",
        "",
        f"Corridas ingeridas: {len(rows)}. `identified=false` em todas (o ingest não promove caso).",
        "",
        "## 1. Relacionar malware, verificação e contramedida",
        "",
        "| Amostra | Modo | hook_seen | módulo (contagens) | result_changed | verdict |",
        "|---|---|---|---|---|---|",
    ]
    any_hook = False
    for sid in SAMPLES:
        for mode in MODES:
            r = by.get((sid, mode))
            if not r:
                lines.append(f"| {sid} | {mode} | missing | — | — | missing |")
                continue
            if r.get("dll_map_failed"):
                lines.append(
                    f"| {sid} | {mode} | inconclusive | Pin failed to map DLL (Win32 216) | {r.get('result_changed')} | INVALID_DLL_MAP |"
                )
                continue
            bits = []
            if as_int(r.get("pe_calls_intercepted")):
                bits.append(f"ProcessEnum calls={r.get('pe_calls_intercepted')} filt={r.get('pe_processes_filtered')}")
            if as_int(r.get("pe_modules_examined")):
                bits.append(f"Module32 exam={r.get('pe_modules_examined')} filt={r.get('pe_modules_filtered')}")
            if as_int(r.get("sleep_calls_intercepted")) or as_int(r.get("time_queries_intercepted")):
                bits.append(
                    f"SkewMask sleep={r.get('sleep_calls_intercepted')} qpc={r.get('time_queries_intercepted')} corr={r.get('corrections_applied')}"
                )
            if as_int(r.get("memcmp_intercepted")):
                bits.append(f"Memcmp {r.get('memcmp_intercepted')}")
            mod = "; ".join(bits) if bits else "nenhum contador > 0"
            if r.get("hook_seen"):
                any_hook = True
            lines.append(
                f"| {sid} | {mode} | {r.get('hook_seen')} | {mod} | {r.get('result_changed')} | {r.get('verdict')} |"
            )
    if not any_hook:
        lines.append("")
        lines.append(
            "**Resultado:** nenhum hook válido em TMW_DP/TMW_DO até agora. "
            "Célula com falha de mapa da DLL (Win32 216) é inconclusiva, não é prova de que a amostra não chamou a API. "
            "IAT continua a não ser ramo executado. Não se acrescentam amostras. "
            "Não se escreve que os 100 usam as cinco checagens."
        )
    else:
        lines.append("")
        lines.append(
            "Hook em runtime é o único ‘usou a verificação’. TMW0 com contadores a zero é esperado "
            "(hooks de -dp/-do não instalados). Continua proibido generalizar aos 100 PE."
        )

    lines += ["", "## 2. Comportamento adicional em casos seleccionados", ""]
    lines.append("| Amostra | Knob | extra vs TMW0 | cadeia completa | nota |")
    lines.append("|---|---|---|---|---|")
    any_chain = False
    for sid in SAMPLES:
        base = by.get((sid, "TMW0"))
        for mode in ("TMW_DP", "TMW_DO"):
            p = pair_note(base, by.get((sid, mode)))
            if p["chain_complete"]:
                any_chain = True
            lines.append(
                f"| {sid} | {mode} | {p['extra_vs_tmw0']} | {p['chain_complete']} | {p['extra_why']} |"
            )
    lines.append("")
    if any_chain:
        lines.append(
            "**Candidato a cadeia** (hook + mudança + extra vs TMW0). "
            "`identified` continua false até revisão humana do artefacto (não pin/conhost). "
            "Não reescreve as 9.000."
        )
    else:
        lines.append(
            "**Nenhuma cadeia completa.** Persistência, árvore pin→sample+conhost e vivo a 60 s "
            "não são comportamento adicional. Item 2 permanece aberto / negativo."
        )

    lines += ["", "## 3. Explicar comportamentalmente o SkewMask", ""]
    lines.append("| Amostra | TMW0 ms | TMW_DO ms | sleep | time | corrections | extra vs TMW0 | leitura |")
    lines.append("|---|---|---|---|---|---|---|---|")
    skew_fired = False
    for sid in SAMPLES:
        a = by.get((sid, "TMW0")) or {}
        b = by.get((sid, "TMW_DO")) or {}
        p = pair_note(a, b)
        sleep = as_int(b.get("sleep_calls_intercepted"))
        tq = as_int(b.get("time_queries_intercepted"))
        corr = as_int(b.get("corrections_applied"))
        if sleep or tq:
            skew_fired = True
        if as_int(b.get("json_ok")) == 0 and b:
            read = "module_events.json ausente; 60 s vivo não é progresso; contadores não demonstrados"
        elif sleep or tq:
            read = "SkewMask acionado; duração extra só é progresso se extra_vs_tmw0"
        else:
            read = "SkewMask não acionado; duração extra = espera/custo"
        lines.append(
            f"| {sid} | {a.get('elapsed_ms', '')} | {b.get('elapsed_ms', '')} | {sleep} | {tq} | {corr} | {p['extra_vs_tmw0']} | {read} |"
        )
    lines.append("")
    if not skew_fired:
        lines.append(
            "**Item 3:** nestas três amostras o SkewMask não interceptou Sleep/QPC. "
            "Não se interpreta TMW_DO mais longo como progresso. r43d (benigno) continua à parte."
        )
    else:
        lines.append(
            "Houve interceptação temporal. Comparar artefactos da tabela do item 2; "
            "sem extra vs TMW0 a duração maior continua espera/custo."
        )

    lines += [
        "",
        "## 4. Coerência temporal de SkewMask",
        "",
        "**Não corrido. Limitação.** Este protocolo não substitui a bateria de esperas concorrentes/sobrepostas/alertáveis. `SkewMask.cpp` não foi alterado.",
        "",
        "## 5. Pin sem Pintool no corpus",
        "",
        "**Limitação.** Só existe o N=3 técnico em TestAntiDebug (920A730A, 3/3 exit 0). Não é braço dos 100 PE.",
        "",
        "## 6. Metadados incompletos",
        "",
        "**Limitação.** Família MalwareBazaar grosseira; packer unknown; targeted_evasion=unverified nos 50 MAL.",
        "",
        "## 7. Comparação experimental externa",
        "",
        "**Limitação.** Sem bake-off Arancino/COBAI/Peekaboo. Arancino: Pin 2.14, 32-bit vs corpus x64.",
        "",
        "## 8. Critérios prospectivos",
        "",
        "As três SHA e os braços foram fixados **antes** desta corrida. Isso não torna prospectiva a campanha das 9.000.",
        "",
        "## Frases que continuam proibidas",
        "",
        "- os 100 usam as cinco checagens; IAT = verificação; vivo 60 s = ganho; pin+conhost = progresso; identified=true sem os quatro elos.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    src = find_dir("access_m3_cases")
    dst = ORACLE / "access_m3_cases"
    out_md = MS / "RESPOSTA_ITENS_1_8_M3.md"
    if not src:
        out_md.write_text(render_awaiting(), encoding="utf-8")
        print("AWAITING guest folder access_m3_cases")
        print(out_md)
        return
    copy_tree(src, dst)
    rows = load_runs(dst)
    fields = [
        "run_dir", "sample_id", "sha256", "mode", "knobs", "pin_sha256",
        "pin_sha256_matches_campaign", "dll_sha256", "elapsed_ms", "exit_code",
        "timed_out", "json_ok", "hook_seen", "result_changed", "verdict",
        "pe_calls_intercepted", "pe_processes_filtered", "pe_modules_examined",
        "pe_modules_filtered", "sleep_calls_intercepted", "time_queries_intercepted",
        "corrections_applied", "n_new_files", "n_registry_delta", "n_tcp_established",
        "n_app_descendants", "app_descendant_names", "stdout_sha256", "stderr_sha256",
        "identified", "chain_complete", "dll_map_failed", "why",
    ]
    write_csv(ORACLE / "access_m3_cases_summary.csv", rows, fields)
    pairs = []
    by = {(r.get("sample_id"), r.get("mode")): r for r in rows}
    for sid in SAMPLES:
        base = by.get((sid, "TMW0"))
        for mode in ("TMW_DP", "TMW_DO"):
            treat = by.get((sid, mode))
            p = pair_note(base, treat)
            pairs.append({
                "sample_id": sid,
                "mode": mode,
                "hook_seen": p["hook_seen"],
                "result_changed": p["result_changed"],
                "extra_vs_tmw0": p["extra_vs_tmw0"],
                "chain_complete": p["chain_complete"],
                "extra_why": p["extra_why"],
                "identified": False,
            })
    write_csv(
        ORACLE / "access_m3_cases_pairs.csv",
        pairs,
        ["sample_id", "mode", "hook_seen", "result_changed", "extra_vs_tmw0", "chain_complete", "extra_why", "identified"],
    )
    manifest = {
        "pack": "access_m3_cases",
        "cited_commit": "a2ee6c9e509ce2d47ff68ba3ae9197a6529d66b3",
        "dll": DLL,
        "pin_launcher": EXPECTED_PIN,
        "n_runs": len(rows),
        "identified_true": 0,
        "any_chain_complete": any(p["chain_complete"] for p in pairs),
        "contains_malware": False,
        "not_a_claim": "three_samples_are_not_the_100; IAT_is_not_a_case; alive_is_not_progress",
    }
    (ORACLE / "m3_cases_ingest_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    out_md.write_text(render_from_runs(rows), encoding="utf-8")
    print(f"ingested {len(rows)} runs -> {dst}")
    print(out_md)


if __name__ == "__main__":
    main()
