--Q1: Tỷ lệ churn tổng (Technique: aggregate)
--Em cho chị tỷ lệ churn % tổng công ty — 1 con số. Chị cần để báo CEO trong họp all-hands sáng mai
SELECT COUNT(*) AS total_employees,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employeess,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF( COUNT(*), 0) AS DECIMAL(5, 2)) AS churn_rate_pct
FROM [hr-employee-churn].[edw].fact_employee;

--Q2: Churn theo department (Technique: group-by, ratio)
--Anh cần tỷ lệ churn theo từng department — department nào đang bị hemorrhage nhân sự?
SELECT e.department_name,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF( COUNT(*), 0) AS DECIMAL(5, 2)) AS churn_rate_pct
FROM [hr-employee-churn].[edw].[fact_employee] f
JOIN [hr-employee-churn].[edw].[dim_department] e ON f.department_id = e.department_id
GROUP BY e.department_name;

--Q3: Lương theo job role (Technique: group-by, aggregate)
--Chị cần lương trung bình, min, max theo từng job role + số employee mỗi role. Để audit compensation.
SELECT
	j.job_role_name,
	CAST ( AVG(salary) AS DECIMAL(10, 2)) AS avg_salary,
	MAX(salary) AS max_salary, MIN(salary) AS min_salary
FROM [hr-employee-churn].[edw].[fact_employee] f
JOIN [hr-employee-churn].[edw].[dim_job_role] j ON j.job_role_id = f.job_role_id
GROUP BY j.job_role_name;


--Q4: Phân bố giới tính + churn (Technique: group-by, pivot)
--Em cho anh số employee theo (giới tính × trạng thái churn) — ma trận. Có khác biệt rõ giữa nam/nữ không?
SELECT
	gender,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	COUNT(*) AS total_emplyees,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF( COUNT(*), 0) AS DECIMAL(5, 2)) AS churn_rate_pct
FROM [hr-employee-churn].[edw].[fact_employee]
GROUP BY gender
ORDER BY churn_rate_pct DESC, gender;


--Q5: Churn theo tenure (Technique: case-when, bucketing)
--Chị cần tỷ lệ churn theo các nhóm tenure: dưới 1 năm, 1-3 năm, 3-5 năm, trên 5 năm. Nhóm nào dễ rời nhất?

WITH tmp AS (
	SELECT employee_id,
		CASE
			WHEN tenure < 1 THEN 'duoi 1 nam'
			WHEN tenure BETWEEN 1 AND 3 THEN '1-3 nam'
			WHEN tenure BETWEEN 3 AND 5 THEN '3-5 nam'
			ELSE '5+ nam'
		END AS tenure_group,
		churn
	FROM [hr-employee-churn].[edw].[fact_employee]
)
SELECT tenure_group,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	COUNT(*) AS total_emplyees,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF( COUNT(*), 0) AS DECIMAL(5, 2)) AS churn_rate_pct
FROM tmp
GROUP BY tenure_group;

--Q6: Lương có correlate performance? (Technique: case-when, group-by)
--Anh nghĩ lương không reflect performance. Em check: chia performance rating thành 3 nhóm (1-2, 3, 4-5), tính lương trung bình mỗi nhóm. Rating cao có lương cao hơn không?

WITH tmp AS (
	SELECT
		employee_id,
		salary,
		performance_rating,
		CASE
			WHEN performance_rating < 3 THEN 'Low performance'
			WHEN performance_rating = 3 THEN 'Medium performance'
			ELSE 'High performance'
		END AS performance_group
	FROM [hr-employee-churn].[edw].[fact_employee]
)
SELECT
	performance_group,
	COUNT(employee_id) as total_employees,
	CAST(AVG(salary) AS DECIMAL(10,2)) AS avg_salary,
	MIN(salary) AS min_salary,
	MAX(salary) AS max_salary,
	CAST(AVG(performance_rating) AS DECIMAL(5,2)) AS avg_performance_rating
FROM tmp
GROUP BY performance_group
ORDER BY performance_group;

--Q7: Overtime ảnh hưởng churn? (Technique: bucketing, ratio)
--Chị muốn biết overtime có gây churn không: chia employee theo nhóm overtime (0, 1-10, 10-20, trên 20 giờ/tháng), tính churn rate mỗi nhóm.
WITH tmp AS (
	SELECT
		employee_id,
		overtime_hours,
		CASE
			WHEN overtime_hours = 0 THEN '0'
			WHEN overtime_hours BETWEEN 1 AND 10 THEN '1-10'
			WHEN overtime_hours BETWEEN 10 AND 20 THEN '11-20'
			ELSE 'over 20'
		END AS overtime_hour_group,
		churn
	FROM [hr-employee-churn].[edw].[fact_employee]
)
SELECT 
	overtime_hour_group,
	COUNT(employee_id) AS total_employees,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS churn_rate_pct
FROM tmp
GROUP BY overtime_hour_group
ORDER BY overtime_hour_group;

--Q8: Matrix work-life × satisfaction (Technique: bucketing, pivot)
--Anh cần ma trận 2D work-life balance × satisfaction level × churn rate. Để thấy combination nào tệ nhất.
--Note: work_life_balance đã bị null toàn cột, không thể xử lý câu này


--Q9: Top 10 dept theo absenteeism (Technique: group-by, rank)
--Chị cần top 10 department có absenteeism cao nhất + số employee. Để team Ops follow up.
WITH dept_abs AS (
    SELECT
        d.department_name,
        COUNT(*) AS total_employees,
        CAST(AVG(CAST(e.absenteeism AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_absenteeism,
        SUM(e.absenteeism) AS total_absenteeism
    FROM [hr-employee-churn].[edw].[fact_employee] e
    JOIN [hr-employee-churn].[edw].[dim_department] d
        ON e.department_id = d.department_id
    GROUP BY d.department_name
)
SELECT TOP 10
    department_name,
    total_employees,
    avg_absenteeism,
    total_absenteeism,
    DENSE_RANK() OVER (ORDER BY total_absenteeism DESC) AS absenteeism_rank
FROM dept_abs
ORDER BY total_absenteeism DESC, department_name;
--> Absenteeism không phân biệt department, chênh lệch chỉ 0.06 ngày giữa cao nhất và thấp nhất → Đây là vấn đề văn hóa/chính sách toàn công ty, không riêng bộ phận nào
--> IT đang "mất" nhiều nhân lực nhất vì nghỉ, dù avg thấp hơn Sales, nhưng tổng 37,570 ngày — cao nhất vì có nhiều nhân sự nhất

--Q10: Manager feedback vs promotion (Technique: bucketing, group-by)
--Anh cần check fairness: chia feedback score thành low/mid/high, tính số lần promotion trung bình + churn rate mỗi nhóm. Manager đánh giá cao có dẫn đến promotion không?
WITH tmp AS (
	SELECT
		employee_id,
		manager_feedback_score,
		CASE
			WHEN manager_feedback_score < 6 THEN 'Low'
			WHEN manager_feedback_score < 9 THEN 'Mid'
			ELSE 'High'
		END AS feedback_score_group,
		promotions,
		churn
	FROM [hr-employee-churn].[edw].[fact_employee]
)
SELECT
	feedback_score_group,
	COUNT(*) AS total_employees,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	SUM(CASE WHEN promotions = 1 THEN 1 ELSE 0 END) AS promoted_employees,
	CAST(AVG(CAST(promotions AS DECIMAL(5,2))) AS DECIMAL(10,2)) AS avg_promotion,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS churn_rate_pct,
	CAST(100.0 * SUM(CASE WHEN promotions = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS promotion_rate_pct
FROM tmp
GROUP BY feedback_score_group
ORDER BY 
    CASE feedback_score_group
        WHEN 'Low' THEN 1
        WHEN 'Mid' THEN 2
        WHEN 'High' THEN 3
    END;

--> Gần như không có sự khác biệt — chênh lệch chỉ ~0.75% giữa các nhóm.
--> Manager feedback cao KHÔNG dẫn đến promotion rõ ràng — đây là dấu hiệu thiếu fairness trong quy trình thăng tiến.
--> Thậm chí Mid còn được promote nhiều hơn High → promotion đang phụ thuộc vào yếu tố khác, không phải manager feedback.
--> Nhóm High feedback lại có churn cao nhất!

--Q11: Underpay employee mỗi role (Technique: window, percent-rank)
--Chị cần list employee có lương thấp hơn 25% peer cùng role — potential flight risk. Team comp team cần review.
WITH salary_ranked AS (
	SELECT
		e.employee_id,
		j.job_role_name,
		e.salary,
		e.churn,
		CAST(AVG(e.salary) OVER (PARTITION BY j.job_role_name) AS DECIMAL(12,2)) AS role_avg_salary,
		CAST(PERCENT_RANK() OVER (
			PARTITION BY j.job_role_name
			ORDER BY e.salary
		) AS DECIMAL(6,4)) AS salary_percentile
	FROM [hr-employee-churn].[edw].[fact_employee] e
	JOIN [hr-employee-churn].[edw].[dim_job_role] j ON j.job_role_id = e.job_role_id
)
SELECT
	employee_id,
	job_role_name,
	salary,
	role_avg_salary,
	CAST(role_avg_salary - salary AS DECIMAL(12,2)) AS salary_gap_to_role_avg,
	salary_percentile,
	CASE WHEN churn = 1 THEN 'High risk (already churned)' ELSE 'Potential risk' END AS risk_flag
FROM salary_ranked
WHERE salary_percentile <= 0.25
ORDER BY job_role_name, salary_percentile, salary;

--Q12: Tenure decile vs churn (Technique: window, ntile)
--Anh cần churn rate theo 10 decile tenure — tuổi nghề nào là sweet spot stay, giai đoạn nào churn mạnh?
WITH tmp AS (
	SELECT
		employee_id,
		tenure,
		churn,
		NTILE(10) OVER (ORDER BY tenure) AS tenure_decile
	FROM [hr-employee-churn].[edw].[fact_employee]
)
SELECT
	tenure_decile,
	MIN(tenure) AS min_tenure_in_decile,
	MAX(tenure) AS max_tenure_in_decile,
	COUNT(*) AS totel_employees,
	SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) AS churned_employees,
	SUM(CASE WHEN churn = 0 THEN 1 ELSE 0 END) AS stayed_employees,
	CAST(100.0 * SUM(CASE WHEN churn = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS churn_rate_pct
FROM tmp
GROUP BY tenure_decile
ORDER BY tenure_decile ASC;
--> Nguy hiểm nhất: 6–7 năm — đây là điểm "đủ kinh nghiệm để nhảy việc, chưa đủ gắn bó để ở lại"
--> 3–4 năm cũng đáng lo — giai đoạn hết "honeymoon period", bắt đầu đánh giá lại
--> Sweet spot rõ nhất: 4–5 năm — churn thấp nhất toàn bảng, đây là giai đoạn nhân viên đã ổn định và gắn bó
--> 0–1 năm churn thấp vì còn đang thích nghi, chưa có lý do rõ để nghỉ

--Q13: Risk score composite (Technique: composite-score, rank)
--Em build giúp chị composite risk score cho mỗi employee (dùng overtime, satisfaction, absenteeism, promotions). Rank + list top 100 high risk.
WITH normalized AS (
	SELECT
			employee_id,
			overtime_hours,
			satisfaction_level,
			absenteeism,
			promotions,
			-- Overtime: cao = nguy hiểm → giữ nguyên hướng
			(overtime_hours - MIN(overtime_hours) OVER()) / NULLIF(MAX(overtime_hours) OVER() - MIN(overtime_hours) OVER(), 0) AS overtime_norm,
			-- Satisfaction: thấp = nguy hiểm → đảo ngược
			1 - (satisfaction_level - MIN(satisfaction_level) OVER()) / NULLIF(MAX(satisfaction_level) OVER() - MIN(satisfaction_level) OVER(), 0) AS satisfaction_norm,
			-- Absenteeism: cao = nguy hiểm → giữ nguyên hướng
			(absenteeism - MIN(absenteeism) OVER()) * 1.0 / NULLIF(MAX(absenteeism) OVER() - MIN(absenteeism) OVER(), 0) AS absenteeism_norm,
			-- promotions: thấp = nguy hiểm → đảo ngược, chỉ có 0 và 1, không cần normalize
			(1 - promotions) AS promotions_norm
	FROM [hr-employee-churn].[edw].[fact_employee]
)
, scored AS (
	SELECT
		employee_id,
		overtime_hours,
		satisfaction_level,
		absenteeism,
		promotions,
		ROUND(
		  (overtime_norm     * 0.30) +
		  (satisfaction_norm * 0.30) +
		  (absenteeism_norm  * 0.25) +
		  (promotions_norm   * 0.15)
		, 4) AS risk_score
	FROM normalized
)
, ranked AS (
	SELECT
		*,
		ROW_NUMBER() OVER (ORDER BY risk_score DESC) AS risk_rank
	FROM scored
)
SELECT *
FROM ranked
WHERE risk_rank <= 100
ORDER BY risk_rank
--> 100 người trong list này đều không được thăng chức
--> Gần như toàn bộ gần như không hài lòng với công việc — thang điểm tối đa là 1.0 mà trung bình chỉ 0.09
--> Không ai trong list này làm việc ở mức bình thường — tất cả đều đang bị overload
--> "Nhóm này có overtime cao VÀ absenteeism cao đồng thời" — còn nguyên nhân là burnout hay làm bù thì không kết luận được chắc chắn.
-->100 người này có mức độ rủi ro tương đương nhau, không có ai vượt trội hẳn

--Q14: Cohort by hire year (Technique: cte, cohort)
--Anh cần churn rate theo cohort hire year (tính từ tenure). Cohort nào có churn cao — năm hire có vấn đề gì?
--Note: Không có cột hire date và leave date, không thể xử lý câu này

--Q15: Peer salary gap (Technique: window, partition-by, peer-diff)
--Chị cần gap lương của mỗi employee so với trung bình peer cùng role. Flag employee gap dưới -10% (underpaid).
WITH salary_ranked AS (
    SELECT
        e.employee_id,
        j.job_role_name,
        e.salary,
        e.churn,
        AVG(e.salary) OVER (PARTITION BY j.job_role_name) AS role_avg_salary,
        ROUND(
            (e.salary - AVG(e.salary) OVER (PARTITION BY j.job_role_name))
            / NULLIF(AVG(e.salary) OVER (PARTITION BY j.job_role_name), 0) * 100.0,
            2
        ) AS salary_gap_pct
    FROM [hr-employee-churn].[edw].[fact_employee] e
    JOIN [hr-employee-churn].[edw].[dim_job_role] j ON j.job_role_id = e.job_role_id
)
SELECT
    *,
    CASE WHEN salary_gap_pct <= -10 THEN 'Underpaid' ELSE 'OK' END AS flag
FROM salary_ranked
ORDER BY salary_gap_pct;