
-- 1️⃣ Identifying Most Common Diagnoses by Age Group
-- This query groups patients into age categories and counts the most common diagnoses.
SELECT 
    p.age_group,
    d.icd_code,
    COUNT(d.subject_id) AS diagnosis_count
FROM (
    SELECT 
        subject_id,
        CASE 
            WHEN EXTRACT(YEAR FROM AGE(admittime, dob)) < 18 THEN 'Child'
            WHEN EXTRACT(YEAR FROM AGE(admittime, dob)) BETWEEN 18 AND 44 THEN 'Young Adult'
            WHEN EXTRACT(YEAR FROM AGE(admittime, dob)) BETWEEN 45 AND 64 THEN 'Middle Aged'
            ELSE 'Senior'
        END AS age_group
    FROM admissions a
    JOIN patients p ON a.subject_id = p.subject_id
) p
JOIN diagnoses_icd d ON p.subject_id = d.subject_id
GROUP BY p.age_group, d.icd_code
ORDER BY p.age_group, diagnosis_count DESC
LIMIT 10;

-- 2️⃣ Patient Readmission Rates Within 30 Days
-- This query calculates the readmission rate for patients who were readmitted within 30 days.
WITH readmission_data AS (
    SELECT 
        subject_id,
        admittime,
        LAG(admittime) OVER (PARTITION BY subject_id ORDER BY admittime) AS prev_admittime
    FROM admissions
)
SELECT 
    COUNT(subject_id) AS total_readmissions,
    ROUND(100.0 * COUNT(subject_id) / (SELECT COUNT(*) FROM admissions), 2) AS readmission_rate
FROM readmission_data
WHERE admittime - prev_admittime <= INTERVAL '30 days';

-- 3️⃣ Mortality Rate by Condition
-- This query calculates the mortality rate for each diagnosis.
SELECT 
    d.icd_code,
    COUNT(CASE WHEN a.deathtime IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) AS mortality_rate
FROM admissions a
JOIN diagnoses_icd d ON a.subject_id = d.subject_id
GROUP BY d.icd_code
ORDER BY mortality_rate DESC
LIMIT 10;

-- 4️⃣ Prescription Trends Over Time
-- This query tracks the number of prescriptions for each drug over time.
SELECT 
    p.drug,
    DATE_TRUNC('month', a.admittime) AS month,
    COUNT(p.subject_id) AS total_prescriptions
FROM prescriptions p
JOIN admissions a ON p.subject_id = a.subject_id
GROUP BY p.drug, month
ORDER BY month, total_prescriptions DESC;

-- 5️⃣ Identifying High-Risk Patients for ICU Admission
-- This query finds patients with multiple ICU admissions, indicating high-risk individuals.
SELECT 
    subject_id,
    COUNT(admission_type) AS icu_admissions
FROM admissions
WHERE admission_type = 'ICU'
GROUP BY subject_id
HAVING COUNT(admission_type) > 2
ORDER BY icu_admissions DESC;

-- 6️⃣ Length of Hospital Stay by Diagnosis
-- Calculates the average length of stay (LOS) for each diagnosis.
SELECT 
    d.icd_code,
    ROUND(AVG(a.dischtime - a.admittime), 2) AS avg_length_of_stay_days,
    COUNT(a.subject_id) AS total_cases
FROM admissions a
JOIN diagnoses_icd d ON a.subject_id = d.subject_id
GROUP BY d.icd_code
ORDER BY avg_length_of_stay_days DESC
LIMIT 10;

-- 7️⃣ Hospital Performance: Readmission Rate by Hospital
-- Identifies hospitals with the highest readmission rates.
WITH readmission_data AS (
    SELECT 
        hospital_id,
        subject_id,
        admittime,
        LAG(admittime) OVER (PARTITION BY subject_id ORDER BY admittime) AS prev_admittime
    FROM admissions
)
SELECT 
    hospital_id,
    COUNT(subject_id) AS total_readmissions,
    ROUND(100.0 * COUNT(subject_id) / (SELECT COUNT(*) FROM admissions WHERE hospital_id = r.hospital_id), 2) AS readmission_rate
FROM readmission_data r
WHERE admittime - prev_admittime <= INTERVAL '30 days'
GROUP BY hospital_id
ORDER BY readmission_rate DESC
LIMIT 10;

-- 8️⃣ Comparing Outcomes of Different Treatment Plans
-- This query compares patient outcomes (mortality rate, length of stay) for different treatments.
SELECT 
    d.icd_code,
    p.drug,
    ROUND(AVG(a.dischtime - a.admittime), 2) AS avg_length_of_stay_days,
    COUNT(CASE WHEN a.deathtime IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) AS mortality_rate,
    COUNT(p.subject_id) AS total_patients
FROM diagnoses_icd d
JOIN prescriptions p ON d.subject_id = p.subject_id
JOIN admissions a ON d.subject_id = a.subject_id
GROUP BY d.icd_code, p.drug
ORDER BY mortality_rate DESC, avg_length_of_stay_days DESC
LIMIT 10;
