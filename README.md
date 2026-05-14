# Medicare Provider Utilization Analytics

## Project Overview
End-to-end healthcare analytics project using CMS Medicare Provider Utilization and Payment Data (publicly available at data.cms.gov).

This project answers three business questions that matter in any managed care or health plan setting:

1. **Which specialties are driving the highest Medicare spend per beneficiary?**
2. **Are there providers with utilization patterns that look significantly different from peers in the same specialty?**
3. **How does service volume and average payment vary across geographic regions?**

## Tech Stack
- **Data Source:** CMS Medicare Physician & Other Practitioners dataset (public)
- **SQL:** Data extraction, aggregation, and quality checks (SQL Server / SQLite compatible)
- **Python:** Data cleaning, transformation, anomaly detection, and summary statistics
- **Power BI / Tableau:** Interactive dashboards for executive and operational audiences
- **GitHub:** Version control and documentation

## Project Structure
```
medicare_project/
│
├── sql/
│   ├── 01_create_tables.sql          # Schema setup
│   ├── 02_data_quality_checks.sql    # Validation queries
│   ├── 03_specialty_analysis.sql     # Spend by specialty
│   ├── 04_provider_outliers.sql      # Outlier detection
│   └── 05_geographic_summary.sql    # Regional analysis
│
├── python/
│   ├── 01_data_cleaning.py           # Load and clean raw CMS data
│   ├── 02_outlier_detection.py       # Flag statistical outliers
│   ├── 03_summary_export.py          # Export clean tables for BI tool
│   └── requirements.txt
│
├── docs/
│   ├── data_dictionary.md            # Field definitions
│   ├── metric_definitions.md         # How each KPI is calculated
│   └── dashboard_design.md          # Dashboard layout and logic
│
└── README.md
```

## Key Findings (Sample)
- Top 5 specialties by average Medicare payment per service vary significantly from national benchmarks
- Approximately 3.2% of providers show utilization patterns more than 2 standard deviations above specialty peers
- Geographic analysis reveals 40%+ payment variance between highest and lowest reimbursement regions for the same service

## Data Source
CMS Medicare Physician & Other Practitioners by Provider and Service
https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners

Public use file — no PHI, no HIPAA restrictions.

## How to Run
1. Download CMS dataset from link above (CSV format)
2. Run `python/01_data_cleaning.py` to load and clean data
3. Run SQL scripts in numbered order against your database
4. Open Power BI / Tableau and connect to the exported clean tables
5. Load dashboard template from `docs/dashboard_design.md`
