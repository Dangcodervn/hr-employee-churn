-- Chay script nay truoc khi load tu STG sang EDW.

USE [hr-employee-churn];
GO

-- 1) Kiem tra so luong record va duplicate key
SELECT COUNT(*) AS total_rows FROM stg.raw_employees;

SELECT employee_id, COUNT(*) AS duplicate_count
FROM stg.raw_employees
GROUP BY employee_id
HAVING COUNT(*) > 1;

-- 2) Kiem tra null/blank theo tung cot quan trong
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(employee_id)), '') IS NULL THEN 1 ELSE 0 END) AS employee_id_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(gender)), '') IS NULL THEN 1 ELSE 0 END) AS gender_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(education_level)), '') IS NULL THEN 1 ELSE 0 END) AS education_level_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(marital_status)), '') IS NULL THEN 1 ELSE 0 END) AS marital_status_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(department)), '') IS NULL THEN 1 ELSE 0 END) AS department_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(job_role)), '') IS NULL THEN 1 ELSE 0 END) AS job_role_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(work_location)), '') IS NULL THEN 1 ELSE 0 END) AS work_location_blank,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(churn)), '') IS NULL THEN 1 ELSE 0 END) AS churn_blank
FROM stg.raw_employees;

-- 3) Kiem tra chuyen doi kieu du lieu (TRY_CAST)
SELECT
    SUM(CASE WHEN TRY_CAST(age AS TINYINT) IS NULL THEN 1 ELSE 0 END) AS age_invalid,
    SUM(CASE WHEN TRY_CAST(tenure AS TINYINT) IS NULL THEN 1 ELSE 0 END) AS tenure_invalid,
    SUM(CASE WHEN TRY_CAST(salary AS DECIMAL(12,2)) IS NULL THEN 1 ELSE 0 END) AS salary_invalid,
    SUM(CASE WHEN TRY_CAST(performance_rating AS DECIMAL(3,1)) IS NULL THEN 1 ELSE 0 END) AS performance_rating_invalid,
    SUM(CASE WHEN TRY_CAST(projects_completed AS SMALLINT) IS NULL THEN 1 ELSE 0 END) AS projects_completed_invalid,
    SUM(CASE WHEN TRY_CAST(training_hours AS SMALLINT) IS NULL THEN 1 ELSE 0 END) AS training_hours_invalid,
    SUM(CASE WHEN TRY_CAST(promotions AS TINYINT) IS NULL THEN 1 ELSE 0 END) AS promotions_invalid,
    SUM(CASE WHEN TRY_CAST(overtime_hours AS DECIMAL(5,2)) IS NULL THEN 1 ELSE 0 END) AS overtime_hours_invalid,
    SUM(CASE WHEN TRY_CAST(satisfaction_level AS DECIMAL(3,1)) IS NULL THEN 1 ELSE 0 END) AS satisfaction_level_invalid,
    SUM(CASE WHEN TRY_CAST(average_monthly_hours_worked AS SMALLINT) IS NULL THEN 1 ELSE 0 END) AS avg_monthly_hours_invalid,
    SUM(CASE WHEN TRY_CAST(absenteeism AS SMALLINT) IS NULL THEN 1 ELSE 0 END) AS absenteeism_invalid,
    SUM(CASE WHEN TRY_CAST(distance_from_home AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS distance_from_home_invalid,
    SUM(CASE WHEN TRY_CAST(manager_feedback_score AS DECIMAL(3,1)) IS NULL THEN 1 ELSE 0 END) AS manager_feedback_score_invalid,
    SUM(CASE WHEN TRY_CAST(churn AS BIT) IS NULL THEN 1 ELSE 0 END) AS churn_invalid
FROM stg.raw_employees;

-- 4) Kiem tra gia tri ngoai domain cua dim
SELECT 'gender' AS field_name, gender AS bad_value, COUNT(*) AS bad_rows
FROM stg.raw_employees
WHERE gender NOT IN ('Male', 'Female', 'Other')
GROUP BY gender
UNION ALL
SELECT 'education_level' AS field_name, education_level AS bad_value, COUNT(*) AS bad_rows
FROM stg.raw_employees
WHERE education_level NOT IN ('High School', 'Bachelor''s', 'Master''s', 'PhD')
GROUP BY education_level
UNION ALL
SELECT 'marital_status' AS field_name, marital_status AS bad_value, COUNT(*) AS bad_rows
FROM stg.raw_employees
WHERE marital_status NOT IN ('Single', 'Married', 'Divorced')
GROUP BY marital_status
UNION ALL
SELECT 'department' AS field_name, department AS bad_value, COUNT(*) AS bad_rows
FROM stg.raw_employees
WHERE department NOT IN ('Sales', 'HR', 'IT', 'Marketing')
GROUP BY department
UNION ALL
SELECT 'job_role' AS field_name, job_role AS bad_value, COUNT(*) AS bad_rows
FROM stg.raw_employees
WHERE job_role NOT IN ('Analyst', 'Manager', 'Developer', 'Sales')
GROUP BY job_role
UNION ALL
SELECT 'work_location' AS field_name, work_location AS bad_value, COUNT(*) AS bad_rows
FROM stg.raw_employees
WHERE work_location NOT IN ('Remote', 'On-site', 'Hybrid')
GROUP BY work_location;

-- 5) Outlier/range checks co ban
SELECT
    SUM(CASE WHEN TRY_CAST(age AS INT) NOT BETWEEN 18 AND 70 THEN 1 ELSE 0 END) AS age_out_of_range,
    SUM(CASE WHEN TRY_CAST(tenure AS INT) NOT BETWEEN 0 AND 50 THEN 1 ELSE 0 END) AS tenure_out_of_range,
    SUM(CASE WHEN TRY_CAST(salary AS DECIMAL(12,2)) <= 0 THEN 1 ELSE 0 END) AS salary_non_positive,
    SUM(CASE WHEN TRY_CAST(performance_rating AS DECIMAL(3,1)) NOT BETWEEN 0 AND 5 THEN 1 ELSE 0 END) AS performance_rating_out_of_range,
    SUM(CASE WHEN TRY_CAST(satisfaction_level AS DECIMAL(3,1)) NOT BETWEEN 0 AND 10 THEN 1 ELSE 0 END) AS satisfaction_out_of_range,
    SUM(CASE WHEN TRY_CAST(churn AS INT) NOT IN (0, 1) THEN 1 ELSE 0 END) AS churn_not_binary
FROM stg.raw_employees;

-- 6) Mau du lieu loi de debug nhanh (top 50)
SELECT TOP 50 *
FROM stg.raw_employees
WHERE NULLIF(LTRIM(RTRIM(employee_id)), '') IS NULL
   OR TRY_CAST(age AS TINYINT) IS NULL
   OR TRY_CAST(salary AS DECIMAL(12,2)) IS NULL
   OR TRY_CAST(churn AS BIT) IS NULL;
GO
