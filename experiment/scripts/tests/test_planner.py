#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Testes unitários do gerador de plano experimental (Planner)."""
from __future__ import annotations

import csv
import json
import tempfile
import unittest
import sys
from pathlib import Path

# Garantir que a raiz TOMWare esteja no sys.path
_repo_root = Path(__file__).resolve().parents[3]
if str(_repo_root) not in sys.path:
    sys.path.insert(0, str(_repo_root))

from experiment.scripts.planner.generate_plan import generate_plan, get_repo_root


class TestPlanner(unittest.TestCase):
    def setUp(self):
        self.repo_root = get_repo_root()

    def test_pilot_plan_generation_and_integrity(self):
        campaign_id = "test_pilot_unit"
        res = generate_plan(
            repo_root=self.repo_root,
            campaign_id=campaign_id,
            pilot_mode=True,
            repetitions=2,  # curto para teste
            seed=424242,
            pin_condition_valid=False,
        )

        self.assertEqual(res["samples_count"], 10)
        self.assertEqual(res["conditions_count"], 9)
        self.assertEqual(res["repetitions"], 2)
        self.assertEqual(res["total_runs"], 10 * 9 * 2)  # 180 runs

        plan_path = Path(res["plan_csv"])
        self.assertTrue(plan_path.exists())

        with plan_path.open("r", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))

        self.assertEqual(len(rows), 180)

        # Verificar integridade dos blocos:
        # Cada bloco (sample_id, rep) deve ter exatamente as 9 condições distintas
        blocks = {}
        for r in rows:
            b_id = r["block_id"]
            blocks.setdefault(b_id, []).append(r["condition"])

        self.assertEqual(len(blocks), 20)  # 10 amostras * 2 repetições
        expected_conds = {"NAT", "EMPTY", "TMW0", "TMW_DD", "TMW_DP", "TMW_DE", "TMW_DM", "TMW_DO", "TMW_ALL"}

        for b_id, cond_list in blocks.items():
            self.assertEqual(len(cond_list), 9, f"Bloco {b_id} não possui 9 execuções.")
            self.assertEqual(set(cond_list), expected_conds, f"Bloco {b_id} tem condições repetidas ou faltantes.")

    def test_plan_determinism_with_same_seed(self):
        res1 = generate_plan(
            repo_root=self.repo_root,
            campaign_id="test_det_1",
            pilot_mode=True,
            repetitions=1,
            seed=999888,
        )
        res2 = generate_plan(
            repo_root=self.repo_root,
            campaign_id="test_det_2",
            pilot_mode=True,
            repetitions=1,
            seed=999888,
        )
        with open(res1["plan_csv"], encoding="utf-8") as f1, open(res2["plan_csv"], encoding="utf-8") as f2:
            r1 = [row["condition"] for row in csv.DictReader(f1)]
            r2 = [row["condition"] for row in csv.DictReader(f2)]
        self.assertEqual(r1, r2, "Mesma semente gerou ordens diferentes!")

    def test_different_seeds_produce_different_orders(self):
        res1 = generate_plan(
            repo_root=self.repo_root,
            campaign_id="test_diff_1",
            pilot_mode=True,
            repetitions=1,
            seed=111111,
        )
        res2 = generate_plan(
            repo_root=self.repo_root,
            campaign_id="test_diff_2",
            pilot_mode=True,
            repetitions=1,
            seed=222222,
        )
        with open(res1["plan_csv"], encoding="utf-8") as f1, open(res2["plan_csv"], encoding="utf-8") as f2:
            r1 = [row["condition"] for row in csv.DictReader(f1)]
            r2 = [row["condition"] for row in csv.DictReader(f2)]
        self.assertNotEqual(r1, r2, "Sementes distintas geraram a mesma ordem!")


if __name__ == "__main__":
    unittest.main()
