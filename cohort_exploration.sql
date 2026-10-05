-- ICU Mortality Prediction (eICU Demo)
-- Cohort definition, exploratory analysis, and feature table
-- Database: eICU-CRD Demo v2.0.1 (SQLite)


-- =========================================================
-- PART 1: EXPLORATION
-- =========================================================

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


-- =========================================================
-- PART 2: COHORT
-- =========================================================

-- 4. Cohort view: first ICU stay per patient, known outcome only,
--    age recoded to a number, mortality evaluation
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
  WHERE hospitaldischargestatus <> ''   -- exclude stays with no recorded outcome
)
SELECT *
FROM ranked
WHERE rn = 1;

-- 5. Overall cohort mortality (1,820 patients, 168 deaths, 9.2%)
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

-- 7. Mortality by hospital (to validate that the demo's cap is about 10 patients per hospital)
SELECT h.hospitalid,
       COUNT(*) AS n,
       SUM(c.died) AS deaths,
       ROUND(100.0 * SUM(c.died) / COUNT(*), 1) AS mortality_percent
FROM cohort c
JOIN hospital h ON c.hospitalid = h.hospitalid
GROUP BY h.hospitalid
ORDER BY mortality_percent DESC;


-- =========================================================
-- PART 3: FEATURES
-- =========================================================

-- 8. Vital signs: min/max/mean in the first 24 hours.
--    NULLIF converts blank text to NULL to prevent aggregation functions from representing incorrect values.
--    LEFT JOIN keeps the 68 patients with no vitals.
DROP VIEW IF EXISTS cohort_vitals;
CREATE VIEW cohort_vitals AS
WITH vitals AS (
  SELECT patientunitstayid,
         MIN(NULLIF(heartrate, ''))   AS hr_min,
         MAX(NULLIF(heartrate, ''))   AS hr_max,
         AVG(NULLIF(heartrate, ''))   AS hr_avg,
         MIN(NULLIF(respiration, '')) AS resp_min,
         MAX(NULLIF(respiration, '')) AS resp_max,
         AVG(NULLIF(respiration, '')) AS resp_avg,
         MIN(NULLIF(sao2, ''))        AS sao2_min,
         MAX(NULLIF(sao2, ''))        AS sao2_max,
         AVG(NULLIF(sao2, ''))        AS sao2_avg
  FROM vitalperiodic
  WHERE observationoffset BETWEEN 0 AND 1440   -- first 24 hours only
  GROUP BY patientunitstayid
)
SELECT c.*,
       v.hr_min, v.hr_max, v.hr_avg,
       v.resp_min, v.resp_max, v.resp_avg,
       v.sao2_min, v.sao2_max, v.sao2_avg
FROM cohort c
LEFT JOIN vitals v ON c.patientunitstayid = v.patientunitstayid;

-- 9. Available lab tests, most common first (used to find exact lab names)
SELECT labname, COUNT(*) AS n
FROM lab
GROUP BY labname
ORDER BY n DESC;

-- 10. Labs: highest value in the first 24 hours, pivoted to one column per lab
DROP VIEW IF EXISTS cohort_features;
CREATE VIEW cohort_features AS
WITH labs AS (
  SELECT patientunitstayid,
         MAX(CASE WHEN labname = 'creatinine' THEN NULLIF(labresult, '') END) AS creat_max,
         MAX(CASE WHEN labname = 'BUN'        THEN NULLIF(labresult, '') END) AS BUN_max,
         MAX(CASE WHEN labname = 'lactate'    THEN NULLIF(labresult, '') END) AS lact_max,
         MAX(CASE WHEN labname = 'WBC x 1000' THEN NULLIF(labresult, '') END) AS WBC_max
  FROM lab
  WHERE labresultoffset BETWEEN 0 AND 1440   -- first 24 hours only
  GROUP BY patientunitstayid
)
SELECT cv.*, l.creat_max, l.BUN_max, l.lact_max, l.WBC_max
FROM cohort_vitals cv
LEFT JOIN labs l ON cv.patientunitstayid = l.patientunitstayid;

-- 11. Missing lab counts (creatinine 294, BUN 297, lactate 1,455, WBC 378)
SELECT SUM(CASE WHEN creat_max IS NULL THEN 1 ELSE 0 END) AS missing_creat,
       SUM(CASE WHEN BUN_max   IS NULL THEN 1 ELSE 0 END) AS missing_bun,
       SUM(CASE WHEN lact_max  IS NULL THEN 1 ELSE 0 END) AS missing_lact,
       SUM(CASE WHEN WBC_max   IS NULL THEN 1 ELSE 0 END) AS missing_wbc
FROM cohort_features;


-- =========================================================
-- PART 4: BENCHMARK
-- =========================================================

-- 12. Final modeling table: features plus APACHE IVa prediction (benchmark only, not a feature).
--     Predictions are stored as text, so: blanks -> NULL, cast to a number,
--     then -1 ("could not be scored") -> NULL.
DROP VIEW IF EXISTS model_data;
CREATE VIEW model_data AS
WITH apache AS (
  SELECT patientunitstayid,
         NULLIF(CAST(NULLIF(predictedhospitalmortality, '') AS REAL), -1) AS apache_pred
  FROM apachepatientresult
  WHERE apacheversion = 'IVa'   -- filter before the join so unscored patients are kept
)
SELECT cf.*, ap.apache_pred
FROM cohort_features cf
LEFT JOIN apache ap ON cf.patientunitstayid = ap.patientunitstayid;

-- 13. Check: row count should be 1,820; 408 patients have no usable APACHE score
SELECT COUNT(*) AS n,
       SUM(CASE WHEN apache_pred IS NULL THEN 1 ELSE 0 END) AS missing_apache,
       MIN(apache_pred) AS min_pred,
       MAX(apache_pred) AS max_pred
FROM model_data;
