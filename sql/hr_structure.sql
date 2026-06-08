-- HR Data Mart: Star Schema (Kimball) — denormalized dims, fact với churn_risk_score
-- Load từ edw.fact_employee + edw.dim_*

USE [hr-employee-churn];
GO

-- Drop bang phu thuoc truoc de tranh loi FK khi rerun script
IF OBJECT_ID('hr.fact_employee_snapshot', 'U') IS NOT NULL DROP TABLE hr.fact_employee_snapshot;
GO

-- ── DIMENSION TABLES ──────────────────────────────────────

-- dim_employee (SCD Type 1)
IF OBJECT_ID('hr.dim_employee', 'U') IS NOT NULL DROP TABLE hr.dim_employee;
GO
CREATE TABLE hr.dim_employee (
    employee_sk         INT             NOT NULL IDENTITY(1,1),
    employee_id         VARCHAR(10)     NOT NULL,   -- natural key
    age                 TINYINT         NOT NULL,
    gender              NVARCHAR(10)    NOT NULL,
    education_level     NVARCHAR(30)    NOT NULL,
    marital_status      NVARCHAR(15)    NOT NULL,
    tenure              TINYINT         NOT NULL,
    distance_from_home  DECIMAL(10,2)   NOT NULL,
    -- ── SCD metadata ──────────────────────────────────────
    dw_start_date       DATE            NOT NULL DEFAULT CAST(SYSDATETIME() AS DATE),
    dw_is_current       BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_hr_dim_employee PRIMARY KEY (employee_sk),
    CONSTRAINT UQ_hr_dim_employee_id UNIQUE (employee_id)
);
GO

-- dim_job (department + job_role + work_location, denormalized)
IF OBJECT_ID('hr.dim_job', 'U') IS NOT NULL DROP TABLE hr.dim_job;
GO
CREATE TABLE hr.dim_job (
    job_sk          SMALLINT        NOT NULL IDENTITY(1,1),
    department      NVARCHAR(30)    NOT NULL,
    job_role        NVARCHAR(30)    NOT NULL,
    work_location   NVARCHAR(15)    NOT NULL,
    CONSTRAINT PK_hr_dim_job PRIMARY KEY (job_sk),
    CONSTRAINT UQ_hr_dim_job UNIQUE (department, job_role, work_location)
);
GO

-- dim_churn_status
IF OBJECT_ID('hr.dim_churn_status', 'U') IS NOT NULL DROP TABLE hr.dim_churn_status;
GO
CREATE TABLE hr.dim_churn_status (
    churn_sk            TINYINT         NOT NULL,
    churn_flag          BIT             NOT NULL,
    churn_label         NVARCHAR(10)    NOT NULL,   -- 'Stayed' / 'Left'
    CONSTRAINT PK_hr_dim_churn_status PRIMARY KEY (churn_sk)
);
GO
INSERT INTO hr.dim_churn_status VALUES (0, 0, 'Stayed'), (1, 1, 'Left');
GO

-- ── FACT TABLE — 1 row/nhân viên ─────────────────────────
CREATE TABLE hr.fact_employee_snapshot (
    -- FK
    employee_sk                  INT             NOT NULL,
    job_sk                       SMALLINT        NOT NULL,
    churn_sk                     TINYINT         NOT NULL,
    employee_id                  VARCHAR(10)     NOT NULL,  -- degenerate dim

    -- Measures
    salary                       DECIMAL(12,2)   NOT NULL,
    performance_rating           DECIMAL(3,1)    NOT NULL,
    projects_completed           SMALLINT        NOT NULL,
    manager_feedback_score       DECIMAL(3,1)    NOT NULL,
    satisfaction_level           DECIMAL(3,1)    NOT NULL,
    training_hours               SMALLINT        NOT NULL,
    promotions                   TINYINT         NOT NULL,
    overtime_hours               DECIMAL(5,2)    NOT NULL,
    average_monthly_hours_worked SMALLINT        NOT NULL,
    absenteeism                  SMALLINT        NOT NULL,

    -- Computed: churn risk score (Q13)
    -- overtime×0.25 + (1-satisfaction/10)×0.30 + absenteeism/100×0.25 + (no promotion)×0.20
    churn_risk_score             AS (
        ROUND(
            (CAST(overtime_hours AS FLOAT) / 40.0)               * 0.25 +
            (1.0 - CAST(satisfaction_level AS FLOAT) / 10.0)     * 0.30 +
            (CAST(absenteeism AS FLOAT) / 100.0)                 * 0.25 +
            (CASE WHEN promotions = 0 THEN 1.0 ELSE 0.0 END)     * 0.20
        , 4)
    ) PERSISTED,

    -- Metadata
    dw_load_datetime             DATETIME2       DEFAULT SYSDATETIME(),

    -- Constraints
    CONSTRAINT PK_hr_fact_employee_snapshot PRIMARY KEY (employee_sk),
    CONSTRAINT FK_hr_fact_emp   FOREIGN KEY (employee_sk) REFERENCES hr.dim_employee   (employee_sk),
    CONSTRAINT FK_hr_fact_job   FOREIGN KEY (job_sk)      REFERENCES hr.dim_job        (job_sk),
    CONSTRAINT FK_hr_fact_churn FOREIGN KEY (churn_sk)    REFERENCES hr.dim_churn_status (churn_sk)
);
GO

-- ── LOAD: edw → hr ───────────────────────────────────────

-- 1. dim_employee
INSERT INTO hr.dim_employee (
    employee_id, age, gender, education_level,
    marital_status, tenure, distance_from_home
)
SELECT
    f.employee_id,
    f.age,
    f.gender,
    e.education_level_name,
    f.marital_status,
    f.tenure,
    f.distance_from_home
FROM edw.fact_employee       f
JOIN edw.dim_education_level e ON e.education_level_id = f.education_level_id;
GO

-- 2. dim_job
INSERT INTO hr.dim_job (department, job_role, work_location)
SELECT DISTINCT
    d.department_name,
    j.job_role_name,
    w.work_location_name
FROM edw.fact_employee      f
JOIN edw.dim_department     d ON d.department_id     = f.department_id
JOIN edw.dim_job_role       j ON j.job_role_id       = f.job_role_id
JOIN edw.dim_work_location  w ON w.work_location_id  = f.work_location_id;
GO

-- 3. fact_employee_snapshot
INSERT INTO hr.fact_employee_snapshot (
    employee_sk, job_sk, churn_sk, employee_id,
    salary, performance_rating, projects_completed, manager_feedback_score,
    satisfaction_level, training_hours, promotions,
    overtime_hours, average_monthly_hours_worked, absenteeism
)
SELECT
    de.employee_sk,
    dj.job_sk,
    CAST(f.churn AS TINYINT)          AS churn_sk,
    f.employee_id,
    f.salary,
    f.performance_rating,
    f.projects_completed,
    f.manager_feedback_score,
    f.satisfaction_level,
    f.training_hours,
    f.promotions,
    f.overtime_hours,
    f.average_monthly_hours_worked,
    f.absenteeism
FROM edw.fact_employee        f
JOIN hr.dim_employee          de ON de.employee_id      = f.employee_id
JOIN edw.dim_department       d  ON d.department_id     = f.department_id
JOIN edw.dim_job_role         jr ON jr.job_role_id      = f.job_role_id
JOIN edw.dim_work_location    w  ON w.work_location_id  = f.work_location_id
JOIN hr.dim_job               dj ON dj.department       = d.department_name
                                 AND dj.job_role        = jr.job_role_name
                                 AND dj.work_location   = w.work_location_name;
GO

-- Kiểm tra
SELECT 'hr.dim_employee'          AS tbl, COUNT(*) AS rows FROM hr.dim_employee
UNION ALL
SELECT 'hr.dim_job'               AS tbl, COUNT(*) AS rows FROM hr.dim_job
UNION ALL
SELECT 'hr.dim_churn_status'      AS tbl, COUNT(*) AS rows FROM hr.dim_churn_status
UNION ALL
SELECT 'hr.fact_employee_snapshot' AS tbl, COUNT(*) AS rows FROM hr.fact_employee_snapshot;
GO

SELECT TOP 5
    f.employee_id,
    de.gender, de.education_level, de.tenure,
    dj.department, dj.job_role, dj.work_location,
    cs.churn_label,
    f.salary, f.satisfaction_level,
    f.churn_risk_score
FROM hr.fact_employee_snapshot f
JOIN hr.dim_employee    de ON de.employee_sk = f.employee_sk
JOIN hr.dim_job         dj ON dj.job_sk      = f.job_sk
JOIN hr.dim_churn_status cs ON cs.churn_sk   = f.churn_sk;
GO
