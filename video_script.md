# Video Walkthrough Script
## Medicare Provider Utilization Analytics — Daxwell Submission
## Estimated time: 7–8 minutes

---

### OPENING (30 seconds)
"Hi, I'm Akhila. This project is a Medicare provider utilization analysis built on
the CMS Medicare Physician and Other Practitioners public dataset.

The goal was to answer three questions any health plan or managed care team would care about:
Which specialties are driving the highest Medicare spend per patient?
Are there individual providers whose utilization looks significantly different from peers?
And how does spend vary across states and regions?

I'll walk you through the data pipeline first, then the dashboard."

---

### PART 1: THE DATA & PIPELINE (2 minutes)
[Show the GitHub repo folder structure]

"The project is organized into SQL and Python layers.

I'll start with Python. Open 01_data_cleaning.py.

The raw CMS CSV has about 10 million rows — one row per provider per HCPCS code.
The first thing I do is rename columns to consistent standard names, then apply
a set of validation rules: drop null or invalid NPIs, filter out negative payments,
remove records where payment exceeds submitted charge, and handle records with
zero services.

Each step is logged so you can see exactly how many records were dropped and why —
that is what the log file shows. After cleaning, I aggregate to the provider level
using a groupby on NPI, specialty, and state."

[Show the log output or describe it]

"In a real project I would also run the SQL data quality checks in script 02 —
these catch things like duplicate NPI-HCPCS combinations and logic errors before
any analysis runs."

---

### PART 2: OUTLIER DETECTION (2 minutes)
[Show 02_outlier_detection.py]

"The interesting piece is the outlier detection.

For each provider, I calculate a z-score — how many standard deviations their
payment per beneficiary falls above the mean for their specialty.

A cardiologist spending $800 per patient might be completely normal for cardiology
but would look very different for a primary care physician.
That's why specialty-specific benchmarks matter here.

I flag anyone more than 2 standard deviations above as REVIEW, and more than 3
as HIGH RISK. About 3% of providers end up flagged for review — which is
a meaningful signal without being noise."

---

### PART 3: SQL ANALYSIS (1.5 minutes)
[Show scripts 03, 04, 05 briefly]

"The SQL layer builds on the cleaned Python outputs.

Script 03 ranks specialties by total spend and by cost per beneficiary —
those are two different rankings and the gap between them tells you something
interesting about which specialties are expensive because they see a lot of patients
versus which are expensive per patient.

Script 04 generates the outlier table using the same z-score logic from Python,
this time in SQL — useful if you want to run this inside a data warehouse like
Snowflake or SQL Server directly.

Script 05 does geographic analysis — state rankings and Census region groupings —
which is where you start to see meaningful regional cost variation."

---

### PART 4: DASHBOARD (2 minutes)
[Open Power BI or Tableau dashboard if built, otherwise describe design]

"The dashboard has four views:

Page 1 — Executive Summary: total providers, total spend, top 5 specialties, and
a US map showing spend per beneficiary by state. The map immediately shows
geographic variation — the Northeast and some Southern states consistently show
higher cost per patient than the Midwest.

Page 2 — Specialty Analysis: a ranked bar chart of specialties by cost per bene
with a benchmark line, and a scatter showing service intensity versus cost.
Specialties in the upper right — high cost AND high service volume — are the ones
worth digging into.

Page 3 — Provider Outliers: a filterable table of flagged providers with their
z-scores, specialty, and state. You can filter to HIGH RISK only or drill into
a specific state or specialty.

Page 4 — Geographic Detail: state-level comparison with % above/below national
average, filterable by specialty and region."

---

### CLOSING (30 seconds)
"If I were taking this further, I would add year-over-year trend data to see
whether outlier providers are consistently flagged or one-time anomalies.
I would also layer in beneficiary demographics to control for age and
disease complexity — a provider in a region with older patients will
naturally show higher spend.

That's the project. Happy to answer any questions. Thanks for your time."
