SELECT 
    COUNT(*) AS total_events,
    COUNT(DISTINCT case_id) AS total_cases,
    COUNT(DISTINCT activity) AS total_activities,
    COUNT(DISTINCT resource) AS total_resources,
    MIN(timestamp) AS first_event_timestamp,
    MAX(timestamp) AS last_event_timestamp
FROM events

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
    DATE_DIFF('hour', case_start, case_end) / 24.0 AS duration_days
FROM case_times
ORDER BY duration_days DESC

SELECT
    case_id,
    duration_days,
    CASE
        WHEN duration_days = 0 THEN 'Same day'
        WHEN duration_days <= 1 THEN '1 day'
        WHEN duration_days <= 14 THEN '2-14 days'
        WHEN duration_days <= 40 THEN '15-40 days'
        ELSE 'Over 40 days'
    END AS duration_category
FROM case_duration

SELECT
    duration_category,
    COUNT(*) AS total_cases,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS case_percentage
FROM case_duration_category
GROUP BY duration_category
ORDER BY total_cases DESC

SELECT
    activity,
    COUNT(*) AS total_events,
    COUNT(DISTINCT case_id) AS cases_involved,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS event_percentage
FROM events
GROUP BY activity
ORDER BY total_events DESC

SELECT
    activity,
    COUNT(*) AS completed_events,
    COUNT(DISTINCT case_id) AS cases_involved
FROM events
WHERE 
    activity LIKE 'W_%'
    AND LOWER(lifecycle_transition) = 'complete'
GROUP BY activity
ORDER BY completed_events DESC

WITH completed_work AS (
    SELECT
        case_id,
        activity,
        COUNT(*) AS activity_count
    FROM events
    WHERE 
        activity LIKE 'W_%'
        AND LOWER(lifecycle_transition) = 'complete'
    GROUP BY case_id, activity
),

repeated_work AS (
    SELECT
        case_id,
        activity,
        activity_count
    FROM completed_work
    WHERE activity_count > 1
)

SELECT
    r.activity,
    COUNT(DISTINCT r.case_id) AS cases_with_rework,
    ROUND(AVG(r.activity_count), 2) AS avg_repetitions_per_reworked_case,
    MAX(r.activity_count) AS max_repetitions_in_case
FROM repeated_work r
GROUP BY r.activity
ORDER BY cases_with_rework DESC

WITH completed_work AS (
    SELECT
        case_id,
        activity,
        COUNT(*) AS activity_count
    FROM events
    WHERE 
        activity LIKE 'W_%'
        AND LOWER(lifecycle_transition) = 'complete'
    GROUP BY case_id, activity
),

repeated_work AS (
    SELECT
        case_id,
        activity,
        activity_count
    FROM completed_work
    WHERE activity_count > 1
),

cases_by_duration AS (
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
    rework_case_rate DESC

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
),

waiting_times AS (
    SELECT
        case_id,
        previous_activity,
        activity,
        previous_timestamp,
        timestamp,
        DATE_DIFF('second', previous_timestamp, timestamp) / 3600.0 AS waiting_time_hours,
        DATE_DIFF('second', previous_timestamp, timestamp) / 86400.0 AS waiting_time_days
    FROM completed_events
    WHERE previous_activity IS NOT NULL
)

SELECT *
FROM waiting_times
ORDER BY waiting_time_hours DESC

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
ORDER BY median_wait_days DESC

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
    t.median_wait_days DESC

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
    t.duration_category

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
ORDER BY completed_workflow_events DESC
