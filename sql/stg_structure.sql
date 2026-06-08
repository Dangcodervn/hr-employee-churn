 -- STG: Bản sao thô 1:1 từ CSV, toàn bộ cột NVARCHAR, không có FK

USE [hr-employee-churn];
GO

-- Tạo bảng (xóa nếu đã tồn tại)
IF OBJECT_ID('stg.raw_employees', 'U') IS NOT NULL
    DROP TABLE stg.raw_employees;
GO

CREATE TABLE stg.raw_employees (
    employee_id NVARCHAR(25),
    age NVARCHAR(25),
    gender NVARCHAR(25),
    education_level NVARCHAR(25),
    marital_status NVARCHAR(25),
    tenure NVARCHAR(25),
    job_role NVARCHAR(25),
    department NVARCHAR(25),
    salary NVARCHAR(25),
    work_location NVARCHAR(25),
    performance_rating NVARCHAR(25),
    projects_completed NVARCHAR(25),
    training_hours NVARCHAR(25),
    promotions NVARCHAR(25),
    overtime_hours NVARCHAR(25),
    satisfaction_level NVARCHAR(25),
    work_life_balance NVARCHAR(25),
    average_monthly_hours_worked NVARCHAR(25),
    absenteeism NVARCHAR(25),
    distance_from_home NVARCHAR(25),
    manager_feedback_score NVARCHAR(25),
    churn NVARCHAR(25)
);
GO

-- Import bulk từ file CSV vào bảng staging
BULK INSERT stg.raw_employees
FROM 'D:\Data Self Learning\Extra Projects\HRProject\data\Employee_Info.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO