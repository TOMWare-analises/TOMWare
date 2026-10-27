#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gerador de Plano Experimental Randomizado em Blocos (Planner) — TOMWare.M

Atende aos requisitos de rigor científico:
1. Blocos estritos por amostra (sample_id, repetition);
2. Randomização independente das condições dentro de cada bloco;
3. Semente pseudoaleatória auditável registrada em arquivo permanente;
4. Nenhuma seleção ou reordenação baseada em resultados;
5. Suporte desacoplado para piloto (5+5) e campanha definitiva (50+50).
"""
from __future__ import annotations

import argparse
import csv
import datetime
import hashlib
import json
import os
import random
import sys
from pathlib import Path
from typing import Any, Dict, List


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_csv(path: Path) -> List[Dict[str, str]]:
    with path.open("r", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def get_repo_root() -> Path:
    current = Path(__file__).resolve()
    for parent in [current] + list(current.parents):
        if (parent / "experiment" / "config" / "experiment.config.json").exists():
            return parent
    return Path.cwd()


def select_pilot_samples(corpus: List[Dict[str, str]], n_benign: int = 5, n_malicious: int = 5) -> List[Dict[str, str]]:
    """
    Seleciona deterministicamente amostras para o piloto garantindo
    representatividade de curta duração e persistentes em ambos os grupos.
    """
    benign_short = [s for s in corpus if s.get("group") == "benign" and s.get("execution_profile") == "short_lived" and s.get("included") == "true"]
    benign_pers = [s for s in corpus if s.get("group") == "benign" and s.get("execution_profile") == "persistent" and s.get("included") == "true"]
    mal_short = [s for s in corpus if s.get("group") == "malicious" and s.get("execution_profile") == "short_lived" and s.get("included") == "true"]
    mal_pers = [s for s in corpus if s.get("group") == "malicious" and s.get("execution_profile") == "persistent" and s.get("included") == "true"]

    selected: List[Dict[str, str]] = []
    # Benignos: preferencialmente equilibrados entre short e persistent
    n_b_short = n_benign // 2
    n_b_pers = n_benign - n_b_short
    selected.extend(benign_short[:n_b_short])
    selected.extend(benign_pers[:n_b_pers])

    # Maliciosos: preferencialmente equilibrados entre short e persistent
    n_m_short = n_malicious // 2
    n_m_pers = n_malicious - n_m_short
    selected.extend(mal_short[:n_m_short])
    selected.extend(mal_pers[:n_m_pers])

    return selected


def generate_plan(
    repo_root: Path,
    campaign_id: str,
    pilot_mode: bool = False,
    repetitions: int | None = None,
    seed: int | None = None,
    pin_condition_valid: bool = False,
    override_samples: List[str] | None = None,
) -> Dict[str, Any]:
    config_path = repo_root / "experiment" / "config" / "experiment.config.json"
    config = load_json(config_path)

    conditions_file = repo_root / config["paths"]["conditions_csv"]
    corpus_file = repo_root / config["paths"]["corpus_csv"]

    all_conditions = load_csv(conditions_file)
    all_corpus = load_csv(corpus_file)

    # Filtrar condições válidas
    conditions = [
        c for c in all_conditions
        if c["condition"] != "PIN" or pin_condition_valid
    ]

    # Determinar repetições
    if repetitions is None:
        if pilot_mode:
            repetitions = int(config["campaigns"]["pilot"]["repetitions"])
        else:
            repetitions = int(config["campaigns"]["definitive"]["repetitions"])

    # Seleção de amostras
    if override_samples:
        samples = [s for s in all_corpus if s["sample_id"] in override_samples or s["sha256"] in override_samples]
    elif pilot_mode:
        p_cfg = config["campaigns"]["pilot"]["samples_per_group"]
        samples = select_pilot_samples(
            all_corpus,
            n_benign=p_cfg.get("benign", 5),
            n_malicious=p_cfg.get("malicious", 5),
        )
    else:
        samples = [s for s in all_corpus if s.get("included", "").lower() == "true"]

    if not samples:
        raise ValueError("Nenhuma amostra qualificada encontrada no corpus.csv.")

    # Semente pseudoaleatória
    if seed is None:
        # Se configurado explicitamente no JSON
        cfg_seed = config["randomization"].get("seed")
        if cfg_seed is not None:
            seed = int(cfg_seed)
        else:
            seed = random.SystemRandom().randint(100000, 999999999)

    rng = random.Random(seed)

    # Registro da semente permanente em randomization_seeds.csv
    seeds_file = repo_root / "experiment" / "protocol" / "randomization_seeds.csv"
    seeds_file.parent.mkdir(parents=True, exist_ok=True)
    seeds_exist = seeds_file.exists()
    with seeds_file.open("a", newline="", encoding="utf-8") as sf:
        writer = csv.writer(sf)
        if not seeds_exist:
            writer.writerow(["timestamp_utc", "campaign_id", "pilot_mode", "seed", "samples_count", "repetitions", "conditions_count", "total_runs"])

    campaign_dir = repo_root / config["paths"]["campaigns_dir"] / campaign_id
    campaign_dir.mkdir(parents=True, exist_ok=True)
    (campaign_dir / "raw" / "runs").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "raw" / "resources").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "raw" / "behavior").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "raw" / "module_events").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "raw" / "stdout").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "raw" / "stderr").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "processed").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "reports" / "tables").mkdir(parents=True, exist_ok=True)
    (campaign_dir / "reports" / "figures").mkdir(parents=True, exist_ok=True)

    # Construir blocos e randomizar
    plan_rows: List[Dict[str, Any]] = []
    global_order = 1

    cond_names = [c["condition"] for c in conditions]
    cond_map = {c["condition"]: c for c in conditions}

    # Para cada repetição e cada amostra: gera um bloco
    for rep in range(1, repetitions + 1):
        for sample in samples:
            s_id = sample["sample_id"]
            block_id = f"{s_id}_rep{rep:02d}"

            # Randomização estrita das condições dentro do bloco
            shuffled_conds = list(cond_names)
            rng.shuffle(shuffled_conds)

            for order_in_block, cond in enumerate(shuffled_conds, start=1):
                run_id = f"{campaign_id}_{s_id}_r{rep:02d}_{cond}_{order_in_block:02d}"
                c_meta = cond_map[cond]
                prof = sample.get("execution_profile", "short_lived")

                timeout = config["observation"]["short_lived"]["timeout_seconds"] if prof == "short_lived" else config["observation"]["persistent"]["window_seconds"]
                window = config["observation"]["persistent"]["window_seconds"] if prof == "persistent" else 0

                plan_rows.append({
                    "global_order": global_order,
                    "campaign_id": campaign_id,
                    "block_id": block_id,
                    "run_id": run_id,
                    "sample_id": s_id,
                    "sha256": sample["sha256"],
                    "group": sample["group"],
                    "execution_profile": prof,
                    "repetition": rep,
                    "condition": cond,
                    "order_in_block": order_in_block,
                    "modules_enabled": c_meta.get("modules_enabled", ""),
                    "command_template": c_meta["command_template"],
                    "knobs": c_meta.get("knobs", ""),
                    "timeout_seconds": timeout,
                    "window_seconds": window,
                    "random_seed": seed,
                    "status": "planned",
                })
                global_order += 1

    # Gravar execution_plan.csv
    plan_csv_path = campaign_dir / "execution_plan.csv"
    with plan_csv_path.open("w", newline="", encoding="utf-8") as f:
        fieldnames = list(plan_rows[0].keys())
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(plan_rows)

    total_runs = len(plan_rows)
    now_utc = datetime.datetime.now(datetime.timezone.utc).isoformat()

    # Atualizar randomization_seeds.csv com totais reais
    with seeds_file.open("a", newline="", encoding="utf-8") as sf:
        writer = csv.writer(sf)
        writer.writerow([
            now_utc,
            campaign_id,
            pilot_mode,
            seed,
            len(samples),
            repetitions,
            len(conditions),
            total_runs,
        ])

    # Hash da configuração e do plano
    plan_bytes = plan_csv_path.read_bytes()
    plan_hash = hashlib.sha256(plan_bytes).hexdigest()

    # Gravar campaign.json
    manifest = {
        "schema_version": 1,
        "campaign_id": campaign_id,
        "pilot_mode": pilot_mode,
        "created_at_utc": now_utc,
        "random_seed": seed,
        "repetitions": repetitions,
        "pin_condition_valid": pin_condition_valid,
        "conditions_included": [c["condition"] for c in conditions],
        "samples_count": len(samples),
        "samples": [
            {
                "sample_id": s["sample_id"],
                "sha256": s["sha256"],
                "group": s["group"],
                "execution_profile": s["execution_profile"],
            }
            for s in samples
        ],
        "total_planned_runs": total_runs,
        "plan_sha256": plan_hash,
        "sampling_interval_ms": config["sampling"]["resource_interval_ms"],
        "isolation_restore_unit": config["isolation"]["restore_unit"],
    }

    manifest_path = campaign_dir / "campaign.json"
    with manifest_path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    return {
        "campaign_id": campaign_id,
        "campaign_dir": str(campaign_dir),
        "plan_csv": str(plan_csv_path),
        "manifest_json": str(manifest_path),
        "seed": seed,
        "samples_count": len(samples),
        "repetitions": repetitions,
        "conditions_count": len(conditions),
        "total_runs": total_runs,
        "plan_sha256": plan_hash,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Gera plano de execução randomizado em blocos (TOMWare.M)")
    parser.add_argument("--campaign-id", required=True, help="Identificador único da campanha")
    parser.add_argument("--pilot", action="store_true", help="Gera plano para campanha piloto (5 benignos + 5 maliciosos)")
    parser.add_argument("--repetitions", type=int, default=None, help="Número de repetições (sobrescreve config)")
    parser.add_argument("--seed", type=int, default=None, help="Semente pseudoaleatória (para reproduzir plano)")
    parser.add_argument("--pin-valid", action="store_true", help="Inclui condição PIN sem tool se validada por probe")
    parser.add_argument("--samples", nargs="+", default=None, help="Lista de sample_id para um plano reduzido (ex.: BEN_01)")

    args = parser.parse_args()
    root = get_repo_root()
    res = generate_plan(
        repo_root=root,
        campaign_id=args.campaign_id,
        pilot_mode=args.pilot,
        repetitions=args.repetitions,
        seed=args.seed,
        pin_condition_valid=args.pin_valid,
        override_samples=args.samples,
    )
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
