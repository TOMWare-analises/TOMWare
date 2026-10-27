#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Teste de integração ponta a ponta com executável benigno (sem malware)."""
from __future__ import annotations

import csv
import json
import shutil
import subprocess
import tempfile
import sys
import unittest
from pathlib import Path

_repo_root = Path(__file__).resolve().parents[3]
if str(_repo_root) not in sys.path:
    sys.path.insert(0, str(_repo_root))

from experiment.scripts.planner.generate_plan import generate_plan, get_repo_root
from experiment.scripts.validators.validate_campaign import CampaignValidator


class TestBenignIntegration(unittest.TestCase):
    def setUp(self):
        self.repo_root = get_repo_root()
        self.campaign_id = "test_integ_benign"
        self.campaign_dir = self.repo_root / "experiment" / "campaigns" / self.campaign_id
        if self.campaign_dir.exists():
            shutil.rmtree(self.campaign_dir, ignore_errors=True)

    def tearDown(self):
        if self.campaign_dir.exists():
            shutil.rmtree(self.campaign_dir, ignore_errors=True)

    def test_benign_nat_execution_and_schema_validation(self):
        # 1. Gerar plano para 1 amostra benigna (BEN_03), 1 repetição
        plan_res = generate_plan(
            repo_root=self.repo_root,
            campaign_id=self.campaign_id,
            pilot_mode=False,
            repetitions=1,
            seed=777,
            override_samples=["BEN_03"],
        )
        self.assertTrue(Path(plan_res["plan_csv"]).exists())

        # Ajustar timeout curto para o teste de integracao nao aguardar 120s
        plan_csv = Path(plan_res["plan_csv"])
        with plan_csv.open("r", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        for r in rows:
            r["timeout_seconds"] = "5"
        with plan_csv.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)

        # 2. Executar via PowerShell runner filtrando apenas a condição NAT
        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(self.repo_root / "experiment" / "scripts" / "runner" / "Run-Campaign.ps1"),
            "-CampaignId",
            self.campaign_id,
            "-Condition",
            "NAT",
        ]
        proc = subprocess.run(cmd, cwd=str(self.repo_root), capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, f"Runner falhou: {proc.stderr}\n{proc.stdout}")

        # 3. Verificar que o arquivo JSON foi gerado atomicamente e existe
        runs_dir = self.campaign_dir / "raw" / "runs"
        json_files = list(runs_dir.glob("*.json"))
        self.assertEqual(len(json_files), 1, "Deveria haver exatamente 1 arquivo JSON gerado")

        with json_files[0].open("r", encoding="utf-8-sig") as jf:
            record = json.load(jf)

        # 4. Verificar métricas e conformidade
        self.assertEqual(record["identification"]["condition"], "NAT")
        self.assertEqual(record["identification"]["sample_id"], "BEN_03")
        self.assertTrue(record["operational_outcome"]["launch_success"])
        self.assertGreater(record["timing_and_cpu"]["wall_clock_ms"], 0)
        self.assertGreater(record["memory"]["peak_working_set_bytes"], 0)

        # 5. Executar o validador de integridade experimental
        validator = CampaignValidator(self.campaign_dir)
        report = validator.validate()
        # Como filtramos apenas a condição NAT (as outras estão em missing_runs),
        # não deve haver violações críticas na execução gerada
        self.assertEqual(len(report["violations"]), 0, f"Houve violações críticas: {report['violations']}")


if __name__ == "__main__":
    unittest.main()
