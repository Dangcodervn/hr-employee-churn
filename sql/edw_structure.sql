-- EDW: Chuẩn hóa 3NF (Inmon) — tách dim tables, fact với FK
-- Load từ stg.raw_employees qua CAST + JOIN

USE [hr-employee-churn];
GO

-- Drop bang phu thuoc truoc de tranh loi FK khi rerun script
IF OBJECT_ID('edw.fact_employee', 'U') IS NOT NULL DROP TABLE edw.fact_employee;
GO
IF OBJECT_ID('edw.dim_marital_status', 'U') IS NOT NULL DROP TABLE edw.dim_marital_status;
GO

-- ── DIMENSION TABLES ──────────────────────────────────────

-- dim_education_level
IF OBJECT_ID('edw.dim_education_level', 'U') IS NOT NULL DROP TABLE edw.dim_education_level;
GO
CREATE TABLE edw.dim_education_level (
    education_level_id   TINYINT         NOT NULL IDENTITY(1,1),
    education_level_name NVARCHAR(30)    NOT NULL,
    CONSTRAINT PK_edw_dim_education_level PRIMARY KEY (education_level_id),
    CONSTRAINT UQ_edw_dim_education_level UNIQUE (education_level_name)
);
GO
INSERT INTO edw.dim_education_level (education_level_name)
VALUES ('High School'), ('Bachelor''s'), ('Master''s'), ('PhD');
GO

-- dim_department
IF OBJECT_ID('edw.dim_department', 'U') IS NOT NULL DROP TABLE edw.dim_department;
GO
CREATE TABLE edw.dim_department (
    department_id   SMALLINT        NOT NULL IDENTITY(1,1),
    department_name NVARCHAR(30)    NOT NULL,
    CONSTRAINT PK_edw_dim_department PRIMARY KEY (department_id),
    CONSTRAINT UQ_edw_dim_department UNIQUE (department_name)
);
GO
INSERT INTO edw.dim_department (department_name)
VALUES ('Sales'), ('HR'), ('IT'), ('Marketing');
GO

-- dim_job_role
IF OBJECT_ID('edw.dim_job_role', 'U') IS NOT NULL DROP TABLE edw.dim_job_role;
GO
CREATE TABLE edw.dim_job_role (
    job_role_id   SMALLINT        NOT NULL IDENTITY(1,1),
    job_role_name NVARCHAR(30)    NOT NULL,
    CONSTRAINT PK_edw_dim_job_role PRIMARY KEY (job_role_id),
    CONSTRAINT UQ_edw_dim_job_role UNIQUE (job_role_name)
);
GO
INSERT INTO edw.dim_job_role (job_role_name)
VALUES ('Analyst'), ('Manager'), ('Developer'), ('Sales');
GO

-- dim_work_location
IF OBJECT_ID('edw.dim_work_location', 'U') IS NOT NULL DROP TABLE edw.dim_work_location;
GO
CREATE TABLE edw.dim_work_location (
    work_location_id   TINYINT         NOT NULL IDENTITY(1,1),
    work_location_name NVARCHAR(15)    NOT NULL,
    CONSTRAINT PK_edw_dim_work_location PRIMARY KEY (work_location_id),
    CONSTRAINT UQ_edw_dim_work_location UNIQUE (work_location_name)
);
GO
INSERT INTO edw.dim_work_location (work_location_name)
VALUES ('Remote'), ('On-site'), ('Hybrid');
GO

-- ── FACT TABLE ────────────────────────────────────────────

-- fact_employee
CREATE TABLE edw.fact_employee (
    -- ── Natural key ─────────────────────────────────────────
    employee_id                  VARCHAR(10)     NOT NULL,

    -- FK → dim tables
    education_level_id           TINYINT         NOT NULL,
    department_id                SMALLINT        NOT NULL,
    job_role_id                  SMALLINT        NOT NULL,
    work_location_id             TINYINT         NOT NULL,

    -- Non-dimension categorical
    gender                       NVARCHAR(10)    NOT NULL,
    marital_status               NVARCHAR(15)    NOT NULL,

    -- Measures
    age                          TINYINT         NOT NULL,
    tenure                       TINYINT         NOT NULL,
    salary                       DECIMAL(12,2)   NOT NULL,
    performance_rating           DECIMAL(3,1)    NOT NULL,
    projects_completed           SMALLINT        NOT NULL,
    training_hours               SMALLINT        NOT NULL,
    promotions                   TINYINT         NOT NULL,
    overtime_hours               DECIMAL(5,2)    NOT NULL,
    satisfaction_level           DECIMAL(3,1)    NOT NULL,
    average_monthly_hours_worked SMALLINT        NOT NULL,
    absenteeism                  SMALLINT        NOT NULL,
    distance_from_home           DECIMAL(10,2)   NOT NULL,
    manager_feedback_score       DECIMAL(3,1)    NOT NULL,
    churn                        BIT             NOT NULL,  -- 0 stayed / 1 left

    -- Metadata
    edw_load_datetime            DATETIME2       DEFAULT SYSDATETIME(),

    -- Constraints
    CONSTRAINT PK_edw_fact_employee PRIMARY KEY (employee_id),
    CONSTRAINT FK_edw_fe_education     FOREIGN KEY (education_level_id) REFERENCES edw.dim_education_level (education_level_id),
    CONSTRAINT FK_edw_fe_department    FOREIGN KEY (department_id)      REFERENCES edw.dim_department (department_id),
    CONSTRAINT FK_edw_fe_job_role      FOREIGN KEY (job_role_id)        REFERENCES edw.dim_job_role (job_role_id),
    CONSTRAINT FK_edw_fe_work_location FOREIGN KEY (work_location_id)   REFERENCES edw.dim_work_location (work_location_id)
);
GO

-- ── LOAD: stg → edw ──────────────────────────────────────
IF OBJECT_ID('tempdb..#validated') IS NOT NULL
    DROP TABLE #validated;

;WITH src AS (
    SELECT
        LTRIM(RTRIM(s.employee_id)) AS employee_id,
        LTRIM(RTRIM(s.gender)) AS gender,
        LTRIM(RTRIM(s.education_level)) AS education_level,
        LTRIM(RTRIM(s.marital_status)) AS marital_status,
        LTRIM(RTRIM(s.department)) AS department,
        LTRIM(RTRIM(s.job_role)) AS job_role,
        LTRIM(RTRIM(s.work_location)) AS work_location,
        TRY_CAST(s.age AS TINYINT) AS age,
        TRY_CAST(s.tenure AS TINYINT) AS tenure,
        TRY_CAST(s.salary AS DECIMAL(12,2)) AS salary,
        TRY_CAST(s.performance_rating AS DECIMAL(3,1)) AS performance_rating,
        TRY_CAST(s.projects_completed AS SMALLINT) AS projects_completed,
        TRY_CAST(s.training_hours AS SMALLINT) AS training_hours,
        TRY_CAST(s.promotions AS TINYINT) AS promotions,
        TRY_CAST(s.overtime_hours AS DECIMAL(5,2)) AS overtime_hours,
        TRY_CAST(s.satisfaction_level AS DECIMAL(3,1)) AS satisfaction_level,
        TRY_CAST(s.average_monthly_hours_worked AS SMALLINT) AS average_monthly_hours_worked,
        TRY_CAST(s.absenteeism AS SMALLINT) AS absenteeism,
        TRY_CAST(s.distance_from_home AS DECIMAL(10,2)) AS distance_from_home,
        TRY_CAST(s.manager_feedback_score AS DECIMAL(3,1)) AS manager_feedback_score,
        TRY_CAST(s.churn AS BIT) AS churn,
        COUNT(*) OVER (PARTITION BY LTRIM(RTRIM(s.employee_id))) AS employee_id_count
    FROM stg.raw_employees s
), validated AS (
    SELECT
        src.*,
        e.education_level_id,
        d.department_id,
        j.job_role_id,
        w.work_location_id,
        CASE WHEN src.employee_id IS NULL OR src.employee_id = '' THEN 1 ELSE 0 END AS err_employee_id_blank,
        CASE WHEN src.employee_id_count > 1 THEN 1 ELSE 0 END AS err_employee_id_duplicate,
        CASE WHEN src.age IS NULL THEN 1 ELSE 0 END AS err_age,
        CASE WHEN src.tenure IS NULL THEN 1 ELSE 0 END AS err_tenure,
        CASE WHEN src.salary IS NULL THEN 1 ELSE 0 END AS err_salary,
        CASE WHEN src.performance_rating IS NULL THEN 1 ELSE 0 END AS err_performance_rating,
        CASE WHEN src.projects_completed IS NULL THEN 1 ELSE 0 END AS err_projects_completed,
        CASE WHEN src.training_hours IS NULL THEN 1 ELSE 0 END AS err_training_hours,
        CASE WHEN src.promotions IS NULL THEN 1 ELSE 0 END AS err_promotions,
        CASE WHEN src.overtime_hours IS NULL THEN 1 ELSE 0 END AS err_overtime_hours,
        CASE WHEN src.satisfaction_level IS NULL THEN 1 ELSE 0 END AS err_satisfaction_level,
        CASE WHEN src.average_monthly_hours_worked IS NULL THEN 1 ELSE 0 END AS err_average_monthly_hours_worked,
        CASE WHEN src.absenteeism IS NULL THEN 1 ELSE 0 END AS err_absenteeism,
        CASE WHEN src.distance_from_home IS NULL THEN 1 ELSE 0 END AS err_distance_from_home,
        CASE WHEN src.manager_feedback_score IS NULL THEN 1 ELSE 0 END AS err_manager_feedback_score,
        CASE WHEN src.churn IS NULL THEN 1 ELSE 0 END AS err_churn,
        CASE WHEN src.gender NOT IN ('Male', 'Female', 'Other') THEN 1 ELSE 0 END AS err_gender_mapping,
        CASE WHEN src.marital_status NOT IN ('Single', 'Married', 'Divorced') THEN 1 ELSE 0 END AS err_marital_status_mapping,
        CASE WHEN e.education_level_id IS NULL THEN 1 ELSE 0 END AS err_education_level_mapping,
        CASE WHEN d.department_id IS NULL THEN 1 ELSE 0 END AS err_department_mapping,
        CASE WHEN j.job_role_id IS NULL THEN 1 ELSE 0 END AS err_job_role_mapping,
        CASE WHEN w.work_location_id IS NULL THEN 1 ELSE 0 END AS err_work_location_mapping
    FROM src
    LEFT JOIN edw.dim_education_level e ON e.education_level_name = src.education_level
    LEFT JOIN edw.dim_department d ON d.department_name = src.department
    LEFT JOIN edw.dim_job_role j ON j.job_role_name = src.job_role
    LEFT JOIN edw.dim_work_location w ON w.work_location_name = src.work_location
)
SELECT *
INTO #validated
FROM validated;

-- Neu co loi data quality thi dung load va tra ve mau loi de debug
IF EXISTS (
    SELECT 1
    FROM #validated
    WHERE
        err_employee_id_blank = 1
        OR err_employee_id_duplicate = 1
        OR err_age = 1
        OR err_tenure = 1
        OR err_salary = 1
        OR err_performance_rating = 1
        OR err_projects_completed = 1
        OR err_training_hours = 1
        OR err_promotions = 1
        OR err_overtime_hours = 1
        OR err_satisfaction_level = 1
        OR err_average_monthly_hours_worked = 1
        OR err_absenteeism = 1
        OR err_distance_from_home = 1
        OR err_manager_feedback_score = 1
        OR err_churn = 1
        OR err_gender_mapping = 1
        OR err_education_level_mapping = 1
        OR err_marital_status_mapping = 1
        OR err_department_mapping = 1
        OR err_job_role_mapping = 1
        OR err_work_location_mapping = 1
)
BEGIN
    SELECT TOP 50 *
    FROM #validated
    WHERE
        err_employee_id_blank = 1
        OR err_employee_id_duplicate = 1
        OR err_age = 1
        OR err_tenure = 1
        OR err_salary = 1
        OR err_performance_rating = 1
        OR err_projects_completed = 1
        OR err_training_hours = 1
        OR err_promotions = 1
        OR err_overtime_hours = 1
        OR err_satisfaction_level = 1
        OR err_average_monthly_hours_worked = 1
        OR err_absenteeism = 1
        OR err_distance_from_home = 1
        OR err_manager_feedback_score = 1
        OR err_churn = 1
        OR err_gender_mapping = 1
        OR err_education_level_mapping = 1
        OR err_marital_status_mapping = 1
        OR err_department_mapping = 1
        OR err_job_role_mapping = 1
        OR err_work_location_mapping = 1;

    THROW 50001, 'Data quality check failed at STG. Run sql/stg_eda_checks.sql and fix invalid rows before loading EDW.', 1;
END;

INSERT INTO edw.fact_employee (
    employee_id, gender, marital_status, education_level_id,
    department_id, job_role_id, work_location_id,
    age, tenure, salary, performance_rating, projects_completed,
    training_hours, promotions, overtime_hours, satisfaction_level,
    average_monthly_hours_worked, absenteeism, distance_from_home,
    manager_feedback_score, churn
)
SELECT
    v.employee_id,
    v.gender,
    v.marital_status,
    v.education_level_id,
    v.department_id,
    v.job_role_id,
    v.work_location_id,
    v.age,
    v.tenure,
    v.salary,
    v.performance_rating,
    v.projects_completed,
    v.training_hours,
    v.promotions,
    v.overtime_hours,
    v.satisfaction_level,
    v.average_monthly_hours_worked,
    v.absenteeism,
    v.distance_from_home,
    v.manager_feedback_score,
    v.churn
FROM #validated v;
GO

-- Kiểm tra
SELECT COUNT(*) AS total_rows FROM edw.fact_employee;
SELECT TOP 5 *  FROM edw.fact_employee;
