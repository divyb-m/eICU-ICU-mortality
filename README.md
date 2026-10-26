# ICU Mortality Prediction (eICU Demo)

**Status:** In progress. Cohort, exploratory analysis, and feature table are done in SQL. Modeling in Python is next.

## Question
Using only data from the first 24 hours of an ICU stay, can a simple model predict in-hospital mortality as well as APACHE IVa, the clinical standard?

## Data
- **Source:** [eICU Collaborative Research Database Demo v2.0.1](https://physionet.org/content/eicu-crd-demo/2.0.1/) (PhysioNet, open access)
- **Contents:** 2,520 ICU stays from 1,841 patients across 186 US hospitals (2014 to 2015)
- **Tools:** SQLite in DBeaver for data preparation; Python (pandas, scikit-learn) for modeling
- The database file is not included in this repo (Physionet restrictions). Download the SQLite version from PhysioNet to rerun the queries.

## Cohort
| Step | Stays/Patients |
|---|---|
| All ICU stays | 2,520 stays (1,841 patients) |
| Removed stays with no recorded outcome | 28 stays removed |
| Kept first ICU stay per patient | **1,820 patients** |

**Final cohort:** 1,820 patients, 168 deaths, **9.2% in-hospital mortality**

## Findings so far

### 1. Mortality rises steadily with age
| Age group | Patients | Deaths | Mortality |
|---|---|---|---|
| Under 50 | 356 | 10 | 2.8% |
| 50 to 64 | 487 | 35 | 7.2% |
| 65 to 79 | 623 | 62 | 10.0% |
| 80+ | 351 | 60 | 17.1% |

Mortality in patients 80 and older is about 6 times higher than in patients under 50. Three patients with no recorded age were excluded from this table.

### 2. Hospital-level mortality can't be compared in this dataset
The demo includes at most 10 patients per hospital. With groups that small, 1 death shifts a hospital's mortality rate by about 10 percentage points, so ranking hospitals would be inaccurate.

## Features (first 24 hours of ICU stay)
| Group | Features | Patients missing |
|---|---|---|
| Demographics | age, sex | 3 (age) |
| Vital signs | heart rate, respiratory rate, SpO2 (min, max, mean of each) | 68 (3.7%) |
| Creatinine | max | 294 (16.2%) |
| BUN | max | 297 (16.3%) |
| WBC | max | 378 (20.8%) |
| Lactate | max | 1,455 (79.9%) |

The 68 patients missing vitals are missing all three. Every other patient has at least one reading of each.

**Benchmark (not a model feature):** APACHE IVa predicted hospital mortality. 408 patients (22.4%) have no usable score: 350 were never scored and 58 were recorded as -1.

## Methods
1. **Explored the patient table.** Found 2,520 ICU stays from 1,841 patients, meaning some patients had more than one stay.
2. **Checked the outcome column.** `hospitaldischargestatus` had 2,280 Alive, 212 Expired, and 28 blank values (stored as empty text, not NULL). The 28 blank stays have no known outcome, so I excluded them.
3. **Cleaned the age column.** Age is stored as text, with some values recorded as '> 89' or left blank. CAST alone turns non-numeric text into 0, so I used a CASE statement to recode '> 89' as 90 (the lowest possible true age, since ages over 89 are capped for de-identification), blank ages as NULL, and everything else with CAST. I matched with `LIKE '>%'` so spacing differences wouldn't cause misses.
4. **Built the cohort.** I used `ROW_NUMBER()` partitioned by patient to keep only each patient's first ICU stay. I removed the blank-outcome stays before ranking, so a patient whose first stay was unlabeled kept their next valid stay. I also created a 0/1 mortality flag and saved the result as a view called `cohort`.
5. **Explored mortality by age and hospital** (see Findings).
6. **Built vital sign features.** From `vitalperiodic`, I kept readings from the first 24 hours (0 to 1,440 minutes after ICU admission) so the model only uses information available on day one. I summarized each vital as min, max, and mean per stay, then used a LEFT JOIN so patients without vitals stay in the cohort.
7. **Caught and fixed blank-text values.** Some vitals and lab results were stored as empty text instead of NULL. SQLite treated them as the highest value in MAX and as 0 in AVG, which produced impossible SpO2 averages in the 50s. I used `NULLIF(column, '')` to convert blanks to NULL so aggregates skip them.
8. **Built lab features.** I pivoted the `lab` table from one row per test to one column per lab using `MAX(CASE WHEN labname = ... THEN ... END)`, taking the highest value in the first 24 hours, since higher values indicate more severe illness for these four labs.
9. **Added the APACHE IVa benchmark.** Predictions were stored as text, so I converted them to numbers with CAST and set -1 ("could not be scored") to NULL. I used IVa, the recalibrated version of APACHE IV.
10. **Saved each stage as a view:** `cohort` → `cohort_vitals` → `cohort_features` → `model_data`. Each view builds on the one before it and never modifies the source tables.

## Planned handling of missing data
- **Creatinine, BUN, WBC (16 to 21% missing):** median imputation in Python, calculated on training data only
- **Lactate (80% missing):** replaced with a yes/no "lactate ordered" flag, since filling 80% of values would mostly invent data, and ordering lactate itself signals clinical concern

## Limitations
- **Small sample:** 168 deaths is enough for a simple model but limits how complex the model can be, and results may not hold on the full eICU database.
- **Sampling design:** up to 10 patients per hospital, so small and large hospitals are equally represented, which doesn't reflect real ICU volumes.
- **Older data:** 2014 to 2015, and clinical practice has changed since then.
- **Approximate ages:** patients over 89 are recorded as 90, so ages in the oldest group are approximate.
- **Excluded stays:** 28 stays with no recorded outcome were removed.
- **Lab window:** only labs from the first 24 hours after ICU admission were used. Labs drawn in the emergency department before admission were not included, which likely increases missingness.
- **APACHE comparison:** 408 patients have no APACHE score, so the benchmark comparison will use a subset of the cohort.

## Next steps
- Load `model_data` into Python and confirm data types and missing counts
- Train a logistic regression baseline and a tree-based model
- Compare model AUROC against APACHE IVa predicted mortality
- Check model performance across subgroups (sex, age group)

## Files
- `cohort_and_exploration.sql`: cohort definition, exploratory queries, and feature table views
