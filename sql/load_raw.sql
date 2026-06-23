-- load_raw.sql
-- Tao bang employees_raw voi dung kieu du lieu, BULK INSERT qua bang tam
-- work_life_balance giu lai dang NULL (toan NULL trong CSV)

USE [hr-employee-churn];
GO

-- ── 1. Tao bang chinh voi dung kieu du lieu ──────────────
IF OBJECT_ID('dbo.employees_raw', 'U') IS NOT NULL
    DROP TABLE dbo.employees_raw;
GO

CREATE TABLE dbo.employees_raw (
    employee_id                  VARCHAR(10)     NOT NULL,
    age                          TINYINT         NOT NULL,
    gender                       NVARCHAR(10)    NOT NULL,
    education_level              NVARCHAR(30)    NOT NULL,
    marital_status               NVARCHAR(15)    NOT NULL,
    tenure                       TINYINT         NOT NULL,
    job_role                     NVARCHAR(30)    NOT NULL,
    department                   NVARCHAR(30)    NOT NULL,
    salary                       DECIMAL(12,2)   NOT NULL,
    work_location                NVARCHAR(15)    NOT NULL,
    performance_rating           DECIMAL(3,1)    NOT NULL,
    projects_completed           SMALLINT        NOT NULL,
    training_hours               SMALLINT        NOT NULL,
    promotions                   TINYINT         NOT NULL,
    overtime_hours               DECIMAL(5,2)    NOT NULL,
    satisfaction_level           DECIMAL(3,2)    NOT NULL,
    work_life_balance            NVARCHAR(10)    NULL,       -- toan NULL trong CSV
    average_monthly_hours_worked SMALLINT        NOT NULL,
    absenteeism                  SMALLINT        NOT NULL,
    distance_from_home           DECIMAL(10,2)   NOT NULL,
    manager_feedback_score       DECIMAL(3,1)    NOT NULL,
    churn                        BIT             NOT NULL,

    CONSTRAINT PK_employees_raw PRIMARY KEY (employee_id)
);
GO

-- ── 2. Bang tam nhan toan bo CSV dang NVARCHAR ────────────
IF OBJECT_ID('tempdb..#stg', 'U') IS NOT NULL
    DROP TABLE #stg;

CREATE TABLE #stg (
    employee_id                  NVARCHAR(25),
    age                          NVARCHAR(25),
    gender                       NVARCHAR(25),
    education_level              NVARCHAR(25),
    marital_status               NVARCHAR(25),
    tenure                       NVARCHAR(25),
    job_role                     NVARCHAR(25),
    department                   NVARCHAR(25),
    salary                       NVARCHAR(25),
    work_location                NVARCHAR(25),
    performance_rating           NVARCHAR(25),
    projects_completed           NVARCHAR(25),
    training_hours               NVARCHAR(25),
    promotions                   NVARCHAR(25),
    overtime_hours               NVARCHAR(25),
    satisfaction_level           NVARCHAR(25),
    work_life_balance            NVARCHAR(25),
    average_monthly_hours_worked NVARCHAR(25),
    absenteeism                  NVARCHAR(25),
    distance_from_home           NVARCHAR(25),
    manager_feedback_score       NVARCHAR(25),
    churn                        NVARCHAR(25)
);

BULK INSERT #stg
FROM 'D:\Data Self Learning\Extra Projects\HRProject\data\Employee_Info.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    TABLOCK
);
GO

-- ── 3. Insert vao bang chinh voi CAST dung kieu ──────────
INSERT INTO dbo.employees_raw (
    employee_id, age, gender, education_level, marital_status,
    tenure, job_role, department, salary, work_location,
    performance_rating, projects_completed, training_hours,
    promotions, overtime_hours, satisfaction_level,
    work_life_balance,
    average_monthly_hours_worked, absenteeism,
    distance_from_home, manager_feedback_score, churn
)
SELECT
    LTRIM(RTRIM(employee_id)),
    CAST(age                          AS TINYINT),
    LTRIM(RTRIM(gender)),
    LTRIM(RTRIM(education_level)),
    LTRIM(RTRIM(marital_status)),
    CAST(tenure                       AS TINYINT),
    LTRIM(RTRIM(job_role)),
    LTRIM(RTRIM(department)),
    CAST(salary                       AS DECIMAL(12,2)),
    LTRIM(RTRIM(work_location)),
    CAST(performance_rating           AS DECIMAL(3,1)),
    CAST(projects_completed           AS SMALLINT),
    CAST(training_hours               AS SMALLINT),
    CAST(promotions                   AS TINYINT),
    CAST(overtime_hours               AS DECIMAL(5,2)),
    CAST(satisfaction_level           AS DECIMAL(3,2)),
    NULLIF(LTRIM(RTRIM(work_life_balance)), 'NULL'),
    CAST(average_monthly_hours_worked AS SMALLINT),
    CAST(absenteeism                  AS SMALLINT),
    CAST(TRY_CAST(distance_from_home  AS DECIMAL(10,2)) AS DECIMAL(10,2)),
    CAST(manager_feedback_score       AS DECIMAL(3,1)),
    CAST(churn                        AS BIT)
FROM #stg;
GO

DROP TABLE #stg;
GO

-- ── 4. Kiem tra ──────────────────────────────────────────
SELECT COUNT(*) AS total_rows FROM dbo.employees_raw;
SELECT TOP 5 * FROM dbo.employees_raw;
GO
