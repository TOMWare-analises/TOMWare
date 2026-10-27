#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Testes unitários do validador de integridade experimental."""
from __future__ import annotations

import csv
import json
import shutil
import tempfile
import sys
import unittest
from pathlib import Path

_repo_root = Path(__file__).resolve().parents[3]
if str(_repo_root) not in sys.path:
    sys.path.insert(0, str(_repo_root))

from experiment.scripts.validators.validate_campaign import CampaignValidator


class TestCampaignValidator(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp(prefix="test_val_"))
        (self.temp_dir / "raw" / "runs").mkdir(parents=True)
        (self.temp_dir / "processed").mkdir(parents=True)

        self.manifest = {
            "schema_version": 1,
            "campaign_id": "test_val_camp",
            "pilot_mode": True,
            "repetitions": 1,
            "total_planned_runs": 1,
        }
        with (self.temp_dir / "campaign.json").open("w", encoding="utf-8") as f:
            json.dump(self.manifest, f)

        self.plan_rows = [
            {
                "global_order": "1",
                "campaign_id": "test_val_camp",
                "block_id": "BEN_01_rep01",
                "run_id": "test_val_run_1",
                "sample_id": "BEN_01",
                "sha256": "1128D0B41456073E0B22E328CE4A89D0877F7D18147DF6B339A4CCE758A1DAAB",
                "group": "benign",
                "execution_profile": "short_lived",
                "repetition": "1",
                "condition": "TMW_DD",
                "order_in_block": "1",
                "modules_enabled": "AntiDebug",
                "command_template": "dummy",
                "knobs": "-dd -q",
                "timeout_seconds": "120",
                "window_seconds": "0",
                "random_seed": "123",
                "status": "planned",
            }
        ]
        with (self.temp_dir / "execution_plan.csv").open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(self.plan_rows[0].keys()))
            w.writeheader()
            w.writerows(self.plan_rows)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _create_record(self, overrides: dict = None) -> dict:
        rec = {
            "schema_version": 1,
            "identification": {
                "campaign_id": "test_val_camp",
                "run_id": "test_val_run_1",
                "sample_id": "BEN_01",
                "sha256": "1128D0B41456073E0B22E328CE4A89D0877F7D18147DF6B339A4CCE758A1DAAB",
                "block_id": "BEN_01_rep01",
                "repetition": 1,
                "condition": "TMW_DD",
                "modules_enabled": ["AntiDebug"],
                "run_order": 1,
                "random_seed": 123,
                "host_id": "TEST_HOST",
                "vm_id": "",
                "snapshot_id": "",
                "restore_completed": True,
                "start_timestamp_utc": "2026-10-13T10:00:00Z",
                "end_timestamp_utc": "2026-10-13T10:00:05Z",
                "monotonic_duration_ms": 5000.0,
                "configuration_hash": "",
            },
            "operational_outcome": {
                "launch_success": True,
                "pid": 1234,
                "parent_pid": 1000,
                "natural_completion": True,
                "timeout": False,
                "still_active_at_window_end": False,
                "controlled_termination": False,
                "crash": False,
                "exception_code": None,
                "exit_code": 0,
                "termination_reason": "natural_exit",
                "observation_duration_ms": 5000.0,
                "time_to_first_activity_ms": 10.0,
                "collector_failure": False,
                "missing_reason": None,
            },
            "timing_and_cpu": {
                "wall_clock_ms": 5000.0,
                "cpu_user_ms": 120.0,
                "cpu_kernel_ms": 40.0,
                "cpu_total_ms": 160.0,
                "cpu_percent_mean": 3.2,
                "cpu_percent_max": 10.0,
                "logical_processors": 4,
            },
            "memory": {
                "current_working_set_bytes": 10000000,
                "peak_working_set_bytes": 12000000,
                "average_working_set_bytes": 8000000,
                "peak_private_bytes": 5000000,
                "average_private_bytes": 4000000,
                "sample_count": 25,
            },
            "io": {
                "bytes_read": 100,
                "bytes_written": 200,
                "read_operations": 5,
                "write_operations": 10,
            },
            "processes_threads_modules": {
                "peak_tracked_processes": 1,
                "peak_tracked_threads": 2,
                "child_pids": [],
                "loaded_modules_count": 10,
            },
            "behavioral_fidelity": {
                "stdout_sha256": "abc",
                "stderr_sha256": "def",
                "stdout_bytes": 10,
                "stderr_bytes": 0,
            },
            "artifacts": {
                "raw_record_json_path": "dummy.json",
                "stdout_path": "out.txt",
                "stderr_path": "err.txt",
            },
        }
        if overrides:
            for k, v in overrides.items():
                if isinstance(v, dict) and k in rec:
                    rec[k].update(v)
                else:
                    rec[k] = v
        return rec

    def test_valid_record_passes(self):
        rec = self._create_record()
        with (self.temp_dir / "raw" / "runs" / "test_val_run_1.json").open("w", encoding="utf-8") as f:
            json.dump(rec, f)

        validator = CampaignValidator(self.temp_dir)
        report = validator.validate()

        self.assertTrue(report["passed"])
        self.assertEqual(report["critical_violations_count"], 0)

    def test_timeout_and_natural_completion_conflict_fails(self):
        rec = self._create_record({
            "operational_outcome": {
                "timeout": True,
                "natural_completion": True,
                "termination_reason": "natural_exit",
            }
        })
        with (self.temp_dir / "raw" / "runs" / "test_val_run_1.json").open("w", encoding="utf-8") as f:
            json.dump(rec, f)

        validator = CampaignValidator(self.temp_dir)
        report = validator.validate()

        self.assertFalse(report["passed"])
        rules_triggered = [v["rule"] for v in report["violations"]]
        self.assertIn("TIMEOUT_MARKED_NATURAL", rules_triggered)

    def test_peak_ws_less_than_avg_fails(self):
        rec = self._create_record({
            "memory": {
                "peak_working_set_bytes": 5000,
                "average_working_set_bytes": 9000,
            }
        })
        with (self.temp_dir / "raw" / "runs" / "test_val_run_1.json").open("w", encoding="utf-8") as f:
            json.dump(rec, f)

        validator = CampaignValidator(self.temp_dir)
        report = validator.validate()

        self.assertFalse(report["passed"])
        rules_triggered = [v["rule"] for v in report["violations"]]
        self.assertIn("PEAK_LESS_THAN_AVG_WS", rules_triggered)

    def test_unplanned_orphan_run_fails(self):
        rec = self._create_record()
        with (self.temp_dir / "raw" / "runs" / "test_val_run_1.json").open("w", encoding="utf-8") as f:
            json.dump(rec, f)
        # Cria arquivo orfao
        with (self.temp_dir / "raw" / "runs" / "orphan_run.json").open("w", encoding="utf-8") as f:
            json.dump(rec, f)

        validator = CampaignValidator(self.temp_dir)
        report = validator.validate()

        self.assertFalse(report["passed"])
        rules_triggered = [v["rule"] for v in report["violations"]]
        self.assertIn("UNPLANNED_RUN", rules_triggered)


if __name__ == "__main__":
    unittest.main()
