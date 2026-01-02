{{
    config(
        materialized='table',
        tags=['oncology', 'intermediate']
    )
}}

with cancer_aggregates as (

    /*
    Aggregates all cancer conditions per patient to calculate summary metrics and active cancer status.
    */
    select
        person_id,
        case
            when max(case when resolved_date is null then 1 else 0 end) = 1 then true
            when max(resolved_date) >= current_date - interval '90 days' then true
            else false
        end as has_active_cancer,
        min(coalesce(onset_date, recorded_date)) as first_cancer_date,
        max(coalesce(onset_date, recorded_date)) as most_recent_cancer_date,
        max(resolved_date) as last_resolution_date,
        count(distinct normalized_code) as distinct_cancer_codes,
        count(*) as total_cancer_diagnoses
    from {{ ref('stg_oncology_conditions') }}
    group by person_id

),


primary_cancer_type as (

    /*
    Identifies the primary and most recent cancer type for each patient.
    */
    select
        person_id,
        cancer_type,
        row_number() over (partition by person_id order by count(*) desc, min(coalesce(onset_date, recorded_date))) as cancer_type_rank
    from {{ ref('stg_oncology_conditions') }}
    group by 
        person_id, 
        cancer_type

)

select
    patient.person_id,
    patient.first_name,
    patient.last_name,
    patient.birth_date,
    patient.death_date,
    patient.sex as gender,
    patient.race,
    patient.city,
    patient.state,
    patient.zip_code,
    cancer_aggregates.first_cancer_date,
    cancer_aggregates.most_recent_cancer_date,
    cancer_aggregates.distinct_cancer_codes,
    cancer_aggregates.total_cancer_diagnoses,
    primary_cancer_type.cancer_type as primary_cancer_type,
    cancer_aggregates.has_active_cancer,
    cancer_aggregates.last_resolution_date,
    case
        when patient.death_date is not null then true
        else false
    end as is_deceased,
    case
        when patient.birth_date is not null then floor(datediff('day', patient.birth_date, current_date) / 365.25)
        else null
    end as age_years,
    case
        when floor(datediff('day', patient.birth_date, current_date) / 365.25) < 18 then 'Pediatric (<18)'
        when floor(datediff('day', patient.birth_date, current_date) / 365.25) < 40 then 'Young Adult (18-39)'
        when floor(datediff('day', patient.birth_date, current_date) / 365.25) < 55 then 'Middle Age (40-54)'
        when floor(datediff('day', patient.birth_date, current_date) / 365.25) < 65 then 'Older Adult (55-64)'
        when floor(datediff('day', patient.birth_date, current_date) / 365.25) < 75 then 'Elderly (65-74)'
        when floor(datediff('day', patient.birth_date, current_date) / 365.25) >= 75 then 'Advanced Age (75+)'
        else null
    end as age_group,
    current_date as cohort_run_date
from {{ ref('core__patient') }} as patient
inner join cancer_aggregates
    on patient.person_id = cancer_aggregates.person_id
inner join primary_cancer_type
    on patient.person_id = primary_cancer_type.person_id
    and primary_cancer_type.cancer_type_rank = 1
