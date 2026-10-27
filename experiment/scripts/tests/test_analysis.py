#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Testes unitários do motor estatístico e gerador de figuras."""
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

from experiment.scripts.analysis.consolidate_and_analyze import (
    CampaignAnalyzer,
    bootstrap_ci_median,
    wilson_score_interval,
)


class TestAnalysisEngine(unittest.TestCase):
    def test_wilson_interval_bounds(self):
        p, lo, hi = wilson_score_interval(10, 10)
        self.assertEqual(p, 1.0)
        self.assertLess(lo, 1.0)
        self.assertGreater(lo, 0.65)
        self.assertEqual(hi, 1.0)

        p, lo, hi = wilson_score_interval(0, 10)
        self.assertEqual(p, 0.0)
        self.assertEqual(lo, 0.0)
        self.assertGreater(hi, 0.0)

    def test_bootstrap_ci_median(self):
        data = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0]
        med, iqr, lo, hi = bootstrap_ci_median(data, n_boot=500, rng_seed=42)
        self.assertEqual(med, 13.0)
        self.assertLessEqual(lo, med)
        self.assertGreaterEqual(hi, med)
        self.assertEqual(iqr, 3.0)

    def test_full_analysis_workflow_on_synthetic_campaign(self):
        temp_dir = Path(tempfile.mkdtemp(prefix="test_analysis_"))
        try:
            (temp_dir / "raw" / "runs").mkdir(parents=True)
            manifest = {
                "campaign_id": "test_synth_camp",
                "samples": [
                    {"sample_id": "BEN_01", "group": "benign", "execution_profile": "short_lived"},
                    {"sample_id": "MAL_01", "group": "malicious", "execution_profile": "persistent"},
                ]
            }
            with (temp_dir / "campaign.json").open("w", encoding="utf-8") as f:
                json.dump(manifest, f)

            plan_rows = [
                {"run_id": "r1", "sample_id": "BEN_01", "group": "benign", "execution_profile": "short_lived", "condition": "NAT"},
                {"run_id": "r2", "sample_id": "BEN_01", "group": "benign", "execution_profile": "short_lived", "condition": "TMW0"},
                {"run_id": "r3", "sample_id": "BEN_01", "group": "benign", "execution_profile": "short_lived", "condition": "TMW_DD"},
                {"run_id": "r4", "sample_id": "BEN_01", "group": "benign", "execution_profile": "short_lived", "condition": "EMPTY"},
            ]
            with (temp_dir / "execution_plan.csv").open("w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=list(plan_rows[0].keys()))
                w.writeheader()
                w.writerows(plan_rows)

            # Criar 4 JSONs sintéticos
            for i, p in enumerate(plan_rows, start=1):
                rec = {
                    "identification": {"run_id": p["run_id"], "sample_id": p["sample_id"], "condition": p["condition"], "repetition": 1, "block_id": "b1"},
                    "operational_outcome": {"launch_success": True, "natural_completion": True, "timeout": False, "controlled_termination": False, "crash": False, "exit_code": 0, "termination_reason": "natural_exit"},
                    "timing_and_cpu": {"wall_clock_ms": 100.0 * i, "cpu_total_ms": 50.0 * i, "cpu_user_ms": 40.0 * i, "cpu_kernel_ms": 10.0 * i},
                    "memory": {"peak_working_set_bytes": 1024 * 1024 * 10 * i, "peak_private_bytes": 1024 * 1024 * 5 * i},
                    "io": {"bytes_read": 10, "bytes_written": 20},
                    "processes_threads_modules": {"peak_tracked_processes": 1, "peak_tracked_threads": 2},
                    "behavioral_fidelity": {"stdout_sha256": "h1", "stderr_sha256": "h2"},
                }
                with (temp_dir / "raw" / "runs" / f"{p['run_id']}.json").open("w", encoding="utf-8") as f:
                    json.dump(rec, f)

            analyzer = CampaignAnalyzer(temp_dir)
            res = analyzer.run_full_analysis()

            self.assertEqual(res["total_runs_analyzed"], 4)
            self.assertEqual(res["samples_analyzed"], 1)

            # Verificar arquivos gerados
            self.assertTrue((temp_dir / "processed" / "sample_metrics.csv").exists())
            self.assertTrue((temp_dir / "processed" / "paired_contrasts.csv").exists())
            self.assertTrue((temp_dir / "reports" / "tables" / "table_01_corpus_composition.csv").exists())
            self.assertTrue((temp_dir / "reports" / "tables" / "table_11_incremental_module_effects.csv").exists())
            self.assertTrue((temp_dir / "reports" / "figures" / "fig_paired_effects_forest.png").exists())
            self.assertTrue((temp_dir / "reports" / "figures" / "fig_resource_boxplots.png").exists())
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
