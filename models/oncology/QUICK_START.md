# Oncology Models - Quick Start Guide

## Step 1: Build the Models

Run the following command to build all oncology models:

```bash
cd /Users/damien.ng/Desktop/github/tuva-demo
dbt run --select oncology
```

This will create all the staging, intermediate, and mart tables in your DuckDB database.

## Step 2: View the Data

### Option A: Using DBeaver (Recommended)

1. Open DBeaver
2. Connect to: `/Users/damien.ng/Desktop/github/tuva-demo/local.duckdb`
3. Navigate to the `main` schema
4. Find these key tables:
   - `oncology__patient_summary` (main table)
   - `oncology__cost_by_care_setting`
   - `oncology__summary_statistics`

### Option B: Using DuckDB CLI

```bash
duckdb local.duckdb

-- View patient summary
SELECT * FROM oncology__patient_summary LIMIT 10;

-- View summary statistics
SELECT * FROM oncology__summary_statistics;

-- Exit
.quit
```

### Option C: Using Python

Create a script or use Python interactively:

```python
import duckdb

conn = duckdb.connect('local.duckdb')

# View patient summary
df = conn.execute("""
    SELECT
        person_id,
        age_years,
        primary_cancer_type,
        total_paid_amount,
        spend_bucket,
        inpatient_paid,
        er_paid,
        office_paid
    FROM oncology__patient_summary
    ORDER BY total_paid_amount DESC
    LIMIT 20
""").fetchdf()

print(df)

# View summary statistics
stats = conn.execute("SELECT * FROM oncology__summary_statistics").fetchdf()
print(stats)

conn.close()
```

## Step 3: Key Queries to Run

### How many cancer patients do we have?
```sql
SELECT COUNT(*) as total_cancer_patients
FROM oncology__patient_summary;
```

### What's the breakdown by cancer type?
```sql
SELECT
    primary_cancer_type,
    COUNT(*) as patient_count,
    ROUND(AVG(total_paid_amount), 2) as avg_spend
FROM oncology__patient_summary
GROUP BY primary_cancer_type
ORDER BY patient_count DESC;
```

### Where is the money going? (Care Setting Analysis)
```sql
SELECT
    SUM(inpatient_paid) as total_inpatient,
    SUM(er_paid) as total_er,
    SUM(outpatient_hospital_paid + outpatient_surgery_paid) as total_outpatient,
    SUM(office_paid) as total_office,
    SUM(total_paid_amount) as grand_total
FROM oncology__patient_summary;
```

### Who are the high-cost, high-risk patients?
```sql
SELECT
    person_id,
    age_years,
    primary_cancer_type,
    risk_category,
    total_paid_amount,
    spend_bucket,
    has_active_cancer
FROM oncology__patient_summary
WHERE risk_category IN ('High Risk', 'Medium-High Risk')
    AND total_paid_amount > 50000
ORDER BY total_paid_amount DESC
LIMIT 20;
```

## Step 4: Generate Documentation

To view full data lineage and column documentation:

```bash
dbt docs generate
dbt docs serve
```

This will open an interactive documentation site in your browser showing:
- Data lineage DAG
- Column descriptions
- Model dependencies
- Test results

## Model Structure

```
📁 models/oncology/
├── 📁 staging/          # Raw data filtering and light transformation
│   ├── stg_oncology__cancer_icd10_codes.sql
│   ├── stg_oncology__conditions.sql
│   └── stg_oncology__claims.sql
│
├── 📁 intermediate/     # Business logic and derived fields
│   ├── int_oncology__cohort_identification.sql
│   └── int_oncology__patient_segmentation.sql
│
└── 📁 marts/            # Analytics-ready tables
    ├── oncology__cost_by_care_setting.sql
    ├── oncology__patient_summary.sql (⭐ START HERE)
    └── oncology__summary_statistics.sql
```

## Troubleshooting

### Models didn't build?
- Check that your Tuva project dependencies are installed: `dbt deps`
- Verify core models exist: `dbt run --select core`

### No cancer patients showing up?
- Verify your source data has ICD-10 diagnosis codes in the C00-D49 range
- Check the `core__condition` table has data

### Want to customize?
- See [README.md](README.md) for customization instructions
- Modify ICD-10 ranges, spend buckets, or care setting logic as needed

## Next Steps

1. **Build the models**: `dbt run --select oncology`
2. **Test the models**: `dbt test --select oncology`
3. **Explore in DBeaver**: Connect and query `oncology__patient_summary`
4. **Create dashboards**: Use the marts to build visualizations in your BI tool
5. **Customize**: Adjust segmentation logic for your specific needs
