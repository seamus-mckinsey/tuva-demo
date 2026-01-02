# Oncology Population Analysis - Project Summary

## Overview

This project analyzes the oncology patient population using claims and diagnosis data to identify cancer patients, segment them by clinical and financial characteristics, and profile healthcare costs by care setting.

## Methodology

### Cancer Definition

**ICD-10-CM Code Ranges:**
We defined the cancer population using the following ICD-10-CM diagnosis code ranges based on the official ICD-10-CM classification system:

- **Malignant Neoplasms (C00-C96)**: Primary and metastatic cancers
- **In Situ Neoplasms (D00-D09)**: Early-stage cancers confined to origin site
- **Neoplasms of Uncertain Behavior (D37-D48)**: Tumors with uncertain malignant potential

**Cancer Type Classification:**
Patients are classified into 15 distinct cancer type categories based on anatomical site and organ system:

| Cancer Type | ICD-10 Range | Examples |
|------------|--------------|----------|
| Head and Neck Cancer | C00-C14 | Lip, oral cavity, pharynx, larynx |
| Gastrointestinal Cancer | C15-C26 | Esophagus, stomach, colon, rectum, pancreas |
| Respiratory Cancer | C30-C39 | Lung, bronchus, trachea |
| Bone and Cartilage Cancer | C40-C41 | Bone, articular cartilage |
| Skin Cancer | C43-C44 | Melanoma, non-melanoma skin cancer |
| Soft Tissue Cancer | C45-C49 | Mesothelioma, soft tissue sarcoma |
| Breast Cancer | C50 | Breast cancer |
| Gynecologic Cancer | C51-C58 | Cervix, uterus, ovary |
| Male Genital Cancer | C60-C63 | Prostate, testis |
| Urinary Cancer | C64-C68 | Kidney, bladder, urinary tract |
| Eye, Brain and CNS Cancer | C69-C72 | Eye, brain, spinal cord |
| Endocrine Cancer | C73-C75 | Thyroid, adrenal glands |
| Ill-defined Cancer | C76-C80 | Ill-defined or unknown primary sites |
| Hematologic Cancer | C81-C96 | Lymphoma, leukemia, multiple myeloma |
| In Situ/Uncertain Behavior | D00-D09, D37-D48 | Pre-cancerous and uncertain neoplasms |

### Data Handling & Ambiguities

**Active Cancer Status:**
A patient is considered to have "active cancer" if either:
- They have at least one unresolved cancer diagnosis (resolved_date is null), OR
- They have a cancer diagnosis resolved within the past 90 days

This 90-day lookback period accounts for recent treatment completion while distinguishing from long-term cancer survivors.

**Primary Cancer Type:**
When a patient has multiple cancer types, the primary cancer type is determined by:
1. **Frequency**: The cancer type with the most diagnosis records
2. **Recency**: If tied, the cancer type with the earliest diagnosis date

**Missing or Null Values:**
- Patients without claims data are assigned to "No claims" spend bucket with $0 spend
- Missing birth dates result in null age calculations
- Onset date falls back to recorded date if unavailable

**Care Setting Classification:**
Claims are classified into care settings using a hierarchical logic based on bill type codes, revenue center codes, and place of service codes:

1. **Inpatient** - Institutional inpatient stays
2. **Emergency Room** - ER visits (highest priority after inpatient)
3. **Outpatient Surgery** - Ambulatory surgical procedures
4. **Skilled Nursing Facility** - Post-acute SNF care
5. **Home Health** - Home-based care services
6. **Office/Clinic** - Professional office visits
7. **Outpatient Hospital** - Other institutional outpatient
8. **Professional Services** - Other professional services
9. **Other** - Unclassified services

---

## Key Findings

### Prevalence

Total cancer patients and active cancer rate:
```sql
select
    count(distinct person_id) as total_cancer_patients,
    sum(case when has_active_cancer = true then 1 else 0 end) as active_cancer_patients,
    round(100.0 * sum(case when has_active_cancer = true then 1 else 0 end) / count(*), 1) as active_cancer_rate_percentage
from int_oncology_cohort_identification
```

Top 10 cancer types by patient count:
```sql
select
    primary_cancer_type,
    count(*) as patient_count,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as percentage_of_total
from int_oncology_cohort_identification
group by primary_cancer_type
order by patient_count desc
limit 10
```

### Top Cost Drivers

**By Care Setting** - Where healthcare dollars are spent:
```sql
select
    care_setting,
    round(sum(total_paid), 0) as total_paid,
    round(100.0 * sum(total_paid) / sum(sum(total_paid)) over (), 1) as percentage_of_total_spend
from mart_oncology_cost_by_care_setting
group by care_setting
order by total_paid desc;
```

**By Cancer Type** - Most expensive cancers by average cost per patient:
```sql
select
    primary_cancer_type,
    count(*) as patient_count,
    round(avg(total_paid_amount), 0) as avg_cost_per_patient
from int_oncology_patient_segmentation
where total_paid_amount > 0
group by primary_cancer_type
order by avg_cost_per_patient desc
limit 10
```

**Spend Concentration** - Small percentage of high-cost patients drive majority of spend:
```sql
select
    spend_bucket,
    count(*) as patient_count,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as percentage_of_patients,
    round(100.0 * sum(total_paid_amount) / sum(sum(total_paid_amount)) over (), 1) as percentage_of_total_spend
from int_oncology_patient_segmentation
group by 
    spend_bucket, 
    spend_bucket_rank
order by spend_bucket_rank
```
--- 

## AI Usage Log

AI was used to generate the yml file and most of the README. I used AI to create add all columns to the yml file along with descriptions. For the README, AI was used to generate the template and methology section.

I have experience using DBT cloud, so using AI to help me learn how to use DBT core along with dbeaver helped speed up the process. AI also helped me define the cancer classification and parsed the codes from https://www.icd10data.com/.

Most case statements were also generated by AI to help speed up the process and help determine what group/bucket each value should go into.