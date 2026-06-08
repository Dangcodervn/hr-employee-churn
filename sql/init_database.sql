-- 00_init_3layer_architecture.sql
-- Tạo database [hr-employee-churn] và 3 schema: stg, edw, hr

-- Database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'hr-employee-churn')
    CREATE DATABASE [hr-employee-churn];
GO

USE [hr-employee-churn];
GO

-- Schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'edw') EXEC('CREATE SCHEMA edw');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'hr')  EXEC('CREATE SCHEMA hr');
GO
