"""
Medicare Provider Utilization Analytics
Script 01: Data Cleaning & Preparation
Author: Akhila K

Loads the raw CMS Medicare Physician & Other Practitioners CSV,
performs cleaning and validation, and exports a clean version
ready for SQL loading and Power BI / Tableau connection.

Data source:
https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners
"""

import pandas as pd
import numpy as np
import os
import logging
from datetime import datetime

# ── Logging setup ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("data_cleaning.log")
    ]
)
log = logging.getLogger(__name__)

# ── Config ─────────────────────────────────────────────────────
RAW_DATA_PATH   = "../data/Medicare_Physician_Other_Practitioners_Raw.csv"
CLEAN_DATA_PATH = "../data/Medicare_Providers_Clean.csv"
SUMMARY_PATH    = "../data/Provider_Summary.csv"

# Column mapping from CMS CSV headers to our standard names
COLUMN_MAP = {
    "Rndrng_NPI":                   "npi",
    "Rndrng_Prvdr_Last_Org_Name":   "provider_last_name",
    "Rndrng_Prvdr_First_Name":      "provider_first_name",
    "Rndrng_Prvdr_Crdntls":         "credentials",
    "Rndrng_Prvdr_Gndr":            "gender",
    "Rndrng_Prvdr_Ent_Cd":          "entity_type",
    "Rndrng_Prvdr_St1":             "street_address",
    "Rndrng_Prvdr_City":            "city",
    "Rndrng_Prvdr_State_Abrvtn":    "state",
    "Rndrng_Prvdr_Zip5":            "zip_code",
    "Rndrng_Prvdr_Type":            "provider_type",
    "HCPCS_Cd":                     "hcpcs_code",
    "HCPCS_Desc":                   "hcpcs_description",
    "HCPCS_Drug_Ind":               "drug_indicator",
    "Place_Of_Srvc":                "place_of_service",
    "Tot_Srvcs":                    "total_services",
    "Tot_Benes":                    "total_beneficiaries",
    "Tot_Bene_Day_Srvcs":           "total_bene_day_services",
    "Avg_Sbmtd_Chrg":               "avg_submitted_charge",
    "Avg_Mdcr_Alowd_Amt":           "avg_medicare_allowed",
    "Avg_Mdcr_Pymt_Amt":            "avg_medicare_payment",
    "Avg_Mdcr_Stdzd_Amt":           "avg_medicare_standardized",
}

VALID_STATES = {
    "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA",
    "HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
    "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
    "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
    "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY",
    "DC","PR","GU","VI","MP","AS"
}


def load_raw_data(path: str) -> pd.DataFrame:
    """Load raw CMS CSV file."""
    log.info(f"Loading raw data from: {path}")
    df = pd.read_csv(
        path,
        dtype={"Rndrng_NPI": str, "Rndrng_Prvdr_Zip5": str, "HCPCS_Cd": str},
        low_memory=False
    )
    log.info(f"Loaded {len(df):,} records, {df.shape[1]} columns")
    return df


def rename_and_select(df: pd.DataFrame) -> pd.DataFrame:
    """Keep only needed columns and rename to standard names."""
    available = {k: v for k, v in COLUMN_MAP.items() if k in df.columns}
    missing   = [k for k in COLUMN_MAP if k not in df.columns]
    if missing:
        log.warning(f"Missing expected columns: {missing}")
    df = df[list(available.keys())].rename(columns=available)
    log.info(f"Selected {len(available)} columns")
    return df


def clean_data(df: pd.DataFrame) -> pd.DataFrame:
    """Apply cleaning rules and log each step."""
    original_count = len(df)

    # 1. Drop records with null NPI
    df = df.dropna(subset=["npi"])
    log.info(f"After dropping null NPI: {len(df):,} records (-{original_count - len(df):,})")

    # 2. Standardize NPI to string, strip whitespace
    df["npi"] = df["npi"].str.strip()

    # 3. Keep only valid 10-digit NPIs
    before = len(df)
    df = df[df["npi"].str.match(r"^\d{10}$", na=False)]
    log.info(f"After NPI format filter: {len(df):,} records (-{before - len(df):,})")

    # 4. Standardize state codes to uppercase
    df["state"] = df["state"].str.strip().str.upper()

    # 5. Filter to US states only (remove territories for this analysis)
    before = len(df)
    df = df[df["state"].isin(VALID_STATES)]
    log.info(f"After state filter: {len(df):,} records (-{before - len(df):,})")

    # 6. Drop records with null or zero services
    before = len(df)
    df = df[df["total_services"].notna() & (df["total_services"] > 0)]
    log.info(f"After zero-service filter: {len(df):,} records (-{before - len(df):,})")

    # 7. Drop records with negative payment amounts (data error)
    before = len(df)
    df = df[
        (df["avg_medicare_payment"] >= 0) &
        (df["avg_medicare_allowed"]  >= 0) &
        (df["avg_submitted_charge"]  >= 0)
    ]
    log.info(f"After negative payment filter: {len(df):,} records (-{before - len(df):,})")

    # 8. Drop records where payment exceeds submitted charge
    before = len(df)
    df = df[df["avg_medicare_payment"] <= df["avg_submitted_charge"]]
    log.info(f"After payment logic filter: {len(df):,} records (-{before - len(df):,})")

    # 9. Fill missing provider type with 'Unknown'
    df["provider_type"] = df["provider_type"].fillna("Unknown").str.strip()

    # 10. Clean provider name fields
    for col in ["provider_last_name", "provider_first_name", "city"]:
        if col in df.columns:
            df[col] = df[col].fillna("").str.strip().str.title()

    # 11. Derive full provider name
    df["provider_name"] = (
        df["provider_last_name"].str.strip() + ", " +
        df["provider_first_name"].str.strip()
    ).str.strip(", ")

    # 12. Derive total payment per row
    df["total_payment"] = df["avg_medicare_payment"] * df["total_services"]

    log.info(f"Cleaning complete. Final record count: {len(df):,}")
    return df


def build_provider_summary(df: pd.DataFrame) -> pd.DataFrame:
    """Aggregate to provider level for dashboard use."""
    log.info("Building provider-level summary...")
    summary = df.groupby(["npi", "provider_name", "provider_type", "state", "city"]).agg(
        total_services      = ("total_services",  "sum"),
        total_beneficiaries = ("total_beneficiaries", "sum"),
        total_payment       = ("total_payment",   "sum"),
        unique_hcpcs_codes  = ("hcpcs_code",      "nunique"),
    ).reset_index()

    summary["avg_payment_per_service"] = np.where(
        summary["total_services"] > 0,
        summary["total_payment"] / summary["total_services"], 0
    )
    summary["avg_payment_per_bene"] = np.where(
        summary["total_beneficiaries"] > 0,
        summary["total_payment"] / summary["total_beneficiaries"], 0
    )
    summary["services_per_bene"] = np.where(
        summary["total_beneficiaries"] > 0,
        summary["total_services"] / summary["total_beneficiaries"], 0
    )

    log.info(f"Provider summary: {len(summary):,} unique providers")
    return summary


def run_final_validation(df: pd.DataFrame, summary: pd.DataFrame) -> None:
    """Print a data quality scorecard to the log."""
    log.info("=== FINAL VALIDATION SCORECARD ===")
    log.info(f"Total clean records:       {len(df):,}")
    log.info(f"Unique providers:          {df['npi'].nunique():,}")
    log.info(f"Unique specialties:        {df['provider_type'].nunique():,}")
    log.info(f"Unique states:             {df['state'].nunique():,}")
    log.info(f"Total Medicare spend:      ${df['total_payment'].sum():,.0f}")
    log.info(f"Null NPI in clean data:    {df['npi'].isna().sum()}")
    log.info(f"Negative payments:         {(df['avg_medicare_payment'] < 0).sum()}")
    log.info(f"Provider summary rows:     {len(summary):,}")


def main():
    log.info("Starting Medicare data cleaning pipeline")
    start = datetime.now()

    df      = load_raw_data(RAW_DATA_PATH)
    df      = rename_and_select(df)
    df      = clean_data(df)
    summary = build_provider_summary(df)

    run_final_validation(df, summary)

    df.to_csv(CLEAN_DATA_PATH, index=False)
    log.info(f"Clean data saved to: {CLEAN_DATA_PATH}")

    summary.to_csv(SUMMARY_PATH, index=False)
    log.info(f"Provider summary saved to: {SUMMARY_PATH}")

    elapsed = (datetime.now() - start).seconds
    log.info(f"Pipeline complete in {elapsed}s")


if __name__ == "__main__":
    main()
