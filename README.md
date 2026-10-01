# eICU-ICU-mortality
### About project

- Goal: Predict ICU mortality from demographics, vitals and labs using eICU demo data
- Data: eICU Collaborative Research Database Demo (physioNet), SQLite in DBeaver, patient data table
  
1. I wanted to determine the number of rows and check for missing values. I found that the 1841 patients had 2520 stays in the hospitals.
2. This is selecting for the discharge status that evaluates each person based on whether they are alive or dead at the time of discharge. This also checks for any missing or null values. There are 28 missing values in  hospitaldischargestatus, with 2280 being alive and 212 recorded as expired. 
3. Casting was used as some of the values in the age column have been recorded as ‘> 89’. Cast converts numeric text into integers and non-numeric text into 0. Over here, I changed everything non numerical into an integer. I also used a CASE statement so that I could convert the ‘> 89’ values to an integer and chose 90 as the patients are at least 90. I also added a statement to the CASE to record the 28 missing values (from hospitaldischargestatus) as NULL values. 
4. To practice saving a code, CTEs and window functions I first wrote the window function to list out the patientid, taking only the first instance of admission as the same patient id was associated with multiple ICU stays. I then categorized the patients based on age and then grouped them based on their discharge status (’Alive’ or ‘Expired’). I saved the code for future reference by using ‘CREATE VIEW’.
5. I wanted to determine the mortality percentage. I used the code saved in 4 to get the values needed for the mortality count. Among 1820 patients, 168 deaths were recorded with a mortality percentage of 9.2%.
6. Now that I have established a dataset, I wanted to look at the mortality percentage and whether age had an effect on it. I grouped the patients by age using the CAST I made in #3. I grouped them in 4 bins with a 5th bin for unknowns. I found that the mortality percent increased with age.
7. I wanted to look at the mortality percentage with respect to each hospital within the dataset. However, I found that since the data only included information from up to 10 patients per hospital, I realized that I could not accurately calculate the mortality percentage per hospital.

Limitations:

- The eICU dataset includes data from up to  10 patients only, regardless of hospital size.
- Given this, I cannot accurately compute the actual mortality percent per hospital as if n = 10, even a death of 1 increases the mortality percentage by 10%.
- Similarly, data is from 2014-2015 only and in the age column, some ages are represented by ‘> 89’ which is not a meaningful number.
