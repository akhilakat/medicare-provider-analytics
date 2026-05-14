-- ============================================================
-- Medicare Provider Utilization Analytics
-- Script 01: Database Schema Setup
-- Author: Akhila K
-- Data Source: CMS Medicare Physician & Other Practitioners
-- ============================================================

-- Raw provider data table (mirrors CMS CSV structure)
CREATE TABLE IF NOT EXISTS medicare_providers_raw (
    npi                         VARCHAR(20),
    provider_last_name          VARCHAR(100),
    provider_first_name         VARCHAR(100),
    provider_credentials        VARCHAR(50),
    provider_gender             VARCHAR(10),
    provider_entity_type        VARCHAR(20),
    provider_street_address_1   VARCHAR(200),
    provider_city               VARCHAR(100),
    provider_state              VARCHAR(5),
    provider_zip                VARCHAR(20),
    provider_country            VARCHAR(50),
    provider_type               VARCHAR(100),
    medicare_participation_ind  VARCHAR(5),
    place_of_service            VARCHAR(10),
    hcpcs_code                  VARCHAR(20),
    hcpcs_description           VARCHAR(500),
    hcpcs_drug_indicator        VARCHAR(5),
    number_of_services          DECIMAL(18,2),
    number_of_medicare_benes    DECIMAL(18,2),
    number_of_distinct_benes    DECIMAL(18,2),
    average_submitted_chrg_amt  DECIMAL(18,2),
    average_medicare_allowed_amt DECIMAL(18,2),
    average_medicare_payment_amt DECIMAL(18,2),
    average_medicare_standard_amt DECIMAL(18,2)
);

-- Cleaned and enriched provider summary table
CREATE TABLE IF NOT EXISTS provider_summary (
    npi                         VARCHAR(20),
    provider_name               VARCHAR(200),
    provider_type               VARCHAR(100),
    provider_state              VARCHAR(5),
    provider_city               VARCHAR(100),
    total_services              DECIMAL(18,2),
    total_beneficiaries         DECIMAL(18,2),
    total_medicare_payment      DECIMAL(18,2),
    avg_payment_per_service     DECIMAL(18,2),
    avg_payment_per_bene        DECIMAL(18,2),
    unique_hcpcs_codes          INT,
    data_year                   INT
);

-- Specialty benchmark table (used for outlier detection)
CREATE TABLE IF NOT EXISTS specialty_benchmarks (
    provider_type               VARCHAR(100),
    avg_payment_per_service     DECIMAL(18,2),
    median_payment_per_service  DECIMAL(18,2),
    stddev_payment_per_service  DECIMAL(18,2),
    avg_services_per_bene       DECIMAL(18,2),
    median_services_per_bene    DECIMAL(18,2),
    stddev_services_per_bene    DECIMAL(18,2),
    provider_count              INT
);

-- Geographic summary table
CREATE TABLE IF NOT EXISTS geographic_summary (
    provider_state              VARCHAR(5),
    provider_type               VARCHAR(100),
    provider_count              INT,
    total_services              DECIMAL(18,2),
    total_beneficiaries         DECIMAL(18,2),
    total_medicare_payment      DECIMAL(18,2),
    avg_payment_per_service     DECIMAL(18,2),
    avg_payment_per_bene        DECIMAL(18,2)
);

-- Provider outlier flags table
CREATE TABLE IF NOT EXISTS provider_outliers (
    npi                         VARCHAR(20),
    provider_name               VARCHAR(200),
    provider_type               VARCHAR(100),
    provider_state              VARCHAR(5),
    avg_payment_per_bene        DECIMAL(18,2),
    specialty_avg_payment       DECIMAL(18,2),
    specialty_stddev_payment    DECIMAL(18,2),
    z_score_payment             DECIMAL(10,4),
    avg_services_per_bene       DECIMAL(18,2),
    specialty_avg_services      DECIMAL(18,2),
    z_score_services            DECIMAL(10,4),
    outlier_flag                VARCHAR(20),
    outlier_reason              VARCHAR(200)
);
