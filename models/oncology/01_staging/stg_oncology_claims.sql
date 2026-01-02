{{
    config(
        materialized='table',
        tags=['oncology', 'staging']
    )
}}

with cancer_patients as (

    /*
    Using distinct to get unique patients in case a patient has multiple cancer conditions.
    */
    select distinct person_id
    from {{ ref('stg_oncology_conditions') }}

)

select
    mc.claim_id,
    mc.claim_line_number,
    mc.person_id,
    bt.bill_type_description,
    pos.place_of_service_description,
    rc.revenue_center_description,
    mc.allowed_amount,
    mc.charge_amount,
    mc.paid_amount,
    mc.coinsurance_amount,
    mc.copayment_amount,
    mc.deductible_amount,
    case
        when mc.claim_type = 'institutional' and mc.bill_type_code in ('11', '12', '13', '14', '18', '41', '42', '43', '44', '48') then 'Inpatient'
        when mc.revenue_center_code in ('0450', '0451', '0452', '0456', '0459', '0981') or mc.place_of_service_code = '23' then 'Emergency Room'
        when mc.bill_type_code in ('13', '83') or mc.place_of_service_code in ('22', '24') then 'Outpatient Surgery'
        when mc.bill_type_code in ('21', '22', '23', '28') or mc.place_of_service_code in ('31', '32') then 'Skilled Nursing Facility'
        when mc.bill_type_code in ('32', '33', '34') or mc.place_of_service_code = '12' then 'Home Health'
        when mc.claim_type = 'professional' and mc.place_of_service_code in ('11', '49', '50', '71', '72', '81') then 'Office/Clinic'
        when mc.claim_type = 'institutional' then 'Outpatient Hospital'
        when mc.claim_type = 'professional' then 'Professional Services'
        else 'Other'
    end as care_setting,
    mc.claim_start_date,
    mc.claim_end_date,
from {{ source('input_layer', 'medical_claim') }} mc
-- inner join to only get patients who have cancer.
inner join cancer_patients cp
    on mc.person_id = cp.person_id
-- left join to terminology tables to get code descriptions.
left join {{ ref('terminology__bill_type') }} bt
    on mc.bill_type_code = bt.bill_type_code
left join {{ ref('terminology__place_of_service') }} pos
    on mc.place_of_service_code = pos.place_of_service_code
left join {{ ref('terminology__revenue_center') }} rc
    on mc.revenue_center_code = rc.revenue_center_code
