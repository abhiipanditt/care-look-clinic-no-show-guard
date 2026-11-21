-- =====================================================================
-- Part 2: SQL Analysis and Business Questions
-- Care Look Clinics No-Show Guard
--
-- HOW TO RUN (MySQL Workbench, MySQL 8+):
--   1. Run SECTION 2.1 (creates the database and the two empty tables).
--   2. Open and run load_data.sql (fills the tables: clinics first, then appointments).
--   3. Run the verification queries at the end of SECTION 2.1.
--   4. Run Sections 2.2 to 2.5 one query at a time.
--
-- Using SQLite online instead of MySQL? Skip the two lines marked [MySQL only].
-- Everything else in this file works on both.
-- =====================================================================


-- ---------------------------------------------------------------------
-- TASK 2.1  Database setup
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS no_show_guard;      -- [MySQL only]
USE no_show_guard;                                -- [MySQL only]

DROP TABLE IF EXISTS appointments;   -- child table first
DROP TABLE IF EXISTS clinics;

CREATE TABLE clinics (
    clinic_id    VARCHAR(5)    PRIMARY KEY,
    clinic_name  VARCHAR(100)  NOT NULL,
    city         VARCHAR(50)   NOT NULL,
    tier         VARCHAR(20)   NOT NULL,
    latitude     DECIMAL(9,4)  NOT NULL,
    longitude    DECIMAL(9,4)  NOT NULL
);

CREATE TABLE appointments (
    appointment_id   VARCHAR(10)   PRIMARY KEY,
    patient_id       VARCHAR(10)   NOT NULL,
    clinic_id        VARCHAR(5)    NOT NULL,
    booked_on        DATE          NOT NULL,
    appt_date        DATE          NOT NULL,
    age              INT           NOT NULL,
    gender           VARCHAR(1)    NOT NULL,
    distance_km      DECIMAL(5,1)  NOT NULL,
    fee_inr          INT           NOT NULL,
    booking_channel  VARCHAR(20)   NOT NULL,
    visit_type       VARCHAR(20)   NOT NULL,
    reminder_sent    VARCHAR(3)    NOT NULL,
    prior_no_shows   INT           NOT NULL,
    status           VARCHAR(20)   NOT NULL,
    lead_days        INT           NOT NULL,
    no_show          INT           NOT NULL,      -- 1 = No-Show, 0 = Attended
    FOREIGN KEY (clinic_id) REFERENCES clinics (clinic_id)
);

-- >>> NOW RUN load_data.sql, then come back here <<<

-- Verify: expected 8 clinics, 990 appointments, 218 no-shows
SELECT COUNT(*) AS clinic_count FROM clinics;
SELECT COUNT(*) AS appointment_count, SUM(no_show) AS no_show_count FROM appointments;

-- Verify structure (MySQL):  DESCRIBE clinics;  DESCRIBE appointments;
-- Verify structure (SQLite): PRAGMA table_info(clinics);  PRAGMA table_info(appointments);


-- ---------------------------------------------------------------------
-- TASK 2.2  No-show rate by clinic
-- Only clinics with at least 95 appointments, highest no-show % first.
-- ---------------------------------------------------------------------
SELECT
    c.clinic_id,
    c.clinic_name,
    c.city,
    COUNT(*)                                   AS total_appointments,
    SUM(a.no_show)                             AS no_shows,
    ROUND(100.0 * SUM(a.no_show) / COUNT(*), 2) AS no_show_pct
FROM appointments AS a
JOIN clinics      AS c ON c.clinic_id = a.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
HAVING COUNT(*) >= 95
ORDER BY no_show_pct DESC;


-- ---------------------------------------------------------------------
-- TASK 2.3  Impact of booking lead time
-- CASE WHEN groups lead_days into buckets (the data ranges from 1 to 45 days).
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN lead_days <= 3  THEN '1. 1-3 days'
        WHEN lead_days <= 7  THEN '2. 4-7 days'
        WHEN lead_days <= 14 THEN '3. 8-14 days'
        WHEN lead_days <= 30 THEN '4. 15-30 days'
        ELSE                      '5. 31+ days'
    END AS lead_time_bucket,
    COUNT(*)                                    AS total_appointments,
    SUM(no_show)                                AS no_shows,
    ROUND(100.0 * SUM(no_show) / COUNT(*), 2)   AS no_show_pct
FROM appointments
GROUP BY lead_time_bucket
ORDER BY lead_time_bucket;


-- ---------------------------------------------------------------------
-- TASK 2.4  Monthly trend (by appointment month)
-- SUBSTR(appt_date, 1, 7) gives 'YYYY-MM'. LAG() compares with the previous month.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT
        SUBSTR(appt_date, 1, 7)                   AS appt_month,
        COUNT(*)                                  AS total_appointments,
        SUM(no_show)                              AS no_shows,
        ROUND(100.0 * SUM(no_show) / COUNT(*), 2) AS no_show_pct
    FROM appointments
    GROUP BY SUBSTR(appt_date, 1, 7)
)
SELECT
    appt_month,
    total_appointments,
    no_shows,
    no_show_pct,
    ROUND(no_show_pct - LAG(no_show_pct) OVER (ORDER BY appt_month), 2) AS change_vs_prev_month_pts
FROM monthly
ORDER BY appt_month;


-- ---------------------------------------------------------------------
-- TASK 2.5  Clinic ranking within each city
-- RANK() restarts for every city (PARTITION BY city); rank 1 = highest no-show %.
-- Note: only Pune and Jaipur have two clinics, so only they get a rank 2.
-- ---------------------------------------------------------------------
WITH clinic_stats AS (
    SELECT
        c.city,
        c.clinic_id,
        c.clinic_name,
        COUNT(*)                                   AS total_appointments,
        SUM(a.no_show)                             AS no_shows,
        ROUND(100.0 * SUM(a.no_show) / COUNT(*), 2) AS no_show_pct
    FROM appointments AS a
    JOIN clinics      AS c ON c.clinic_id = a.clinic_id
    GROUP BY c.city, c.clinic_id, c.clinic_name
)
SELECT
    city,
    clinic_id,
    clinic_name,
    total_appointments,
    no_shows,
    no_show_pct,
    RANK() OVER (PARTITION BY city ORDER BY no_show_pct DESC) AS rank_in_city
FROM clinic_stats
ORDER BY city, rank_in_city;
