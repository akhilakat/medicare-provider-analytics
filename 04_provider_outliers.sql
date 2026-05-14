-- ============================================================
-- Medicare Provider Utilization Analytics
-- Script 04: Provider Outlier Detection
-- Author: Akhila K
-- Business Question: Which providers show utilization patterns
-- significantly different from specialty peers?
-- Method: Z-score analysis (flag providers > 2 std deviations
-- above specialty mean on payment per bene OR services per bene)
-- ============================================================

INSERT INTO provider_outliers
SELECT
    ps.npi,
    ps.provider_name,
    ps.provider_type,
    ps.provider_state,

    -- Provider metrics
    ROUND(ps.avg_payment_per_bene, 2)                          AS avg_payment_per_bene,

    -- Specialty benchmarks
    ROUND(sb.avg_payment_per_service, 2)                       AS specialty_avg_payment,
    ROUND(sb.stddev_payment_per_service, 2)                    AS specialty_stddev_payment,

    -- Z-score: how many standard deviations above specialty mean
    ROUND(
        (ps.avg_payment_per_bene - sb.avg_payment_per_service)
        / NULLIF(sb.stddev_payment_per_service, 0),
        4
    )                                                          AS z_score_payment,

    ROUND(ps.total_services / NULLIF(ps.total_beneficiaries, 0), 2)
                                                               AS avg_services_per_bene,
    ROUND(sb.avg_services_per_bene, 2)                        AS specialty_avg_services,

    ROUND(
        (ps.total_services / NULLIF(ps.total_beneficiaries, 0) - sb.avg_services_per_bene)
        / NULLIF(sb.stddev_services_per_bene, 0),
        4
    )                                                          AS z_score_services,

    -- Flag type
    CASE
        WHEN (ps.avg_payment_per_bene - sb.avg_payment_per_service)
             / NULLIF(sb.stddev_payment_per_service, 0) > 3
         AND (ps.total_services / NULLIF(ps.total_beneficiaries, 0) - sb.avg_services_per_bene)
             / NULLIF(sb.stddev_services_per_bene, 0) > 3
        THEN 'HIGH RISK'

        WHEN (ps.avg_payment_per_bene - sb.avg_payment_per_service)
             / NULLIF(sb.stddev_payment_per_service, 0) > 2
         OR  (ps.total_services / NULLIF(ps.total_beneficiaries, 0) - sb.avg_services_per_bene)
             / NULLIF(sb.stddev_services_per_bene, 0) > 2
        THEN 'REVIEW'

        ELSE 'NORMAL'
    END                                                        AS outlier_flag,

    -- Human-readable reason
    CASE
        WHEN (ps.avg_payment_per_bene - sb.avg_payment_per_service)
             / NULLIF(sb.stddev_payment_per_service, 0) > 3
         AND (ps.total_services / NULLIF(ps.total_beneficiaries, 0) - sb.avg_services_per_bene)
             / NULLIF(sb.stddev_services_per_bene, 0) > 3
        THEN 'Both payment per bene and services per bene exceed 3 SD above specialty mean'

        WHEN (ps.avg_payment_per_bene - sb.avg_payment_per_service)
             / NULLIF(sb.stddev_payment_per_service, 0) > 2
        THEN 'Payment per beneficiary exceeds 2 SD above specialty mean'

        WHEN (ps.total_services / NULLIF(ps.total_beneficiaries, 0) - sb.avg_services_per_bene)
             / NULLIF(sb.stddev_services_per_bene, 0) > 2
        THEN 'Services per beneficiary exceeds 2 SD above specialty mean'

        ELSE 'Within normal range'
    END                                                        AS outlier_reason

FROM provider_summary ps
JOIN specialty_benchmarks sb
    ON ps.provider_type = sb.provider_type
WHERE ps.total_beneficiaries >= 11;

-- Summary: Outlier counts by flag level
SELECT
    outlier_flag,
    COUNT(*)                                                   AS provider_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)        AS pct_of_total
FROM provider_outliers
GROUP BY outlier_flag
ORDER BY provider_count DESC;

-- Top 25 highest z-score providers for review
SELECT TOP 25
    provider_name,
    provider_type,
    provider_state,
    ROUND(avg_payment_per_bene, 2)                            AS payment_per_bene,
    ROUND(specialty_avg_payment, 2)                           AS specialty_avg,
    ROUND(z_score_payment, 2)                                 AS z_score,
    outlier_flag,
    outlier_reason
FROM provider_outliers
WHERE outlier_flag IN ('HIGH RISK', 'REVIEW')
ORDER BY z_score_payment DESC;
