# Oncology Analytics Models

This directory contains dbt models for analyzing the oncology (cancer) patient population. The models follow a layered architecture: **Staging → Intermediate → Marts**.

## Architecture Overview

```
Staging Layer (stg_oncology__*)
    ↓
Intermediate Layer (int_oncology__*)
    ↓
Marts Layer (oncology__*)
```

## Model Descriptions

### Staging Layer

**Purpose**: Clean, filter, and lightly transform source data specific to oncology.

| Model | Description |
|-------|-------------|
| `stg_oncology__cancer_icd10_codes` | Reference table of ICD-10 cancer code ranges |
| `stg_oncology__conditions` | All cancer diagnoses with cancer type classification |
| `stg_oncology__claims` | Medical claims for cancer patients with care setting classification |

### Intermediate Layer

**Purpose**: Apply business logic, create derived fields, and prepare data for reporting.

| Model | Description |
|-------|-------------|
| `int_oncology__cohort_identification` | Identifies cancer patients and determines active status |
| `int_oncology__patient_segmentation` | Segments patients by cancer type, spend bucket, age, and risk |

### Marts Layer

**Purpose**: Create analytics-ready tables optimized for reporting and dashboarding.

| Model | Description |
|-------|-------------|
| `oncology__cost_by_care_setting` | Cost breakdown by care setting per patient |
| `oncology__patient_summary` | **Main mart** - comprehensive patient-level summary |
| `oncology__summary_statistics` | Aggregate statistics for the entire cohort |

## Key Features

### Cohort Identification
- Uses ICD-10 codes (C00-D49 range) to identify cancer patients
- Determines active cancer status based on resolution dates
- Tracks primary and secondary cancer types

### Segmentation
Cancer patients are segmented by:
- **Cancer Type**: 15 categories (Breast, Lung, Hematologic, etc.)
- **Spend Bucket**: 5 tiers from <$10K to >$250K
- **Age Group**: 6 groups from Pediatric to Advanced Age
- **Risk Category**: High, Medium-High, Medium, Lower Risk

### Cost Profiling
Analyzes spending across care settings:
- Inpatient
- Emergency Room
- Outpatient Hospital / Surgery
- Office/Clinic
- Skilled Nursing Facility
- Home Health
- Professional Services

## Usage Examples

### Query 1: Get all cancer patients with their primary diagnosis and total spend
```sql
SELECT
    person_id,
    first_name,
    last_name,
    age_years,
    primary_cancer_type,
    total_paid_amount,
    spend_bucket,
    has_active_cancer
FROM oncology__patient_summary
ORDER BY total_paid_amount DESC;
```

### Query 2: Analyze cost distribution by care setting for breast cancer patients
```sql
SELECT
    person_id,
    total_paid_amount,
    inpatient_paid,
    er_paid,
    outpatient_hospital_paid,
    office_paid,
    pct_inpatient,
    pct_er
FROM oncology__patient_summary
WHERE primary_cancer_type = 'Breast Cancer'
    AND total_paid_amount > 0
ORDER BY total_paid_amount DESC;
```

### Query 3: View high-level cohort statistics
```sql
SELECT
    metric_category,
    metric_name,
    metric_value,
    metric_pct
FROM oncology__summary_statistics
ORDER BY metric_category, metric_name;
```

### Query 4: Identify high-risk, high-cost patients for care management
```sql
SELECT
    person_id,
    first_name,
    last_name,
    age_years,
    primary_cancer_type,
    risk_category,
    total_paid_amount,
    inpatient_claim_count,
    er_claim_count
FROM oncology__patient_summary
WHERE risk_category = 'High Risk'
    AND total_paid_amount > 100000
ORDER BY total_paid_amount DESC;
```

### Query 5: Compare spending across cancer types
```sql
SELECT
    primary_cancer_type,
    COUNT(DISTINCT person_id) as patient_count,
    SUM(total_paid_amount) as total_spend,
    AVG(total_paid_amount) as avg_spend_per_patient,
    SUM(inpatient_paid) as total_inpatient_spend,
    ROUND(100.0 * SUM(inpatient_paid) / NULLIF(SUM(total_paid_amount), 0), 2) as pct_inpatient
FROM oncology__patient_summary
GROUP BY primary_cancer_type
ORDER BY total_spend DESC;
```

## Running the Models

### Build all oncology models
```bash
dbt run --select oncology
```

### Build just the marts (final tables)
```bash
dbt run --select oncology.marts
```

### Build a specific model and its dependencies
```bash
dbt run --select +oncology__patient_summary
```

### Run tests
```bash
dbt test --select oncology
```

### Generate documentation
```bash
dbt docs generate
dbt docs serve
```

## Data Quality Considerations

- **ICD-10 Code Coverage**: Models identify cancer using C00-D49 range. Verify this aligns with your organization's definition.
- **Active Cancer Logic**: Patients with no resolved_date or resolved_date within last 90 days are considered "active."
- **Care Setting Classification**: Based on bill type codes and place of service. Review logic in `stg_oncology__claims.sql`.
- **Spend Buckets**: Thresholds are set at $10K, $50K, $100K, $250K. Adjust as needed for your population.

## Customization

To customize these models for your organization:

1. **Adjust ICD-10 code ranges**: Modify `stg_oncology__conditions.sql`
2. **Change spend bucket thresholds**: Edit `int_oncology__patient_segmentation.sql`
3. **Refine care setting logic**: Update `stg_oncology__claims.sql`
4. **Add new segmentation dimensions**: Extend `int_oncology__patient_segmentation.sql`

## References

- [ICD-10 Code Lookup](https://www.icd10data.com/)
- [Tuva Project Documentation](https://thetuvaproject.com/)
- [dbt Documentation](https://docs.getdbt.com/)
