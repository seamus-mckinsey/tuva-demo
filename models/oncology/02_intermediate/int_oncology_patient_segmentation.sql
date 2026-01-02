{{
    config(
        materialized='table',
        tags=['oncology', 'intermediate']
    )
}}

with patient_spend as (

    /*
    Aggregate total spend and claim counts per patient.
    */
    select
        person_id,
        sum(paid_amount) as total_paid_amount,
        sum(allowed_amount) as total_allowed_amount,
        sum(charge_amount) as total_charge_amount,
        count(distinct claim_id) as total_claim_count,
        count(*) as total_claim_line_count,
        min(claim_start_date) as first_claim_date,
        max(claim_end_date) as last_claim_date
    from {{ ref('stg_oncology_claims') }}
    group by person_id

),

spend_buckets as (

    /*
    Classify patients into buckets based on how much they've spent.
    */
    select
        person_id,
        total_paid_amount,
        total_allowed_amount,
        total_charge_amount,
        total_claim_count,
        total_claim_line_count,
        first_claim_date,
        last_claim_date,
        case
            when total_paid_amount < 10000 then 'Low Spend (<$10K)'
            when total_paid_amount < 50000 then 'Medium Spend ($10K-$50K)'
            when total_paid_amount < 100000 then 'High Spend ($50K-$100K)'
            when total_paid_amount < 250000 then 'Very High Spend ($100K-$250K)'
            else 'Catastrophic Spend (>$250K)'
        end as spend_bucket,
        case
            when total_paid_amount < 10000 then 1
            when total_paid_amount < 50000 then 2
            when total_paid_amount < 100000 then 3
            when total_paid_amount < 250000 then 4
            else 5
        end as spend_bucket_rank
    from patient_spend
),

patient_cancer_types as (

    /*
    Aggregate all cancer types per patient.
    */
    select
        person_id,
        string_agg(distinct cancer_type, ', ') as all_cancer_types,
        count(distinct cancer_type) as cancer_type_count
    from {{ ref('stg_oncology_conditions') }}
    group by person_id
)

select
    cohorts.person_id,
    cohorts.first_name,
    cohorts.last_name,
    cohorts.gender,
    cohorts.race,
    cohorts.state,
    cohorts.zip_code,
    cohorts.age_years,
    cohorts.age_group,
    cohorts.is_deceased,
    cohorts.primary_cancer_type,
    patient_cancer_types.all_cancer_types,
    patient_cancer_types.cancer_type_count,
    cohorts.has_active_cancer,
    cohorts.first_cancer_date,
    cohorts.most_recent_cancer_date,
    cohorts.distinct_cancer_codes,
    cohorts.total_cancer_diagnoses,
    coalesce(spend_buckets.total_paid_amount, 0) as total_paid_amount,
    coalesce(spend_buckets.total_allowed_amount, 0) as total_allowed_amount,
    coalesce(spend_buckets.spend_bucket, 'No claims') as spend_bucket,
    coalesce(spend_buckets.spend_bucket_rank, 0) as spend_bucket_rank,
    coalesce(spend_buckets.total_claim_count, 0) as total_claim_count,
    coalesce(spend_buckets.total_claim_line_count, 0) as total_claim_line_count,
    case
        when cohorts.has_active_cancer and patient_cancer_types.cancer_type_count > 1 and coalesce(spend_buckets.spend_bucket_rank, 0) >= 3 then 'High Risk'
        when cohorts.has_active_cancer and (patient_cancer_types.cancer_type_count > 1 or coalesce(spend_buckets.spend_bucket_rank, 0) >= 3) then 'Medium-High Risk'
        when cohorts.has_active_cancer then 'Medium Risk'
        else 'Lower Risk'
    end as risk_category,
    cohorts.cohort_run_date,
    spend_buckets.first_claim_date,
    spend_buckets.last_claim_date
from {{ ref('int_oncology_cohort_identification') }} as cohorts
left join spend_buckets
    on cohorts.person_id = spend_buckets.person_id
left join patient_cancer_types
    on cohorts.person_id = patient_cancer_types.person_id
