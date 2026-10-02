# eICU-ICU-mortality
### About project

- Goal: Predict ICU mortality from demographics, vitals and labs using eICU demo data
- Data: eICU Collaborative Research Database Demo (physioNet), SQLite in DBeaver, patient data table
  
**Status:** In progress. Cohort definition and exploratory analysis are done. Feature building (first 24 hours of vitals and labs) and the model are next.

## Question
Using only data from the first 24 hours of an ICU stay, can a simple model predict in-hospital mortality as well as APACHE IV, the clinical standard?

## Data
- **Source:** [eICU Collaborative Research Database Demo v2.0.1](https://physionet.org/content/eicu-crd-demo/2.0.1/) (PhysioNet, open access)
- **Contents:** 2,520 ICU stays from 1,841 patients across 186 US hospitals (2014 to 2015)
- **Tools:** SQLite in DBeaver for data preparation; Python (pandas, scikit-learn) planned for modeling
- The database file is not included in this repo. Download the SQLite version from PhysioNet to rerun the queries as access requires CITI training.

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

Mortality in patients 80 and older is ~6 times higher than in patients under 50. Three patients with no recorded age were excluded from this table.

### 2. Hospital-level mortality can't be compared in this dataset
The demo includes at most 10 patients per hospital. Since the groups are small, a single death shifts a hospital's mortality rate by about 10 percentage points, so ranking hospitals would mostly reflect noise.

## Methods
1. **Explored the patient table.** Found 2,520 ICU stays from 1,841 patients, meaning some patients had more than one stay.
2. **Checked the outcome column.** `hospitaldischargestatus` had 2,280 Alive, 212 Expired, and 28 blank values (stored as empty text, not NULL). The 28 blank stays have no known outcome, so I excluded them.
3. **Cleaned the age column.** Age is stored as text, with some values recorded as '> 89' or left blank. CAST alone turns non-numeric text into 0, so I used a CASE statement to recode '> 89' as 90 (the lowest possible true age, since ages over 89 are capped for de-identification), blank ages as NULL, and everything else with CAST. I matched with `LIKE '>%'` instead of an exact string so spacing differences wouldn't cause misses.
4. **Built the cohort.** I used `ROW_NUMBER()` partitioned by patient to keep only each patient's first ICU stay. I removed the blank-outcome stays before ranking, so a patient whose first stay was unlabeled kept their next valid stay. I also created a 0/1 mortality flag and saved the result as a view called `cohort`.
5. **Calculated overall mortality** from the cohort: 168 deaths among 1,820 patients (9.2%).
6. **Grouped mortality by age** into four bins plus an unknown group.
7. **Grouped mortality by hospital**, which showed the 10-patient cap described above.

## Limitations
- **Small sample:** 168 deaths is enough for a simple model but limits how complex the model can be, and results may not hold on the full eICU database.
- **Sampling design:** up to 10 patients per hospital, so small and large hospitals are equally represented, which doesn't reflect real ICU volumes.
- **Older data:** 2014 to 2015, and clinical practice has changed since then.
- **Approximate ages:** patients over 89 are recorded as 90, so ages in the oldest group are approximate.
- **Excluded stays:** 28 stays with no recorded outcome were removed.

## Next steps
- Build first-24-hour features from vital signs (`vitalperiodic`) and labs (`lab`)
- Train a logistic regression baseline and a tree-based model in Python
- Compare model AUROC against APACHE IV predicted mortality
- Check model performance across subgroups (sex, age group)

## Files
- `cohort_and_exploration.sql`: cohort view and exploratory queries
