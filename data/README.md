# Data

This project uses the **BPI Challenge 2012** event log, a real process mining dataset related to a loan application process.

The original dataset is available from 4TU.ResearchData:

* Dataset: BPI Challenge 2012
* Source: 4TU.ResearchData / Eindhoven University of Technology
* Format: `.xes.gz`
* Original file: `BPI_Challenge_2012.xes.gz`

## Data Usage in This Repository

To keep the repository lightweight, this GitHub repository does **not** include the full raw dataset or the full processed event-level CSV.

Instead, it includes:

```text
data/sample/
```

A small sample of the processed event log.

```text
data/kpis/
```

Small KPI tables generated from the full dataset and used for dashboarding.

## Folder Structure

```text
data/
│
├── sample/
│   └── bpi_2012_events_sample.csv
│
└── kpis/
    ├── activity_frequency.csv
    ├── case_duration_categories.csv
    ├── completed_workflow_activity.csv
    ├── key_transition_comparison.csv
    ├── resource_workload.csv
    ├── rework_by_duration.csv
    ├── rework_summary.csv
    ├── waiting_time_by_duration.csv
    └── waiting_time_summary.csv
```

## Sample Data

The sample file contains a small subset of the processed event log and is included only for reference.

Main columns include:

| Column                   | Description                                      |
| ------------------------ | ------------------------------------------------ |
| `case_id`                | Unique identifier for each loan application case |
| `activity`               | Workflow activity/event name                     |
| `timestamp`              | Date and time of the event                       |
| `resource`               | User/resource associated with the event          |
| `lifecycle_transition`   | Lifecycle status of the event                    |
| `case_registration_date` | Registration date of the case                    |
| `amount_requested`       | Requested loan amount                            |

## KPI Tables

The KPI files in `data/kpis/` were generated from the full processed dataset using SQL queries in:

```text
sql/01_process_kpis.sql
```

These tables are designed to support the dashboard without requiring the full dataset to be stored in the repository.

The KPI tables include:

* case duration categories
* activity frequency
* completed workflow activity counts
* rework metrics
* rework by duration category
* waiting time between transitions
* key transition comparison
* resource workload

## Reproducibility Note

To fully reproduce the analysis, download the original `.xes.gz` file from 4TU.ResearchData and run:

```text
notebooks/01_convert_xes_to_csv.ipynb
notebooks/02_exploratory_analysis.ipynb
notebooks/03_sql_kpi_analysis.ipynb
```

The full dataset should be downloaded directly from the original 4TU.ResearchData source.
