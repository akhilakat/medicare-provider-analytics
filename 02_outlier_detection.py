"""
Medicare Provider Utilization Analytics
Script 02: Statistical Outlier Detection
Author: Akhila K

Uses z-score analysis to identify providers whose payment
per beneficiary or services per beneficiary falls significantly
outside their specialty peer group.

Outputs a flagged provider table for dashboard visualization.
"""

import pandas as pd
import numpy as np
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger(__name__)

SUMMARY_PATH  = "../data/Provider_Summary.csv"
OUTLIER_PATH  = "../data/Provider_Outliers.csv"
BENCHMARK_PATH = "../data/Specialty_Benchmarks.csv"

MIN_BENES_THRESHOLD = 11    # CMS suppresses counts < 11 — exclude from analysis
MIN_SPECIALTY_COUNT = 30    # Need at least 30 providers for a valid specialty benchmark
Z_SCORE_REVIEW      = 2.0   # Flag for review
Z_SCORE_HIGH_RISK   = 3.0   # Flag as high risk


def load_summary(path: str) -> pd.DataFrame:
    log.info(f"Loading provider summary from: {path}")
    df = pd.read_csv(path)
    log.info(f"Loaded {len(df):,} providers")
    return df


def build_specialty_benchmarks(df: pd.DataFrame) -> pd.DataFrame:
    """Calculate mean, median, and std dev for each specialty."""
    log.info("Building specialty benchmarks...")

    # Filter to providers with enough beneficiaries
    df_filtered = df[df["total_beneficiaries"] >= MIN_BENES_THRESHOLD].copy()

    benchmarks = (
        df_filtered
        .groupby("provider_type")
        .agg(
            avg_payment_per_bene    = ("avg_payment_per_bene",    "mean"),
            median_payment_per_bene = ("avg_payment_per_bene",    "median"),
            std_payment_per_bene    = ("avg_payment_per_bene",    "std"),
            avg_services_per_bene   = ("services_per_bene",       "mean"),
            median_services_per_bene= ("services_per_bene",       "median"),
            std_services_per_bene   = ("services_per_bene",       "std"),
            provider_count          = ("npi",                     "count"),
        )
        .reset_index()
    )

    # Only keep specialties with enough providers for valid statistics
    benchmarks = benchmarks[benchmarks["provider_count"] >= MIN_SPECIALTY_COUNT]
    log.info(f"Built benchmarks for {len(benchmarks):,} specialties")
    return benchmarks


def calculate_z_scores(df: pd.DataFrame, benchmarks: pd.DataFrame) -> pd.DataFrame:
    """Merge benchmarks onto provider summary and calculate z-scores."""
    log.info("Calculating z-scores...")

    df_filtered = df[df["total_beneficiaries"] >= MIN_BENES_THRESHOLD].copy()
    merged = df_filtered.merge(benchmarks, on="provider_type", how="inner")

    # Z-score: (provider value - specialty mean) / specialty std dev
    merged["z_payment"] = np.where(
        merged["std_payment_per_bene"] > 0,
        (merged["avg_payment_per_bene"] - merged["avg_payment_per_bene_x"]) /
        merged["std_payment_per_bene"],
        0
    )

    merged["z_services"] = np.where(
        merged["std_services_per_bene"] > 0,
        (merged["services_per_bene"] - merged["avg_services_per_bene"]) /
        merged["std_services_per_bene"],
        0
    )

    log.info(f"Z-scores calculated for {len(merged):,} providers")
    return merged


def flag_outliers(df: pd.DataFrame) -> pd.DataFrame:
    """Apply outlier flags based on z-score thresholds."""

    def assign_flag(row):
        if row["z_payment"] > Z_SCORE_HIGH_RISK and row["z_services"] > Z_SCORE_HIGH_RISK:
            return "HIGH RISK", "Both payment and services per bene exceed 3 SD above specialty mean"
        elif row["z_payment"] > Z_SCORE_HIGH_RISK:
            return "HIGH RISK", f"Payment per bene {row['z_payment']:.1f} SD above specialty mean"
        elif row["z_services"] > Z_SCORE_HIGH_RISK:
            return "HIGH RISK", f"Services per bene {row['z_services']:.1f} SD above specialty mean"
        elif row["z_payment"] > Z_SCORE_REVIEW:
            return "REVIEW", f"Payment per bene {row['z_payment']:.1f} SD above specialty mean"
        elif row["z_services"] > Z_SCORE_REVIEW:
            return "REVIEW", f"Services per bene {row['z_services']:.1f} SD above specialty mean"
        else:
            return "NORMAL", "Within normal range"

    flags = df.apply(assign_flag, axis=1, result_type="expand")
    df["outlier_flag"]   = flags[0]
    df["outlier_reason"] = flags[1]

    # Summary
    summary = df["outlier_flag"].value_counts()
    log.info("Outlier flag summary:")
    for flag, count in summary.items():
        pct = 100 * count / len(df)
        log.info(f"  {flag:12s}: {count:,} providers ({pct:.1f}%)")

    return df


def export_results(df: pd.DataFrame, benchmarks: pd.DataFrame) -> None:
    output_cols = [
        "npi", "provider_name", "provider_type", "state", "city",
        "total_services", "total_beneficiaries", "total_payment",
        "avg_payment_per_bene", "services_per_bene",
        "avg_payment_per_bene_x", "std_payment_per_bene",
        "z_payment", "z_services",
        "outlier_flag", "outlier_reason"
    ]
    output_cols = [c for c in output_cols if c in df.columns]
    df[output_cols].to_csv(OUTLIER_PATH, index=False)
    log.info(f"Outlier results saved to: {OUTLIER_PATH}")

    benchmarks.to_csv(BENCHMARK_PATH, index=False)
    log.info(f"Specialty benchmarks saved to: {BENCHMARK_PATH}")


def main():
    summary    = load_summary(SUMMARY_PATH)
    benchmarks = build_specialty_benchmarks(summary)
    scored     = calculate_z_scores(summary, benchmarks)
    flagged    = flag_outliers(scored)
    export_results(flagged, benchmarks)
    log.info("Outlier detection complete.")


if __name__ == "__main__":
    main()
