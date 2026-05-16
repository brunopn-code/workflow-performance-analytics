# Data

This project uses the **BPI Challenge 2012** event log, a real process mining dataset related to a loan application process.

The original dataset is available from 4TU.ResearchData:

- Dataset: BPI Challenge 2012
- Source: 4TU.ResearchData / Eindhoven University of Technology
- Format: `.xes.gz`
- Original file: `BPI_Challenge_2012.xes.gz`

## Data Usage in This Repository

To keep the repository lightweight, this GitHub repository does **not** include the full raw dataset.

Instead, it includes a small sample file:

```text
data/sample/bpi_2012_events_sample.csv
```

The full dataset was downloaded locally and converted from `.xes.gz` to `.csv` using Python and PM4Py.

## Main Columns

| Column | Description |
|---|---|
| `case_id` | Unique identifier for each loan application case |
| `activity` | Workflow activity/event name |
| `timestamp` | Date and time of the event |
| `resource` | User/resource associated with the event |
| `lifecycle_transition` | Lifecycle status of the event |
| `case_registration_date` | Registration date of the case |
| `amount_requested` | Requested loan amount |

## Planned Analysis

This dataset will be used to analyze:

1. Process bottlenecks
2. Case duration
3. Rework patterns
4. Activity frequency
5. Resource workload
6. Loan application process performance

## Note

The full dataset should be downloaded directly from the original 4TU.ResearchData source if reproduction is required.
