-- Process KPI queries for the BPI Challenge 2012 event log
-- SQL dialect: DuckDB
-- Assumes a table/view named "events" is available with the processed event log.


-- ============================================================
-- 1. Dataset Overview KPI
-- ============================================================

SELECT 
    COUNT(*) AS total_events,
    COUNT(DISTINCT case_id) AS total_cases,
    COUNT(DISTINCT activity) AS total_activities,
    COUNT(DISTINCT resource) AS total_resources,
    MIN(timestamp) AS first_event_timestamp,
    MAX(timestamp) AS last_event_timestamp
FROM events;


-- ============================================================
-- 2. Case Duration View
-- ============================================================
-- Calculates each case duration from first event to last event.
-- duration_days_exact keeps decimal days.
-- duration_days floors the value to match the EDA duration categories.

CREATE OR REPLACE VIEW case_duration AS
WITH case_times AS (
    SELECT
        case_id,
        MIN(timestamp) AS case_start,
        MAX(timestamp) AS case_end
    FROM events
    GROUP BY case_id
)
SELECT
    case_id,
    case_start,
    case_end,
    DATE_DIFF('second', case_start, case_end) / 86400.0 AS duration_days_exact,
    CAST(FLOOR(DATE_DIFF('second', case_start, case_end) / 86400.0) AS INTEGER) AS duration_days
FROM case_times;


-- ============================================================
-- 3. Case Duration Category View
-- ============================================================
-- Groups cases into duration categories used in the EDA.

CREATE OR REPLACE VIEW case_duration_category AS
SELECT
    case_id,
    duration_days,
    duration_days_exact,
    CASE
        WHEN duration_days = 0 THEN 'Same day'
        WHEN duration_days = 1 THEN '1 day'
        WHEN duration_days <= 14 THEN '2-14 days'
        WHEN duration_days <= 40 THEN '15-40 days'
        ELSE 'Over 40 days'
    END AS duration_category
FROM case_duration;


-- ============================================================
-- 4. Case Duration Category KPI
-- ============================================================

SELECT
    duration_category,
    COUNT(*) AS total_cases,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS case_percentage
FROM case_duration_category
GROUP BY duration_category
ORDER BY total_cases DESC;


-- ============================================================
-- 5. Activity Frequency KPI
-- ============================================================
-- Shows the most frequent activities in the event log.

SELECT
    activity,
    COUNT(*) AS total_events,
    COUNT(DISTINCT case_id) AS cases_involved,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS event_percentage
FROM events
GROUP BY activity
ORDER BY total_events DESC;


-- ============================================================
-- 6. Completed Workflow Activity KPI
-- ============================================================
-- Focuses on completed manual workflow tasks, identified by W_ activities.

SELECT
    activity,
    COUNT(*) AS completed_events,
    COUNT(DISTINCT case_id) AS cases_involved
FROM events
WHERE 
    activity LIKE 'W_%'
    AND LOWER(lifecycle_transition) = 'complete'
GROUP BY activity
ORDER BY completed_events DESC;


-- ============================================================
-- 7. Completed Work View
-- ============================================================
-- Counts completed workflow activities per case.
-- Used to identify repeated workflow activities.

CREATE OR REPLACE VIEW completed_work AS
SELECT
    case_id,
    activity,
    COUNT(*) AS activity_count
FROM events
WHERE 
    activity LIKE 'W_%'
    AND LOWER(lifecycle_transition) = 'complete'
GROUP BY case_id, activity;


-- ============================================================
-- 8. Repeated Work View
-- ============================================================
-- A workflow activity is considered repeated work if it appears
-- more than once as a completed activity in the same case.

CREATE OR REPLACE VIEW repeated_work AS
SELECT
    case_id,
    activity,
    activity_count
FROM completed_work
WHERE activity_count > 1;


-- ============================================================
-- 9. Rework KPI
-- ============================================================

SELECT
    activity,
    COUNT(DISTINCT case_id) AS cases_with_rework,
    ROUND(AVG(activity_count), 2) AS avg_repetitions_per_reworked_case,
    MAX(activity_count) AS max_repetitions_in_case
FROM repeated_work
GROUP BY activity
ORDER BY cases_with_rework DESC;


-- ============================================================
-- 10. Rework by Duration Category KPI
-- ============================================================
-- Compares repeated workflow activities across duration categories.

WITH cases_by_duration AS (
    SELECT
        duration_category,
        COUNT(DISTINCT case_id) AS total_cases
    FROM case_duration_category
    GROUP BY duration_category
)

SELECT
    c.duration_category,
    r.activity,
    COUNT(DISTINCT r.case_id) AS cases_with_rework,
    b.total_cases,
    ROUND(COUNT(DISTINCT r.case_id) * 100.0 / b.total_cases, 2) AS rework_case_rate,
    ROUND(AVG(r.activity_count), 2) AS avg_repetitions_per_reworked_case,
    MAX(r.activity_count) AS max_repetitions_in_case
FROM repeated_work r
JOIN case_duration_category c
    ON r.case_id = c.case_id
JOIN cases_by_duration b
    ON c.duration_category = b.duration_category
GROUP BY
    c.duration_category,
    r.activity,
    b.total_cases
ORDER BY
    c.duration_category,
    rework_case_rate DESC;


-- ============================================================
-- 11. Waiting Time View
-- ============================================================
-- Calculates waiting time between completed activities within each case.

CREATE OR REPLACE VIEW waiting_times AS
WITH completed_events AS (
    SELECT
        case_id,
        activity,
        timestamp,
        LAG(activity) OVER (
            PARTITION BY case_id
            ORDER BY timestamp
        ) AS previous_activity,
        LAG(timestamp) OVER (
            PARTITION BY case_id
            ORDER BY timestamp
        ) AS previous_timestamp
    FROM events
    WHERE LOWER(lifecycle_transition) = 'complete'
)
SELECT
    case_id,
    previous_activity,
    activity,
    previous_timestamp,
    timestamp,
    DATE_DIFF('second', previous_timestamp, timestamp) / 3600.0 AS waiting_time_hours,
    DATE_DIFF('second', previous_timestamp, timestamp) / 86400.0 AS waiting_time_days
FROM completed_events
WHERE previous_activity IS NOT NULL;


-- ============================================================
-- 12. Waiting Time by Transition KPI
-- ============================================================
-- Summarizes waiting time between activity transitions.
-- Only transitions with at least 30 occurrences are included.

SELECT
    previous_activity,
    activity,
    previous_activity || ' → ' || activity AS transition,
    COUNT(*) AS transition_count,
    ROUND(AVG(waiting_time_days), 2) AS mean_wait_days,
    ROUND(MEDIAN(waiting_time_days), 2) AS median_wait_days,
    ROUND(QUANTILE_CONT(waiting_time_days, 0.95), 2) AS p95_wait_days,
    ROUND(MAX(waiting_time_days), 2) AS max_wait_days
FROM waiting_times
GROUP BY
    previous_activity,
    activity
HAVING COUNT(*) >= 30
ORDER BY median_wait_days DESC;


-- ============================================================
-- 13. Waiting Time by Duration Category KPI
-- ============================================================
-- Compares transition waiting times across case duration categories.

WITH waiting_with_duration AS (
    SELECT
        w.case_id,
        c.duration_category,
        w.previous_activity,
        w.activity,
        w.previous_activity || ' → ' || w.activity AS transition,
        w.waiting_time_days
    FROM waiting_times w
    JOIN case_duration_category c
        ON w.case_id = c.case_id
),

cases_by_duration AS (
    SELECT
        duration_category,
        COUNT(DISTINCT case_id) AS total_cases
    FROM case_duration_category
    GROUP BY duration_category
),

transition_summary AS (
    SELECT
        duration_category,
        previous_activity,
        activity,
        transition,
        COUNT(*) AS transition_count,
        ROUND(AVG(waiting_time_days), 2) AS mean_wait_days,
        ROUND(MEDIAN(waiting_time_days), 2) AS median_wait_days,
        ROUND(QUANTILE_CONT(waiting_time_days, 0.95), 2) AS p95_wait_days
    FROM waiting_with_duration
    GROUP BY
        duration_category,
        previous_activity,
        activity,
        transition
    HAVING COUNT(*) >= 30
)

SELECT
    t.duration_category,
    t.transition,
    t.transition_count,
    c.total_cases,
    ROUND(t.transition_count * 1.0 / c.total_cases, 2) AS transitions_per_case,
    t.mean_wait_days,
    t.median_wait_days,
    t.p95_wait_days
FROM transition_summary t
JOIN cases_by_duration c
    ON t.duration_category = c.duration_category
ORDER BY
    t.duration_category,
    t.median_wait_days DESC;


-- ============================================================
-- 14. Key Transition Comparison KPI
-- ============================================================
-- Focuses on the transitions most relevant to the EDA findings.

WITH waiting_with_duration AS (
    SELECT
        w.case_id,
        c.duration_category,
        w.previous_activity || ' → ' || w.activity AS transition,
        w.waiting_time_days
    FROM waiting_times w
    JOIN case_duration_category c
        ON w.case_id = c.case_id
),

cases_by_duration AS (
    SELECT
        duration_category,
        COUNT(DISTINCT case_id) AS total_cases
    FROM case_duration_category
    GROUP BY duration_category
),

transition_summary AS (
    SELECT
        duration_category,
        transition,
        COUNT(*) AS transition_count,
        ROUND(MEDIAN(waiting_time_days), 2) AS median_wait_days
    FROM waiting_with_duration
    WHERE transition IN (
        'W_Nabellen offertes → W_Nabellen offertes',
        'W_Nabellen offertes → O_SENT_BACK',
        'W_Nabellen offertes → W_Valideren aanvraag',
        'W_Completeren aanvraag → W_Nabellen offertes',
        'W_Completeren aanvraag → O_SENT_BACK',
        'W_Nabellen incomplete dossiers → O_SENT_BACK'
    )
    GROUP BY
        duration_category,
        transition
    HAVING COUNT(*) >= 30
)

SELECT
    t.duration_category,
    t.transition,
    t.transition_count,
    c.total_cases,
    ROUND(t.transition_count * 1.0 / c.total_cases, 2) AS transitions_per_case,
    t.median_wait_days
FROM transition_summary t
JOIN cases_by_duration c
    ON t.duration_category = c.duration_category
WHERE t.duration_category IN ('2-14 days', '15-40 days', 'Over 40 days')
ORDER BY
    t.transition,
    t.duration_category;


-- ============================================================
-- 15. Resource Workload KPI
-- ============================================================
-- Shows which resources handled the most completed workflow activities.

SELECT
    resource,
    COUNT(*) AS completed_workflow_events,
    COUNT(DISTINCT case_id) AS cases_handled,
    COUNT(DISTINCT activity) AS unique_activities_handled
FROM events
WHERE
    activity LIKE 'W_%'
    AND LOWER(lifecycle_transition) = 'complete'
    AND resource IS NOT NULL
GROUP BY resource
ORDER BY completed_workflow_events DESC;
```
