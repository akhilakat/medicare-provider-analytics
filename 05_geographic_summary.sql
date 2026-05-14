-- ============================================================
-- Medicare Provider Utilization Analytics
-- Script 05: Geographic Analysis
-- Author: Akhila K
-- Business Question: How does Medicare spend and utilization
-- vary across states and regions?
-- ============================================================

-- STEP 1: Build state-level geographic summary
INSERT INTO geographic_summary
SELECT
    ps.provider_state,
    ps.provider_type,
    COUNT(DISTINCT ps.npi)                                     AS provider_count,
    SUM(ps.total_services)                                     AS total_services,
    SUM(ps.total_beneficiaries)                                AS total_beneficiaries,
    SUM(ps.total_medicare_payment)                             AS total_medicare_payment,
    CASE
        WHEN SUM(ps.total_services) > 0
        THEN SUM(ps.total_medicare_payment) / SUM(ps.total_services)
        ELSE 0
    END                                                        AS avg_payment_per_service,
    CASE
        WHEN SUM(ps.total_beneficiaries) > 0
        THEN SUM(ps.total_medicare_payment) / SUM(ps.total_beneficiaries)
        ELSE 0
    END                                                        AS avg_payment_per_bene
FROM provider_summary ps
GROUP BY ps.provider_state, ps.provider_type;

-- STEP 2: State ranking by total Medicare spend
SELECT
    provider_state,
    COUNT(DISTINCT provider_type)                              AS specialties_present,
    SUM(provider_count)                                        AS total_providers,
    ROUND(SUM(total_services) / 1000000.0, 2)                 AS total_services_millions,
    ROUND(SUM(total_beneficiaries) / 1000000.0, 2)            AS total_benes_millions,
    ROUND(SUM(total_medicare_payment) / 1000000000.0, 3)      AS total_spend_billions,
    ROUND(SUM(total_medicare_payment) / NULLIF(SUM(total_beneficiaries), 0), 2)
                                                               AS avg_payment_per_bene,
    RANK() OVER (ORDER BY SUM(total_medicare_payment) DESC)    AS spend_rank
FROM geographic_summary
GROUP BY provider_state
ORDER BY total_spend_billions DESC;

-- STEP 3: States with highest cost per beneficiary
-- (controls for state population size — reveals true cost intensity)
WITH state_totals AS (
    SELECT
        provider_state,
        SUM(total_medicare_payment)                            AS total_spend,
        SUM(total_beneficiaries)                               AS total_benes,
        SUM(total_services)                                    AS total_services,
        SUM(total_medicare_payment)
            / NULLIF(SUM(total_beneficiaries), 0)              AS cost_per_bene
    FROM geographic_summary
    GROUP BY provider_state
),
national_avg AS (
    SELECT AVG(cost_per_bene) AS national_cost_per_bene
    FROM state_totals
)
SELECT
    st.provider_state,
    ROUND(st.cost_per_bene, 2)                                AS cost_per_bene,
    ROUND(na.national_cost_per_bene, 2)                       AS national_avg,
    ROUND(
        100.0 * (st.cost_per_bene - na.national_cost_per_bene)
        / NULLIF(na.national_cost_per_bene, 0), 1
    )                                                          AS pct_above_national_avg,
    RANK() OVER (ORDER BY st.cost_per_bene DESC)               AS cost_rank
FROM state_totals st
CROSS JOIN national_avg na
ORDER BY cost_per_bene DESC;

-- STEP 4: Regional grouping (Census regions)
-- Adds context for regional pattern analysis
SELECT
    CASE
        WHEN provider_state IN ('CT','ME','MA','NH','RI','VT','NJ','NY','PA')
            THEN 'Northeast'
        WHEN provider_state IN ('IL','IN','MI','OH','WI','IA','KS','MN','MO','NE','ND','SD')
            THEN 'Midwest'
        WHEN provider_state IN ('DE','FL','GA','MD','NC','SC','VA','DC','WV',
                                 'AL','KY','MS','TN','AR','LA','OK','TX')
            THEN 'South'
        WHEN provider_state IN ('AZ','CO','ID','MT','NV','NM','UT','WY',
                                 'AK','CA','HI','OR','WA')
            THEN 'West'
        ELSE 'Territory/Other'
    END                                                        AS census_region,
    COUNT(DISTINCT provider_state)                             AS state_count,
    SUM(provider_count)                                        AS total_providers,
    ROUND(SUM(total_medicare_payment) / 1000000000.0, 3)      AS total_spend_billions,
    ROUND(
        SUM(total_medicare_payment) / NULLIF(SUM(total_beneficiaries), 0), 2
    )                                                          AS avg_cost_per_bene
FROM geographic_summary
GROUP BY
    CASE
        WHEN provider_state IN ('CT','ME','MA','NH','RI','VT','NJ','NY','PA')
            THEN 'Northeast'
        WHEN provider_state IN ('IL','IN','MI','OH','WI','IA','KS','MN','MO','NE','ND','SD')
            THEN 'Midwest'
        WHEN provider_state IN ('DE','FL','GA','MD','NC','SC','VA','DC','WV',
                                 'AL','KY','MS','TN','AR','LA','OK','TX')
            THEN 'South'
        WHEN provider_state IN ('AZ','CO','ID','MT','NV','NM','UT','WY',
                                 'AK','CA','HI','OR','WA')
            THEN 'West'
        ELSE 'Territory/Other'
    END
ORDER BY total_spend_billions DESC;
