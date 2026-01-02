{{
    config(
        materialized='table',
        tags=['oncology', 'marts']
    )
}}


with person_care_setting_costs as (

    /*
    Aggregate costs by person and care setting.
    */
    select
        person_id,
        care_setting,
        sum(paid_amount) as total_paid,
        sum(allowed_amount) as total_allowed,
        sum(charge_amount) as total_charges,
        sum(coinsurance_amount) as total_coinsurance,
        sum(copayment_amount) as total_copay,
        sum(deductible_amount) as total_deductible,
        count(distinct claim_id) as claim_count,
        count(*) as claim_line_count,
        min(claim_start_date) as first_service_date,
        max(claim_end_date) as last_service_date,
        avg(paid_amount) as avg_paid_per_line,
        sum(paid_amount) / nullif(count(distinct claim_id), 0) as avg_paid_per_claim

    from {{ ref('stg_oncology_claims') }}
    group by 
        person_id, 
        care_setting

),

person_totals as (

    /*
    Calculate person-level totals for percentage calculations.
    */
    select
        person_id,
        sum(total_paid) as person_total_paid,
        sum(total_allowed) as person_total_allowed,
        sum(claim_count) as person_total_claims,
        sum(claim_line_count) as person_total_lines
    from person_care_setting_costs
    group by person_id

)

select
    person_care_setting_costs.person_id,
    person_care_setting_costs.care_setting,
    patient_segmentation.primary_cancer_type,
    patient_segmentation.age_group,
    patient_segmentation.spend_bucket,
    patient_segmentation.risk_category,
    patient_segmentation.has_active_cancer,
    person_care_setting_costs.total_paid,
    person_care_setting_costs.total_allowed,
    person_care_setting_costs.total_charges,
    person_care_setting_costs.total_coinsurance,
    person_care_setting_costs.total_copay,
    person_care_setting_costs.total_deductible,
    person_care_setting_costs.claim_count,
    person_care_setting_costs.claim_line_count,
    person_care_setting_costs.avg_paid_per_line,
    person_care_setting_costs.avg_paid_per_claim,
    round(100.0 * person_care_setting_costs.total_paid / nullif(person_totals.person_total_paid, 0), 2) as pct_of_person_spend,
    round(100.0 * person_care_setting_costs.claim_count / nullif(person_totals.person_total_claims, 0), 2) as pct_of_person_claims,
    person_totals.person_total_paid,
    person_totals.person_total_allowed,
    person_care_setting_costs.first_service_date,
    person_care_setting_costs.last_service_date
from person_care_setting_costs
left join person_totals
    on person_care_setting_costs.person_id = person_totals.person_id
left join {{ ref('int_oncology_patient_segmentation') }} patient_segmentation
    on person_care_setting_costs.person_id = patient_segmentation.person_id
order by 
    person_care_setting_costs.person_id, 
    person_care_setting_costs.total_paid desc
