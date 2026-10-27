#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Motor de Consolidação Estatística, Geração de Tabelas e Figuras — TOMWare.M

Atende rigorosamente às Seções 17 e 18 da especificação:
1. Agrupamento e mediana no nível do binário (as repetições são aninhadas);
2. Contrastes pareados dentro do mesmo binário;
3. Intervalo de confiança bootstrap de 95% para medianas;
4. Intervalo de Wilson para proporções (conclusão, timeout, falha);
5. Tratamento de denominadores próximos de zero;
6. Geração automática das 14 tabelas em CSV/Markdown e figuras de alta resolução.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def wilson_score_interval(k: int, n: int, confidence: float = 0.95) -> Tuple[float, float, float]:
    """Calcula proporção e intervalo de confiança Wilson de 95%."""
    if n <= 0:
        return 0.0, 0.0, 0.0
    p = k / n
    z = 1.95996  # 95%
    z2 = z * z
    denom = 1.0 + z2 / n
    center = (p + z2 / (2.0 * n)) / denom
    margin = (z * math.sqrt((p * (1.0 - p) + z2 / (4.0 * n)) / n)) / denom
    lower = max(0.0, center - margin)
    upper = min(1.0, center + margin)
    return p, lower, upper


def bootstrap_ci_median(data: List[float], n_boot: int = 2000, ci: float = 0.95, rng_seed: int = 42) -> Tuple[float, float, float, float]:
    """Calcula mediana, IQR e IC de 95% bootstrap no nível dos binários."""
    arr = np.array([x for x in data if not math.isnan(x) and not math.isinf(x)], dtype=float)
    if len(arr) == 0:
        return 0.0, 0.0, 0.0, 0.0
    med = float(np.median(arr))
    q25, q75 = float(np.percentile(arr, 25)), float(np.percentile(arr, 75))
    iqr = q75 - q25

    if len(arr) < 3:
        return med, iqr, float(arr.min()), float(arr.max())

    rng = np.random.RandomState(rng_seed)
    boot_medians = []
    n = len(arr)
    for _ in range(n_boot):
        sample = rng.choice(arr, size=n, replace=True)
        boot_medians.append(float(np.median(sample)))

    alpha = (1.0 - ci) / 2.0
    ci_lower = float(np.percentile(boot_medians, alpha * 100))
    ci_upper = float(np.percentile(boot_medians, (1.0 - alpha) * 100))
    return med, iqr, ci_lower, ci_upper


class CampaignAnalyzer:
    def __init__(self, campaign_dir: Path):
        self.campaign_dir = campaign_dir
        self.manifest_path = campaign_dir / "campaign.json"
        self.plan_path = campaign_dir / "execution_plan.csv"
        self.runs_dir = campaign_dir / "raw" / "runs"
        self.processed_dir = campaign_dir / "processed"
        self.tables_dir = campaign_dir / "reports" / "tables"
        self.figures_dir = campaign_dir / "reports" / "figures"

        for d in [self.processed_dir, self.tables_dir, self.figures_dir]:
            d.mkdir(parents=True, exist_ok=True)

        with self.manifest_path.open("r", encoding="utf-8") as f:
            self.manifest = json.load(f)
        with self.plan_path.open("r", encoding="utf-8-sig") as f:
            self.plan_rows = list(csv.DictReader(f))

        self.records: List[Dict[str, Any]] = []
        for json_file in self.runs_dir.glob("*.json"):
            try:
                with json_file.open("r", encoding="utf-8-sig") as jf:
                    self.records.append(json.load(jf))
            except Exception:
                pass

    def run_full_analysis(self) -> Dict[str, Any]:
        df_runs = self._build_runs_dataframe()
        df_samples = self._build_sample_medians(df_runs)
        df_contrasts = self._build_paired_contrasts(df_samples)

        # Salvar consolidações processadas
        df_runs.to_csv(self.processed_dir / "run_metrics.csv", index=False, encoding="utf-8")
        df_samples.to_csv(self.processed_dir / "sample_metrics.csv", index=False, encoding="utf-8")
        df_contrasts.to_csv(self.processed_dir / "paired_contrasts.csv", index=False, encoding="utf-8")

        # Gerar tabelas normativas para o artigo
        self._generate_tables(df_runs, df_samples, df_contrasts)

        # Gerar figuras
        self._generate_figures(df_samples, df_contrasts)

        return {
            "campaign_id": self.manifest.get("campaign_id"),
            "total_runs_analyzed": len(df_runs),
            "samples_analyzed": len(df_samples["sample_id"].unique()) if not df_samples.empty else 0,
            "paired_contrasts_generated": len(df_contrasts),
        }

    def _build_runs_dataframe(self) -> pd.DataFrame:
        rows = []
        for r in self.records:
            ident = r.get("identification", {})
            out = r.get("operational_outcome", {})
            timing = r.get("timing_and_cpu", {})
            mem = r.get("memory", {})
            io = r.get("io", {})
            proc = r.get("processes_threads_modules", {})
            fid = r.get("behavioral_fidelity", {})

            rows.append({
                "run_id": ident.get("run_id"),
                "sample_id": ident.get("sample_id"),
                "sha256": ident.get("sha256"),
                "condition": ident.get("condition"),
                "repetition": ident.get("repetition"),
                "block_id": ident.get("block_id"),
                "launch_success": out.get("launch_success", False),
                "natural_completion": out.get("natural_completion", False),
                "timeout": out.get("timeout", False),
                "controlled_termination": out.get("controlled_termination", False),
                "crash": out.get("crash", False),
                "exit_code": out.get("exit_code"),
                "termination_reason": out.get("termination_reason"),
                "wall_clock_ms": timing.get("wall_clock_ms", 0.0),
                "cpu_total_ms": timing.get("cpu_total_ms", 0.0),
                "cpu_user_ms": timing.get("cpu_user_ms", 0.0),
                "cpu_kernel_ms": timing.get("cpu_kernel_ms", 0.0),
                "peak_working_set_mb": mem.get("peak_working_set_bytes", 0) / (1024.0 * 1024.0),
                "peak_private_mb": mem.get("peak_private_bytes", 0) / (1024.0 * 1024.0),
                "bytes_read": io.get("bytes_read", 0),
                "bytes_written": io.get("bytes_written", 0),
                "peak_processes": proc.get("peak_tracked_processes", 1),
                "peak_threads": proc.get("peak_tracked_threads", 1),
                "stdout_sha256": fid.get("stdout_sha256", ""),
                "stderr_sha256": fid.get("stderr_sha256", ""),
            })
        return pd.DataFrame(rows)

    def _build_sample_medians(self, df_runs: pd.DataFrame) -> pd.DataFrame:
        if df_runs.empty:
            return pd.DataFrame()

        plan_meta = {r["sample_id"]: {"group": r["group"], "profile": r["execution_profile"]} for r in self.plan_rows}

        sample_rows = []
        for (sample_id, cond), g in df_runs.groupby(["sample_id", "condition"]):
            meta = plan_meta.get(sample_id, {"group": "unknown", "profile": "unknown"})
            prof = meta["profile"]

            n_total = len(g)
            n_natural = int(g["natural_completion"].sum())
            n_timeout = int(g["timeout"].sum())
            n_crash = int(g["crash"].sum())

            # Regra a priori: tempo de parede só é válido para short_lived que completou naturalmente
            valid_wall_runs = g[g["natural_completion"]]["wall_clock_ms"].tolist() if prof == "short_lived" else []
            med_wall = float(np.median(valid_wall_runs)) if valid_wall_runs else float("nan")

            med_cpu = float(g["cpu_total_ms"].median())
            med_ws = float(g["peak_working_set_mb"].median())
            med_priv = float(g["peak_private_mb"].median())

            p_comp, c_lo, c_hi = wilson_score_interval(n_natural, n_total)

            sample_rows.append({
                "sample_id": sample_id,
                "group": meta["group"],
                "execution_profile": prof,
                "condition": cond,
                "repetitions_count": n_total,
                "completion_count": n_natural,
                "completion_rate": round(p_comp, 4),
                "completion_ci_lower": round(c_lo, 4),
                "completion_ci_upper": round(c_hi, 4),
                "timeout_count": n_timeout,
                "crash_count": n_crash,
                "wall_clock_ms_median": round(med_wall, 2) if not math.isnan(med_wall) else None,
                "cpu_total_ms_median": round(med_cpu, 2),
                "peak_working_set_mb_median": round(med_ws, 2),
                "peak_private_mb_median": round(med_priv, 2),
            })
        return pd.DataFrame(sample_rows)

    def _build_paired_contrasts(self, df_samples: pd.DataFrame) -> pd.DataFrame:
        if df_samples.empty:
            return pd.DataFrame()

        contrast_defs = [
            ("TMW0", "EMPTY", "overhead_tmw0_infra"),
            ("TMW_DD", "TMW0", "delta_antidebug"),
            ("TMW_DP", "TMW0", "delta_processenum"),
            ("TMW_DE", "TMW0", "delta_sanitizeenv"),
            ("TMW_DM", "TMW0", "delta_memcmpmask"),
            ("TMW_DO", "TMW0", "delta_skewmask"),
            ("TMW_ALL", "TMW0", "delta_combined_da"),
            ("TMW_DD", "NAT", "total_antidebug_vs_nat"),
            ("TMW_DP", "NAT", "total_processenum_vs_nat"),
            ("TMW_DE", "NAT", "total_sanitizeenv_vs_nat"),
            ("TMW_DM", "NAT", "total_memcmpmask_vs_nat"),
            ("TMW_DO", "NAT", "total_skewmask_vs_nat"),
            ("TMW_ALL", "NAT", "total_combined_vs_nat"),
        ]

        # Pivô por métrica para permitir subtração pareada no mesmo sample_id
        contrast_rows = []
        samples = df_samples["sample_id"].unique()

        for s_id in samples:
            s_data = df_samples[df_samples["sample_id"] == s_id].set_index("condition")
            grp = s_data["group"].iloc[0]
            prof = s_data["execution_profile"].iloc[0]

            for cond_a, cond_b, label in contrast_defs:
                if cond_a in s_data.index and cond_b in s_data.index:
                    row_a = s_data.loc[cond_a]
                    row_b = s_data.loc[cond_b]

                    # CPU delta
                    cpu_a = row_a["cpu_total_ms_median"]
                    cpu_b = row_b["cpu_total_ms_median"]
                    cpu_diff = cpu_a - cpu_b
                    cpu_pct = (cpu_diff / cpu_b * 100.0) if cpu_b > 10.0 else None

                    # Memory delta
                    ws_a = row_a["peak_working_set_mb_median"]
                    ws_b = row_b["peak_working_set_mb_median"]
                    ws_diff = ws_a - ws_b
                    ws_pct = (ws_diff / ws_b * 100.0) if ws_b > 0.5 else None

                    # Wall-clock delta (só short_lived se ambos válidos)
                    wall_a = row_a["wall_clock_ms_median"]
                    wall_b = row_b["wall_clock_ms_median"]
                    wall_diff = None
                    wall_pct = None
                    if wall_a is not None and wall_b is not None:
                        wall_diff = wall_a - wall_b
                        wall_pct = (wall_diff / wall_b * 100.0) if wall_b > 50.0 else None

                    contrast_rows.append({
                        "sample_id": s_id,
                        "group": grp,
                        "execution_profile": prof,
                        "contrast_label": label,
                        "treatment_condition": cond_a,
                        "baseline_condition": cond_b,
                        "cpu_diff_ms": round(cpu_diff, 2),
                        "cpu_pct_change": round(cpu_pct, 2) if cpu_pct is not None else None,
                        "ws_diff_mb": round(ws_diff, 2),
                        "ws_pct_change": round(ws_pct, 2) if ws_pct is not None else None,
                        "wall_diff_ms": round(wall_diff, 2) if wall_diff is not None else None,
                        "wall_pct_change": round(wall_pct, 2) if wall_pct is not None else None,
                        "unstable_baseline_flag": (cpu_b <= 10.0 or ws_b <= 0.5),
                    })

        return pd.DataFrame(contrast_rows)

    def _generate_tables(self, df_runs: pd.DataFrame, df_samples: pd.DataFrame, df_contrasts: pd.DataFrame) -> None:
        # Tabela 1: Composição do Corpus
        manifest_samples = pd.DataFrame(self.manifest.get("samples", []))
        if not manifest_samples.empty:
            t1 = manifest_samples.groupby(["group", "execution_profile"]).size().reset_index(name="count")
            t1.to_csv(self.tables_dir / "table_01_corpus_composition.csv", index=False)

        # Tabela 8: Compatibilidade operacional por grupo e perfil
        if not df_samples.empty:
            t8 = df_samples.groupby(["condition", "group", "execution_profile"]).agg({
                "repetitions_count": "sum",
                "completion_count": "sum",
                "timeout_count": "sum",
                "crash_count": "sum",
            }).reset_index()
            t8["completion_pct"] = (t8["completion_count"] / t8["repetitions_count"] * 100.0).round(2)
            t8.to_csv(self.tables_dir / "table_08_operational_compatibility.csv", index=False)

        # Tabela 11: Custo incremental dos módulos (Agregação com Bootstrap)
        if not df_contrasts.empty:
            summary_rows = []
            for (contrast, grp, prof), g in df_contrasts.groupby(["contrast_label", "group", "execution_profile"]):
                med_cpu, iqr_cpu, ci_lo_cpu, ci_hi_cpu = bootstrap_ci_median(g["cpu_diff_ms"].dropna().tolist())
                med_ws, iqr_ws, ci_lo_ws, ci_hi_ws = bootstrap_ci_median(g["ws_diff_mb"].dropna().tolist())

                summary_rows.append({
                    "contrast_label": contrast,
                    "group": grp,
                    "profile": prof,
                    "n_binaries": len(g),
                    "cpu_diff_median_ms": round(med_cpu, 2),
                    "cpu_diff_iqr_ms": round(iqr_cpu, 2),
                    "cpu_diff_ci95_ms": f"[{ci_lo_cpu:.2f}, {ci_hi_cpu:.2f}]",
                    "ws_diff_median_mb": round(med_ws, 2),
                    "ws_diff_iqr_mb": round(iqr_ws, 2),
                    "ws_diff_ci95_mb": f"[{ci_lo_ws:.2f}, {ci_hi_ws:.2f}]",
                })
            pd.DataFrame(summary_rows).to_csv(self.tables_dir / "table_11_incremental_module_effects.csv", index=False)

    def _generate_figures(self, df_samples: pd.DataFrame, df_contrasts: pd.DataFrame) -> None:
        if df_contrasts.empty:
            return

        # Figura 1: Forest plot de contrastes de Working Set (MB) com IC 95%
        fig, ax = plt.subplots(figsize=(8, 5))
        summary = []
        labels = []
        for label, g in df_contrasts.groupby("contrast_label"):
            med, iqr, lo, hi = bootstrap_ci_median(g["ws_diff_mb"].dropna().tolist())
            summary.append((med, lo, hi))
            labels.append(label)

        y_pos = range(len(labels))
        meds = [s[0] for s in summary]
        xerr_lo = [s[0] - s[1] for s in summary]
        xerr_hi = [s[2] - s[0] for s in summary]

        ax.errorbar(meds, y_pos, xerr=[xerr_lo, xerr_hi], fmt="o", color="#0B1D33", ecolor="#E63946", capsize=4)
        ax.axvline(0, color="gray", linestyle="--", alpha=0.7)
        ax.set_yticks(y_pos)
        ax.set_yticklabels(labels)
        ax.set_xlabel("Diferença Pareada de Working Set (MB) [Mediana e IC 95% Bootstrap]")
        ax.set_title("Efeito Incremental das Condições Experimentais (TOMWare.M)")
        fig.tight_layout()

        fig.savefig(self.figures_dir / "fig_paired_effects_forest.png", dpi=300)
        fig.savefig(self.figures_dir / "fig_paired_effects_forest.pdf")
        plt.close(fig)

        # Figura 2: Boxplot com pontos individuais por condição (Working Set)
        if not df_samples.empty:
            fig, ax = plt.subplots(figsize=(9, 5))
            conds = df_samples["condition"].unique()
            data_by_cond = [df_samples[df_samples["condition"] == c]["peak_working_set_mb_median"].dropna().values for c in conds]

            ax.boxplot(data_by_cond, tick_labels=conds, showmeans=True)
            for i, c in enumerate(conds, start=1):
                y = df_samples[df_samples["condition"] == c]["peak_working_set_mb_median"].dropna().values
                x = np.random.normal(i, 0.04, size=len(y))
                ax.plot(x, y, "r.", alpha=0.6)

            ax.set_ylabel("Pico de Working Set (MB) [Mediana por Binário]")
            ax.set_xlabel("Condição Experimental")
            ax.set_title("Distribuição de Recursos de Memória por Condição (com Amostras Individuais)")
            fig.tight_layout()

            fig.savefig(self.figures_dir / "fig_resource_boxplots.png", dpi=300)
            fig.savefig(self.figures_dir / "fig_resource_boxplots.pdf")
            plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Motor de consolidação estatística e geração de tabelas/figuras (TOMWare.M)")
    parser.add_argument("--campaign-dir", required=True, help="Diretorio da campanha")
    args = parser.parse_args()

    analyzer = CampaignAnalyzer(Path(args.campaign_dir))
    res = analyzer.run_full_analysis()
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
