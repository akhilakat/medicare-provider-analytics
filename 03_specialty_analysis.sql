-- ============================================================
-- Medicare Provider Utilization Analytics
-- Script 03: Specialty-Level Spend & Utilization Analysis
-- Author: Akhila K
-- Business Question: Which specialties drive the highest
-- Medicare spend, and how does cost per beneficiary vary?
-- ============================================================

-- STEP 1: Build provider-level summary
INSERT INTO provider_summary
SELECT
    r.npi,
    TRIM(r.provider_last_name + ', ' + r.provider_first_name) AS provider_name,
    r.provider_type,
    r.provider_state,
    r.provider_city,
    SUM(r.number_of_services)                                  AS total_services,
    SUM(r.number_of_distinct_benes)                            AS total_beneficiaries,
    SUM(r.average_medicare_payment_amt * r.number_of_services) AS total_medicare_payment,
    CASE
        WHEN SUM(r.number_of_services) > 0
        THEN SUM(r.average_medicare_payment_amt * r.number_of_services)
             / SUM(r.number_of_services)
        ELSE 0
    END                                                        AS avg_payment_per_service,
    CASE
        WHEN SUM(r.number_of_distinct_benes) > 0
        THEN SUM(r.average_medicare_payment_amt * r.number_of_services)
             / SUM(r.number_of_distinct_benes)
        ELSE 0
    END                                                        AS avg_payment_per_bene,
    COUNT(DISTINCT r.hcpcs_code)                               AS unique_hcpcs_codes,
    2023                                                       AS data_year
FROM medicare_providers_raw r
WHERE r.number_of_services > 0
  AND r.average_medicare_payment_amt >= 0
  AND r.provider_type IS NOT NULL
GROUP BY
    r.npi,
    r.provider_last_name,
    r.provider_first_name,
    r.provider_type,
    r.provider_state,
    r.provider_city;

-- STEP 2: Build specialty benchmark table
INSERT INTO specialty_benchmarks
SELECT
    ps.provider_type,
    AVG(ps.avg_payment_per_service)                            AS avg_payment_per_service,
    -- Median approximation using PERCENTILE_CONT
    PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY ps.avg_payment_per_service)                  AS median_payment_per_service,
    STDEV(ps.avg_payment_per_service)                          AS stddev_payment_per_service,
    AVG(ps.total_services / NULLIF(ps.total_beneficiaries, 0)) AS avg_services_per_bene,
    PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY ps.total_services / NULLIF(ps.total_beneficiaries, 0))
                                                               AS median_services_per_bene,
    STDEV(ps.total_services / NULLIF(ps.total_beneficiaries, 0))
                                                               AS stddev_services_per_bene,
    COUNT(*)                                                   AS provider_count
FROM provider_summary ps
WHERE ps.total_beneficiaries >= 11  -- CMS suppresses records < 11 benes
GROUP BY ps.provider_type
HAVING COUNT(*) >= 30;              -- Only specialties with enough providers for valid benchmarks

-- STEP 3: Top 20 specialties by total Medicare spend
SELECT TOP 20
    sb.provider_type                                           AS specialty,
    sb.provider_count,
    ROUND(SUM(ps.total_medicare_payment) / 1000000, 2)        AS total_spend_millions,
    ROUND(sb.avg_payment_per_service, 2)                      AS avg_payment_per_service,
    ROUND(sb.median_payment_per_service, 2)                   AS median_payment_per_service,
    ROUND(AVG(ps.avg_payment_per_bene), 2)                    AS avg_payment_per_bene,
    ROUND(sb.avg_services_per_bene, 2)                        AS avg_services_per_bene
FROM provider_summary ps
JOIN specialty_benchmarks sb
    ON ps.provider_type = sb.provider_type
GROUP BY
    sb.provider_type,
    sb.provider_count,
    sb.avg_payment_per_service,
    sb.median_payment_per_service,
    sb.avg_services_per_bene
ORDER BY total_spend_millions DESC;

-- STEP 4: Specialties with highest cost per beneficiary
-- (flags high-cost, potentially high-intensity specialties)
SELECT TOP 20
    sb.provider_type                                           AS specialty,
    sb.provider_count,
    ROUND(AVG(ps.avg_payment_per_bene), 2)                    AS avg_payment_per_bene,
    ROUND(sb.avg_services_per_bene, 2)                        AS avg_services_per_bene,
    ROUND(sb.stddev_payment_per_service, 2)                   AS payment_variability
FROM provider_summary ps
JOIN specialty_benchmarks sb
    ON ps.provider_type = sb.provider_type
GROUP BY
    sb.provider_type,
    sb.provider_count,
    sb.avg_services_per_bene,
    sb.stddev_payment_per_service
ORDER BY avg_payment_per_bene DESC;
