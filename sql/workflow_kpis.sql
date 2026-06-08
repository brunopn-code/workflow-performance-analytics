-- Workflow Performance Analytics
-- Basic KPI queries for workflow event data

-- 1. Count total workflow cases
SELECT 
    COUNT(DISTINCT case_id) AS total_cases
FROM workflow_events;


-- 2. Count total workflow events
SELECT 
    COUNT(*) AS total_events
FROM workflow_events;


-- 3. Number of cases by case type
SELECT
    case_type,
    COUNT(DISTINCT case_id) AS total_cases
FROM workflow_events
GROUP BY case_type
ORDER BY total_cases DESC;


-- 4. Number of events by activity
SELECT
    activity,
    COUNT(*) AS total_events
FROM workflow_events
GROUP BY activity
ORDER BY total_events DESC;


-- 5. Number of events by department
SELECT
    department,
    COUNT(*) AS total_events
FROM workflow_events
GROUP BY department
ORDER BY total_events DESC;


-- 6. Cases with rework
SELECT
    case_id,
    COUNT(*) AS rework_events
FROM workflow_events
WHERE activity = 'Rework Requested'
GROUP BY case_id
ORDER BY rework_events DESC;


-- 7. Number of completed cases
SELECT
    COUNT(DISTINCT case_id) AS completed_cases
FROM workflow_events
WHERE activity = 'Completed';
