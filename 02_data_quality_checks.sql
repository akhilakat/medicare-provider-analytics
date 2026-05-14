-- ============================================================
-- Medicare Provider Utilization Analytics
-- Script 02: Data Quality Checks
-- Author: Akhila K
-- ============================================================
-- Run these checks BEFORE any analysis to confirm data integrity.
-- Every check should return 0 rows if data is clean.
-- ============================================================

-- CHECK 1: Null or missing NPI (primary key)
SELECT
    COUNT(*) AS missing_npi_count
FROM medicare_providers_raw
WHERE npi IS NULL
   OR TRIM(npi) = '';

-- CHECK 2: Invalid NPI format (should be 10 digits)
SELECT
    COUNT(*) AS invalid_npi_format
FROM medicare_providers_raw
WHERE LEN(TRIM(npi)) <> 10
   OR npi NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]';

-- CHECK 3: Negative payment amounts (should never occur)
SELECT
    COUNT(*) AS negative_payments
FROM medicare_providers_raw
WHERE average_medicare_payment_amt < 0
   OR average_medicare_allowed_amt < 0
   OR average_submitted_chrg_amt < 0;

-- CHECK 4: Payment exceeds submitted charge (logic error)
SELECT
    COUNT(*) AS payment_exceeds_charge
FROM medicare_providers_raw
WHERE average_medicare_payment_amt > average_submitted_chrg_amt;

-- CHECK 5: Zero or null service counts
SELECT
    COUNT(*) AS zero_service_records
FROM medicare_providers_raw
WHERE number_of_services IS NULL
   OR number_of_services <= 0;

-- CHECK 6: Missing provider type (needed for specialty benchmarks)
SELECT
    COUNT(*) AS missing_provider_type
FROM medicare_providers_raw
WHERE provider_type IS NULL
   OR TRIM(provider_type) = '';

-- CHECK 7: Invalid state codes (should be 2-letter US state)
SELECT
    provider_state,
    COUNT(*) AS record_count
FROM medicare_providers_raw
WHERE LEN(TRIM(provider_state)) <> 2
   OR provider_state NOT IN (
       'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
       'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
       'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
       'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
       'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
       'DC','PR','GU','VI','MP','AS'
   )
GROUP BY provider_state
ORDER BY record_count DESC;

-- CHECK 8: Duplicate NPI + HCPCS combinations
SELECT
    npi,
    hcpcs_code,
    place_of_service,
    COUNT(*) AS duplicate_count
FROM medicare_providers_raw
GROUP BY npi, hcpcs_code, place_of_service
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- SUMMARY: Overall data quality scorecard
SELECT
    COUNT(*)                                            AS total_records,
    COUNT(DISTINCT npi)                                 AS unique_providers,
    COUNT(DISTINCT provider_type)                       AS unique_specialties,
    COUNT(DISTINCT provider_state)                      AS unique_states,
    COUNT(DISTINCT hcpcs_code)                          AS unique_hcpcs_codes,
    SUM(number_of_services)                             AS total_services,
    SUM(number_of_medicare_benes)                       AS total_beneficiaries,
    SUM(average_medicare_payment_amt * number_of_services) AS total_medicare_spend,
    ROUND(
        100.0 * SUM(CASE WHEN npi IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                   AS pct_missing_npi,
    ROUND(
        100.0 * SUM(CASE WHEN provider_type IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                   AS pct_missing_specialty
FROM medicare_providers_raw;
