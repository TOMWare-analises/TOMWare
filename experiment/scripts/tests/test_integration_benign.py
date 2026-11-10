#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""End-to-end integration test with a benign executable (no malware)."""
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
        # 1. Generate a plan for 1 benign sample (BEN_03), 1 repetition
        plan_res = generate_plan(
            repo_root=self.repo_root,
            campaign_id=self.campaign_id,
            pilot_mode=False,
            repetitions=1,
            seed=777,
            override_samples=["BEN_03"],
        )
        self.assertTrue(Path(plan_res["plan_csv"]).exists())

        # Short timeout so the integration test does not wait 120s
        plan_csv = Path(plan_res["plan_csv"])
        with plan_csv.open("r", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        for r in rows:
            r["timeout_seconds"] = "5"
        with plan_csv.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)

        # 2. Run via the PowerShell runner, filtering to the NAT condition only
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
        self.assertEqual(proc.returncode, 0, f"Runner failed: {proc.stderr}\n{proc.stdout}")

        # 3. Verify the JSON file was written atomically and exists
        runs_dir = self.campaign_dir / "raw" / "runs"
        json_files = list(runs_dir.glob("*.json"))
        self.assertEqual(len(json_files), 1, "There should be exactly 1 generated JSON file")

        with json_files[0].open("r", encoding="utf-8-sig") as jf:
            record = json.load(jf)

        # 4. Check metrics and schema compliance
        self.assertEqual(record["identification"]["condition"], "NAT")
        self.assertEqual(record["identification"]["sample_id"], "BEN_03")
        self.assertTrue(record["operational_outcome"]["launch_success"])
        self.assertGreater(record["timing_and_cpu"]["wall_clock_ms"], 0)
        self.assertGreater(record["memory"]["peak_working_set_bytes"], 0)

        # 5. Run the experimental integrity validator
        validator = CampaignValidator(self.campaign_dir)
        report = validator.validate()
        # NAT-only filter leaves other conditions in missing_runs;
        # the generated execution must not have critical violations
        self.assertEqual(len(report["violations"]), 0, f"Critical violations found: {report['violations']}")


if __name__ == "__main__":
    unittest.main()
