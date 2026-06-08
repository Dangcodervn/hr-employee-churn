--Q1: Tỷ lệ churn tổng (Technique: aggregate)
SELECT COUNT(*) AS total_employees,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employeess,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF( COUNT(*), 0) AS DECIMAL(5, 2)) AS churn_rate_ptc
FROM [hr-employee-churn].[edw].fact_employee

--Q2: Churn theo department (Technique: group-by, ratio)
SELECT e.department_name,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF( COUNT(*), 0) AS DECIMAL(5, 2)) AS churn_rate_ptc
FROM [hr-employee-churn].[edw].[fact_employee] f
JOIN [hr-employee-churn].[edw].[dim_department] e ON f.department_id = e.department_id
GROUP BY e.department_name

--Q3: Lương theo job role (Technique: group-by, aggregate)
SELECT j.job_role_name, CAST ( AVG(salary) AS DECIMAL(10, 2)) AS avg_salary, MAX(salary) AS max_salary, MIN(salary) AS min_salary
FROM [hr-employee-churn].[edw].[fact_employee] f
JOIN [hr-employee-churn].[edw].[dim_job_role] j ON j.job_role_id = f.job_role_id
GROUP BY j.job_role_name


--Q4: Phân bố giới tính + churn (Technique: group-by, pivot)
SELECT *
FROM [hr-employee-churn].[edw].[fact_employee]
JOIN [hr-employee-churn].[edw]


--Q5: Churn theo tenure (Technique: case-when, bucketing)


--Q6: Lương có correlate performance? (Technique: case-when, group-by)


--Q7: Overtime ảnh hưởng churn? (Technique: bucketing, ratio)


--Q8: Matrix work-life × satisfaction (Technique: bucketing, pivot)


--Q9: Top 10 dept theo absenteeism (Technique: group-by, rank)


--Q10: Manager feedback vs promotion (Technique: bucketing, group-by)


--Q11: Underpay employee mỗi role (Technique: window, percent-rank)


--Q12: Tenure decile vs churn (Technique: window, ntile)


--Q13: Risk score composite (Technique: composite-score, rank)


--Q14: Cohort by hire year (Technique: cte, cohort)


--Q15: Peer salary gap (Technique: window, partition-by, peer-diff)

