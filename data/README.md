# Data

This folder will contain the workflow event dataset used in the project.

## Planned Dataset Structure

Each row will represent one workflow event.

Expected columns:

| Column | Description |
|---|---|
| case_id | Unique identifier for each workflow case |
| activity | Name of the workflow step/activity |
| timestamp | Date and time when the event occurred |
| user_id | User or team responsible for the activity |
| department | Department responsible for the activity |
| case_type | Type/category of the workflow case |
| priority | Priority level of the case |
| sla_hours | SLA target in hours |
| status | Current or final status of the case |

## Example Questions

This dataset will be used to answer:

1. Which activities take the longest?
2. Which cases are most likely to miss SLA?
3. Where does rework happen most often?
4. Which departments handle the highest workload?
5. What process improvements can reduce delays?

## Data Source

For the first version of this project, I will use a synthetic workflow event dataset.

The dataset will be generated to simulate realistic business process behavior, including delays, approvals, rework, and SLA breaches.
