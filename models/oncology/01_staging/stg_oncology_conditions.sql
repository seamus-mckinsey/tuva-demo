{{
    config(
        materialized='table',
        tags=['oncology', 'staging']
    )
}}

select
    person_id,
    status,
    normalized_code,
    normalized_description,
    condition_rank,
    -- Cancer type classification based on ICD-10 code ranges
    -- Source: https://www.icd10data.com/ICD10CM/Codes/C00-D49
    case
        when normalized_code >= 'C00' and normalized_code < 'C15' then 'Head and Neck Cancer'
        when normalized_code >= 'C15' and normalized_code < 'C27' then 'Gastrointestinal Cancer'
        when normalized_code >= 'C30' and normalized_code < 'C40' then 'Respiratory Cancer'
        when normalized_code >= 'C40' and normalized_code < 'C42' then 'Bone and Cartilage Cancer'
        when normalized_code >= 'C43' and normalized_code < 'C45' then 'Skin Cancer'
        when normalized_code >= 'C45' and normalized_code < 'C50' then 'Soft Tissue Cancer'
        when normalized_code >= 'C50' and normalized_code < 'C51' then 'Breast Cancer'
        when normalized_code >= 'C51' and normalized_code < 'C59' then 'Gynecologic Cancer'
        when normalized_code >= 'C60' and normalized_code < 'C64' then 'Male Genital Cancer'
        when normalized_code >= 'C64' and normalized_code < 'C69' then 'Urinary Cancer'
        when normalized_code >= 'C69' and normalized_code < 'C73' then 'Eye, Brain and CNS Cancer'
        when normalized_code >= 'C73' and normalized_code < 'C76' then 'Endocrine Cancer'
        when normalized_code >= 'C76' and normalized_code < 'C81' then 'Ill-defined Cancer'
        when normalized_code >= 'C81' and normalized_code < 'C97' then 'Hematologic Cancer'
        when normalized_code >= 'D00' and normalized_code < 'D10' then 'In Situ Neoplasm'
        when normalized_code >= 'D37' and normalized_code < 'D49' then 'Uncertain Behavior'
        else 'Other Cancer'
    end as cancer_type,
    recorded_date,
    onset_date,
    resolved_date
from {{ ref('core__condition') }}
where normalized_code_type = 'icd-10-cm'
    and (
        -- Malignant neoplasms (C00-C97)
        normalized_code like 'C%'
        -- In situ neoplasms (D00-D09)
        or (normalized_code >= 'D00' and normalized_code < 'D10')
        -- Neoplasms of uncertain behavior (D37-D48)
        or (normalized_code >= 'D37' and normalized_code < 'D49')
    )
