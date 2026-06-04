
-- ============================================================
-- HR PROJECT - SQL Server Schema
-- ============================================================

-- 1. Tạo database (nếu chưa có)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'hr_project')
    CREATE DATABASE hr_project;
GO

USE hr_project;
GO

-- 2. Tạo bảng employees (nếu đã tồn tại thì xóa trước)
IF OBJECT_ID('dbo.employees', 'U') IS NOT NULL
    DROP TABLE dbo.employees;
GO

CREATE TABLE dbo.employees (
    employee_id                 VARCHAR(10)     NOT NULL,
    age                         INT             NOT NULL,
    gender                      VARCHAR(10)     NOT NULL,
    education_level             VARCHAR(20)     NOT NULL,
    marital_status              VARCHAR(10)     NOT NULL,
    tenure                      INT             NOT NULL,       -- years at company
    job_role                    VARCHAR(20)     NOT NULL,
    department                  VARCHAR(20)     NOT NULL,
    salary                      DECIMAL(12,2)   NOT NULL,
    work_location               VARCHAR(10)     NOT NULL,       -- Remote / On-site / Hybrid
    performance_rating          DECIMAL(3,1)    NOT NULL,
    projects_completed          INT             NOT NULL,
    training_hours              INT             NOT NULL,
    promotions                  INT             NOT NULL,
    overtime_hours              DECIMAL(5,2)    NOT NULL,
    satisfaction_level          DECIMAL(3,1)    NOT NULL,
    work_life_balance           VARCHAR(20)     NULL,           -- all NULL in source data
    average_monthly_hours_worked INT            NOT NULL,
    absenteeism                 INT             NOT NULL,       -- days absent
    distance_from_home          INT             NOT NULL,
    manager_feedback_score      DECIMAL(3,1)    NOT NULL,
    churn                       TINYINT         NOT NULL,       -- 0 = stayed, 1 = left

    CONSTRAINT PK_employees PRIMARY KEY (employee_id)
);
GO
