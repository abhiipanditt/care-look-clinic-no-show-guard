# Care Look Clinics - No-Show Guard

An end-to-end pipeline that cleans appointment booking data, finds no-show patterns with SQL,
predicts risky bookings with machine learning, and uses Google Gemini to turn call-centre notes into
structured root causes and recommended actions.

Care Look Clinics runs eight outpatient clinics in six Indian cities (Pune, Nagpur, Jaipur, Kochi, Indore, Lucknow).
A missed appointment leaves an empty doctor slot. Today no-shows are only counted after the day is over; this project
flags risky bookings **in advance**.

## Repository contents

| File | What it is |
|---|---|
| `01_ingest_clean.ipynb` | Part 1 - read, clean, engineer features, call Open-Meteo API, export CSV + SQL |
| `02_queries.sql` | Part 2 - database setup and 4 business-question queries |
| `03_model.ipynb` | Part 3 - Logistic Regression, Decision Tree, Random Forest, tuning, risk scores |
| `04_genai.ipynb` | Part 4 - Gemini analysis of follow-up notes, validation, final recommendations |
| `data/appointments.csv`, `data/clinics.csv`, `data/follow_up_notes.csv` | Input data (as provided) |
| `rejected_rows.json` | Rows rejected by strict type conversion (Task 1.1) |
| `clean_appointments.csv` | Cleaned data: 990 rows, 16 columns, no missing values |
| `load_data.sql` | INSERT statements (clinics first, then appointments) |
| `clinics_enriched.csv` | Clinics + current temperature (created when you run notebook 01, needs internet) |
| `test_risk_score.csv` | Risk score for each of the 198 test-set bookings |
| `all_risk_scores.csv` | Risk score for all 990 bookings (used by Part 4; `split` column shows train/test) |
| `10_analyzed_notes.csv` | Final output of Part 4 (created when you run notebook 04 with your own API key) |

## Installation

Easiest: use **Google Colab** (nothing to install except the Gemini key). To run locally instead:

```
pip install pandas numpy scikit-learn requests pydantic google-genai jupyter
```

Libraries used: `csv`, `json`, `requests`, `pandas`, `numpy`, `scikit-learn`, `pydantic`, `google-genai`.
SQL tools: MySQL Workbench (MySQL 8+) or SQLite online.

## How to run

1. **Part 1** - open `01_ingest_clean.ipynb`, Run all. Creates `rejected_rows.json`, `clinics_enriched.csv`, `clean_appointments.csv`, `load_data.sql`.
2. **Part 2** - in MySQL Workbench: run the *Task 2.1* block of `02_queries.sql`, then run `load_data.sql`, then run the remaining queries one at a time.
3. **Part 3** - open `03_model.ipynb`, Run all. Creates `test_risk_score.csv` and `all_risk_scores.csv`.
4. **Part 4** - get a free key at https://aistudio.google.com, store it as a Colab secret named `GEMINI_API_KEY`, open `04_genai.ipynb`, Run all. Creates `10_analyzed_notes.csv`.

Never commit your API key. The notebook reads it from a Colab secret or a hidden prompt.

## Results (from the actual data)

**Cleaning:** 1,020 raw rows -> 20 exact duplicates removed -> 990 rows after dropping 10 rows with an unusable date or missing status.
32 rows were rejected by the strict `csv` parsing step (12 blank ages, 20 blank distances). 5 impossible ages were set to missing, then 17 missing ages
(12 blank + 5 invalid) were filled with the median (48); 20 missing distances with the median (8.25). 218 of 990 bookings are no-shows (22.0%).

**SQL findings**
- Lead time is the strongest pattern: no-show rate is 13.2% for 1-3 day bookings, 30.0% for 15-30 days and 60.5% for bookings made 31+ days ahead.
- Of clinics with at least 95 appointments, Hadapsar (Pune, 27.3%) and Malviya Nagar (Jaipur, 26.8%) are highest; Vaishali Nagar (Jaipur, 13.9%) is lowest.
  Gomti Nagar (Lucknow) has the highest rate overall (33.3%) but only 90 appointments, so the 95-appointment filter excludes it.
- Monthly no-show rate stays between 20.4% and 24.8% with no strong trend.

**Model (test set, 198 rows)**

| Model | Recall | ROC-AUC |
|---|---|---|
| Logistic Regression | 0.163 | 0.724 |
| Decision Tree | 0.408 | 0.607 |
| Random Forest | 0.245 | 0.606 |
| **Tuned Logistic Regression** (C=0.1, balanced) | **0.633** | **0.721** |

Logistic Regression was selected using 5-fold cross-validation **on the training set only** (average rank of CV recall and CV ROC-AUC); the test set was used only for reporting.
The decision tree clearly overfits (train accuracy 0.999 vs test 0.707). Risk bands behave sensibly: actual no-show rate in the test set is 6.7% (Low), 24.3% (Medium), 41.2% (High).
Only four numeric features are available, so the model is useful for ranking risk, not for certainty.

## Notes and deviations from the brief (and why)

- Column names in the supplied files are `appt_date`, `distance_km`, `fee_inr` etc. (not `appointment_date`/`distance_kilometers`); the code uses the real names.
- Dates in the file are `YYYY-MM-DD`, so the parse format is `%Y-%m-%d` (the brief's `%d-%m-%Y` would fail on every row).
- Booking-channel cleaning changed the text of 295 rows (extra spaces / inconsistent case). Three appt_date entries were placeholder text (`not booked`, `TBD`, `N/A`).
- Part 4 uses the `google-genai` SDK (the current Google library). Model name and thinking level are set in variables at the top of the notebook because Google changes model names often.
- Risk scores for rows that were in the training split are in-sample; `all_risk_scores.csv` labels each row `train` or `test`.
