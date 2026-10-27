#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Validador Automatizado de Integridade e Regras a Priori — TOMWare.M

Aplica as regras normativas da Seção 15 e 16 da especificação experimental:
- Detecta execuções ausentes, duplicadas ou fora de ordem;
- Verifica sanidade temporal e ausência de CPU/memória negativas;
- Impede inconsistências entre timeout e término natural;
- Verifica correspondência estrita de knobs por condição experimental;
- Falha explicitamente diante de qualquer violação crítica.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple


class CampaignValidator:
    def __init__(self, campaign_dir: Path):
        self.campaign_dir = campaign_dir
        self.manifest_path = campaign_dir / "campaign.json"
        self.plan_path = campaign_dir / "execution_plan.csv"
        self.runs_dir = campaign_dir / "raw" / "runs"

        self.violations: List[Dict[str, Any]] = []
        self.warnings: List[Dict[str, Any]] = []
        self.validated_records: List[Dict[str, Any]] = []
        self.missing_runs: List[Dict[str, Any]] = []

    def add_violation(self, rule: str, run_id: str, message: str, critical: bool = True) -> None:
        entry = {
            "rule": rule,
            "run_id": run_id,
            "message": message,
            "critical": critical,
        }
        if critical:
            self.violations.append(entry)
        else:
            self.warnings.append(entry)

    def validate(self) -> Dict[str, Any]:
        if not self.manifest_path.exists():
            raise FileNotFoundError(f"campaign.json ausente em: {self.campaign_dir}")
        if not self.plan_path.exists():
            raise FileNotFoundError(f"execution_plan.csv ausente em: {self.campaign_dir}")

        with self.manifest_path.open("r", encoding="utf-8") as f:
            manifest = json.load(f)
        with self.plan_path.open("r", encoding="utf-8-sig") as f:
            planned_rows = list(csv.DictReader(f))

        planned_run_ids = [r["run_id"] for r in planned_rows]
        seen_run_ids: Set[str] = set()

        # 1. Checar unicidade no plano
        for run_id in planned_run_ids:
            if run_id in seen_run_ids:
                self.add_violation("UNIQUE_RUN_ID", run_id, "run_id duplicado no plano de execucao")
            seen_run_ids.add(run_id)

        # 2. Carregar e validar cada corrida
        actual_runs_on_disk: Set[str] = set()
        if self.runs_dir.exists():
            for json_file in self.runs_dir.glob("*.json"):
                actual_runs_on_disk.add(json_file.stem)

        for plan_row in planned_rows:
            run_id = plan_row["run_id"]
            json_file = self.runs_dir / f"{run_id}.json"

            if not json_file.exists():
                self.missing_runs.append({
                    "run_id": run_id,
                    "sample_id": plan_row["sample_id"],
                    "condition": plan_row["condition"],
                    "repetition": plan_row["repetition"],
                    "block_id": plan_row["block_id"],
                    "reason": "json_record_not_found_on_disk"
                })
                self.add_violation("MISSING_EXECUTION", run_id, "Execucao planejada nao encontrada em raw/runs/", critical=False)
                continue

            try:
                with json_file.open("r", encoding="utf-8-sig") as jf:
                    record = json.load(jf)
            except Exception as e:
                self.add_violation("CORRUPT_JSON", run_id, f"Falha ao decodificar JSON: {e}", critical=True)
                continue

            self._validate_single_record(plan_row, record)
            self.validated_records.append(record)

        # 3. Detectar execuções órfãs (em disco mas não planejadas)
        for on_disk in actual_runs_on_disk:
            if on_disk not in seen_run_ids:
                self.add_violation("UNPLANNED_RUN", on_disk, "Execucao em disco nao consta no plano planejado", critical=True)

        report = {
            "campaign_id": manifest.get("campaign_id"),
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "total_planned": len(planned_rows),
            "total_validated": len(self.validated_records),
            "total_missing": len(self.missing_runs),
            "critical_violations_count": len(self.violations),
            "warnings_count": len(self.warnings),
            "passed": len(self.violations) == 0,
            "violations": self.violations,
            "warnings": self.warnings,
        }

        # Gravar relatórios
        processed_dir = self.campaign_dir / "processed"
        processed_dir.mkdir(parents=True, exist_ok=True)

        with (processed_dir / "audit_validation_report.json").open("w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)

        # Gravar missing_data.csv
        missing_csv_path = processed_dir / "missing_data.csv"
        with missing_csv_path.open("w", newline="", encoding="utf-8") as f:
            fieldnames = ["run_id", "sample_id", "condition", "repetition", "block_id", "reason"]
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(self.missing_runs)

        return report

    def _validate_single_record(self, plan: Dict[str, str], rec: Dict[str, Any]) -> None:
        run_id = plan["run_id"]
        ident = rec.get("identification", {})
        outcome = rec.get("operational_outcome", {})
        timing = rec.get("timing_and_cpu", {})
        mem = rec.get("memory", {})

        # Condição coincide
        if ident.get("condition") != plan["condition"]:
            self.add_violation("CONDITION_MISMATCH", run_id, f"Esperado {plan['condition']}, registrado {ident.get('condition')}")

        # Regras de isolamento de condição e knobs
        cond = plan["condition"]
        mods_raw = ident.get("modules_enabled", [])
        if isinstance(mods_raw, str):
            if mods_raw.lower() in ("none", ""):
                mods = []
            else:
                mods = [m.strip() for m in mods_raw.split(";") if m.strip() and m.strip().lower() != "none"]
        elif isinstance(mods_raw, list):
            mods = [m.strip() for m in mods_raw if m and m.strip().lower() != "none"]
        else:
            mods = []

        if outcome.get("launch_success", False):
            if cond == "NAT":
                if ident.get("pin_version") and "pin" in str(ident.get("pin_version")).lower() and mods:
                    self.add_violation("NAT_WITH_PIN", run_id, "Condicao NAT contem modulos Pin habilitados")
            elif cond == "EMPTY":
                if mods:
                    self.add_violation("EMPTY_WITH_MODULES", run_id, f"Condicao EMPTY nao pode conter modulos TOMWare: {mods}")
            elif cond == "TMW0":
                if mods:
                    self.add_violation("TMW0_WITH_MODULES", run_id, f"Condicao TMW0 nao pode conter modulos ativos: {mods}")
            elif cond == "TMW_ALL":
                expected_mods = {"AntiDebug", "ProcessEnum", "SanitizePinEnvVars", "InstMemcmpMask", "SkewMask"}
                if set(mods) != expected_mods:
                    self.add_violation("TMW_ALL_INCOMPLETE", run_id, f"TMW_ALL deve ter exatamente os 5 modulos ativos, encontrados: {mods}")
            elif cond.startswith("TMW_"):
                # Exatamente 1 módulo
                if len(mods) != 1:
                    self.add_violation("MULTIPLE_MODULES_IN_SINGLE_COND", run_id, f"Condicao {cond} deve ter exatamente 1 modulo, encontrados: {mods}")

        # Temporal e monotonia
        dur = ident.get("monotonic_duration_ms", -1)
        if dur < 0:
            self.add_violation("NEGATIVE_DURATION", run_id, f"Duracao monotonica negativa: {dur}")

        start_str = ident.get("start_timestamp_utc")
        end_str = ident.get("end_timestamp_utc")
        if start_str and end_str:
            try:
                t0 = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
                t1 = datetime.fromisoformat(end_str.replace("Z", "+00:00"))
                if t1 < t0:
                    self.add_violation("END_BEFORE_START", run_id, f"Timestamp final ({t1}) anterior ao inicial ({t0})")
            except Exception as e:
                self.add_violation("INVALID_TIMESTAMP_FORMAT", run_id, f"Formato de timestamp invalido: {e}")

        # Sanidade de recursos
        cpu_tot = timing.get("cpu_total_ms", 0)
        if cpu_tot is not None and cpu_tot < 0:
            self.add_violation("NEGATIVE_CPU", run_id, f"CPU total negativa: {cpu_tot}")

        ws_peak = mem.get("peak_working_set_bytes", 0)
        ws_avg = mem.get("average_working_set_bytes", 0)
        if ws_peak is not None and ws_peak < 0:
            self.add_violation("NEGATIVE_MEMORY", run_id, f"Working set pico negativo: {ws_peak}")
        if ws_peak is not None and ws_avg is not None and ws_peak < ws_avg:
            self.add_violation("PEAK_LESS_THAN_AVG_WS", run_id, f"Pico WS ({ws_peak}) inferior a media ({ws_avg})")

        # Inconsistência de término
        timed_out = outcome.get("timeout", False)
        natural_exit = outcome.get("natural_completion", False)
        term_reason = outcome.get("termination_reason")

        if timed_out and natural_exit:
            self.add_violation("TIMEOUT_MARKED_NATURAL", run_id, "Execucao marcada simultaneamente como timeout e natural_completion")
        if timed_out and term_reason == "natural_exit":
            self.add_violation("TIMEOUT_CONFLICT_REASON", run_id, "termination_reason marcado como natural_exit em timeout")

        # Processo persistente deve registrar janela
        if plan.get("execution_profile") == "persistent" and outcome.get("launch_success", False):
            if not outcome.get("controlled_termination") and not timed_out and not outcome.get("crash") and not outcome.get("natural_completion"):
                self.add_violation("PERSISTENT_NO_WINDOW", run_id, "Processo persistente sem terminacao controlada nem status valido de janela")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validador de integridade e regras de auditoria experimental (TOMWare.M)")
    parser.add_argument("--campaign-dir", required=True, help="Diretorio da campanha a validar")
    parser.add_argument("--fail-on-critical", action="store_true", default=True, help="Retorna exit code 1 se houver violacoes criticas")
    args = parser.parse_args()

    v = CampaignValidator(Path(args.campaign_dir))
    report = v.validate()

    print(json.dumps(report, indent=2))
    if args.fail_on_critical and not report["passed"]:
        print("\n[ERRO CRITICO] O pipeline detectou violacoes das regras experimentais a priori!", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
