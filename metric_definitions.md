# Metric Definitions

All metrics used in this project are defined here to ensure
consistency across SQL, Python, and the Power BI dashboard.

---

## Core Metrics

### avg_payment_per_service
**Definition:** Total Medicare payment divided by total services rendered.
**Formula:** `SUM(avg_medicare_payment * total_services) / SUM(total_services)`
**Use case:** Measures cost efficiency per procedure. High values may indicate high-complexity
or high-cost service mix.

### avg_payment_per_bene
**Definition:** Total Medicare payment divided by total distinct beneficiaries.
**Formula:** `SUM(total_payment) / SUM(total_beneficiaries)`
**Use case:** Normalizes cost by patient volume. Better than total spend for comparing
providers of different sizes. Primary metric for outlier detection.

### services_per_bene
**Definition:** Total services divided by total distinct beneficiaries.
**Formula:** `SUM(total_services) / SUM(total_beneficiaries)`
**Use case:** Measures service intensity. Unusually high values may indicate over-utilization
relative to specialty peers.

---

## Outlier Detection Metrics

### z_payment
**Definition:** How many standard deviations a provider's avg_payment_per_bene
is above (positive) or below (negative) their specialty mean.
**Formula:** `(provider_avg_payment_per_bene - specialty_mean) / specialty_std_dev`
**Threshold:** > 2.0 = REVIEW flag, > 3.0 = HIGH RISK flag

### z_services
**Definition:** Same z-score methodology applied to services_per_bene.
**Formula:** `(provider_services_per_bene - specialty_mean) / specialty_std_dev`
**Threshold:** > 2.0 = REVIEW flag, > 3.0 = HIGH RISK flag

---

## Data Quality Notes

- CMS suppresses provider records with fewer than 11 beneficiaries to protect patient privacy.
  These records are excluded from outlier analysis.
- Specialty benchmarks require a minimum of 30 providers per specialty to ensure
  statistically meaningful mean and standard deviation calculations.
- Payment amounts represent Medicare fee-for-service payments only.
  They do not include Medicare Advantage or supplemental insurance payments.

---

## Data Source

CMS Medicare Physician & Other Practitioners by Provider and Service
- Public use file, no PHI
- Available at: https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners
- Updated annually
