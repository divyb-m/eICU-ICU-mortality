-- ICU Mortality Prediction (eICU Demo)
-- Cohort definition and exploratory analysis
-- Database: eICU-CRD Demo v2.0.1 (SQLite)

-- 1. Size check: total stays vs. unique patients
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT uniquepid) AS n_patients,
       COUNT(DISTINCT patientunitstayid) AS n_icu_stays
FROM patient;

-- 2. Outcome distribution (28 stays have a blank status)
SELECT hospitaldischargestatus,
       COUNT(*) AS n
FROM patient
GROUP BY hospitaldischargestatus;

-- 3. Find non-numeric age values ('> 89' and blank)
SELECT age, COUNT(*) AS n
FROM patient
WHERE CAST(age AS INTEGER) = 0
GROUP BY age;

-- 4. Cohort view: first ICU stay per patient, known outcome only,
--    age recoded to a number, 0/1 mortality flag
DROP VIEW IF EXISTS cohort;

CREATE VIEW cohort AS
WITH ranked AS (
  SELECT uniquepid,
         patientunitstayid,
         hospitaldischargeyear,
         hospitalid,
         gender,
         unitdischargeoffset,
         CASE
           WHEN age LIKE '>%' THEN 90   -- ages over 89 are capped for de-identification
           WHEN age = '' THEN NULL
           ELSE CAST(age AS INTEGER)
         END AS age_num,
         CASE
           WHEN hospitaldischargestatus = 'Expired' THEN 1 ELSE 0
         END AS died,
         ROW_NUMBER() OVER (
           PARTITION BY uniquepid
           ORDER BY hospitaldischargeyear, patienthealthsystemstayid, unitvisitnumber
         ) AS rn
  FROM patient
  WHERE hospitaldischargestatus <> ''   -- to exclude stays with no recorded outcome
)
SELECT *
FROM ranked
WHERE rn = 1;

-- 5. Overall cohort mortality
SELECT COUNT(*) AS n,
       SUM(died) AS deaths,
       ROUND(100.0 * SUM(died) / COUNT(*), 1) AS pct_death
FROM cohort;

-- 6. Mortality by age group
SELECT CASE
         WHEN age_num < 50 THEN 'under_50'
         WHEN age_num BETWEEN 50 AND 64 THEN '50_to_64'
         WHEN age_num BETWEEN 65 AND 79 THEN '65_to_79'
         WHEN age_num >= 80 THEN '80_plus'
         ELSE 'unknown'
       END AS age_group,
       COUNT(*) AS n,
       SUM(died) AS deaths,
       ROUND(100.0 * SUM(died) / COUNT(*), 1) AS mortality_percent
FROM cohort
GROUP BY age_group
ORDER BY MIN(age_num);

-- 7. Mortality by hospital (shows the demo's cap of 10 patients per hospital)
SELECT h.hospitalid,
       COUNT(*) AS n,
       SUM(c.died) AS deaths,
       ROUND(100.0 * SUM(c.died) / COUNT(*), 1) AS mortality_percent
FROM cohort c
JOIN hospital h ON c.hospitalid = h.hospitalid
GROUP BY h.hospitalid
ORDER BY mortality_percent DESC;
