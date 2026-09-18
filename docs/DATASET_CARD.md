# Dataset Card — Rakshak Chennai Safety Signals

## Summary

**This is a synthetically generated dataset.** It is not a download of, or
derived from, any external public dataset file. Every row is produced by
`ml/generate_chennai_synthetic_datav2.py` and `ml/Finaldataset.py`, running
locally with a fixed random seed, over a hand-curated table of real Chennai
pincodes, coordinates, and area/neighborhood names.

We say this plainly and up front because the alternative — implying a
dataset was sourced from Kaggle, NCRB, or another public repository when it
wasn't — would misrepresent the model's actual training data to anyone
evaluating it. The project's own prior competition materials
(`Context_Files/# Rakshak — Competition Brief` in the source archive)
independently reached the same conclusion and instructed the team to
"acknowledge the synthetic data limitation honestly" — judges had already
flagged synthetic-only data as a known weakness, and obscuring it would
have made that worse, not better.

| | |
|---|---|
| Rows | 20,800 (15,000 from the original 20-area generator + 5,800 from a 29-zone, 200-rows-each extension) |
| Zones | 44 unique Chennai pincodes |
| Features | 17 model inputs + identifying/timestamp columns — see `FEATURE_ENGINEERING.md` |
| Label | `risk_level` ∈ {0: Low, 1: Medium, 2: High} |
| Generation | Deterministic, rule-based, `numpy.random.seed(42)` |
| Real-world validation | **None.** No row corresponds to an actual reported incident. |

## What "synthetic" means concretely here

The generator does **not** sample from real crime statistics. It:

1. Starts from a hand-authored table of 20 Chennai areas (`chennai_areas` in
   `generate_chennai_synthetic_datav2.py`) with real pincodes, real
   lat/lng, and an assigned `base_risk` (0–1) and `avg_police_response_min`
   — both **estimated by the team**, not measured.
2. Samples an occurrence time, weighting evening/night hours higher in
   higher-`base_risk` areas — a rule the team wrote, not a pattern learned
   from data.
3. Derives `risk_level` from a hand-written scoring formula (`risk_score =
   base_risk + bonuses for night/high recent signal count/slow
   response/slow reporting`, thresholded at 0.4/0.65) — see
   `FEATURE_ENGINEERING.md` for the exact formula.
4. `Finaldataset.py` extends coverage to all 44 pincodes the backend
   actually serves, using a **latitude-band heuristic**
   (`lat >= 13.10 → high risk, >= 13.05 → medium, else low` — a simple
   proxy for "North Chennai reads as higher-density/higher-risk in local
   context") rather than any per-area estimate.

## Why build it this way instead of using a real crime dataset

- **No real incident-level dataset for Chennai SOS/safety signals with
  this feature shape (reporting delay, response time, recent signal
  density) was available to the team** within the hackathon's scope and
  timeline. Public crime datasets that do exist (e.g. India's National
  Crime Records Bureau "Crime in India" annual reports) are aggregated at
  district/state/city level, not per-incident with lat/lng and response
  timing — they inform general domain framing (see below) but cannot be
  joined or sampled into per-incident training rows.
- Using real reported-crime data for a **safety-perception and
  patrol-allocation demo** also carries a real risk of encoding historical
  policing bias into a "risk score" presented as objective — a synthetic,
  clearly-labeled dataset avoids that specific harm while the concept is
  validated.
- The generator's structure (documented, deterministic, inspectable) means
  every row's provenance is fully traceable to a rule in
  `ml/generate_chennai_synthetic_datav2.py` or `ml/Finaldataset.py` — this
  is an advantage a black-box or unlicensed scraped dataset would not have.

## Domain grounding (context, not training data)

Two things genuinely came from outside the team's own assumptions and are
cited here as **background context that shaped feature selection**, not as
sources the training rows were sampled from:

- **General public safety domain knowledge** — that response time and
  reporting delay are meaningful safety-outcome factors, and that risk
  perception varies by time-of-day and day-of-week, is widely documented
  in public safety literature and in India's own National Crime Records
  Bureau (NCRB) "Crime in India" annual reports
  (https://ncrb.gov.in/en/crime-in-india). These reports are cited as
  general domain context for *why* `response_time_minutes`,
  `reporting_delay_minutes`, `is_night`, and `is_rush_hour` were chosen as
  features — not as a data source the synthetic generator samples from or
  validates against.
- **Real Chennai geography** — the 44 pincodes, their coordinates, and
  area/neighborhood names are real and independently verifiable (public
  postal/administrative data), even though the *risk values* attached to
  them are the team's own synthetic assignment, not a measurement.

## Known limitations (stated honestly, not minimized)

- **No ground truth.** `risk_level` is a formula, not an observed outcome.
  The model's ~100% test accuracy (see `ML_PIPELINE.md`) reflects that it
  is learning the *generator's own rule*, not a noisy real-world signal —
  this is expected and is not evidence of real-world predictive power.
- **`base_risk` for the original 20 areas and the latitude-band heuristic
  for the remaining 24 are both estimates**, not measurements. A
  real deployment would need this replaced with actual reported-incident
  density, ideally sourced through a formal data-sharing arrangement with
  Chennai City Police or a public-safety NGO (see "Path to real data"
  below).
- **Synthetic data cannot capture real spatial correlation, seasonality,
  or event-driven spikes** (a festival, a specific unsafe intersection) —
  only what the generator's rules encode.

## Path to real data (future work, not implemented here)

A production deployment would replace this generator with:
1. A data-sharing agreement with Chennai City Police or the Tamil Nadu
   state police for de-identified, aggregated incident/response-time data.
2. Or a partnership with a public-safety NGO already collecting
   citizen-reported safety signals (e.g. Safecity-style crowdsourced
   reports), with appropriate consent and privacy handling.
3. Retraining the same feature pipeline (`FEATURE_ENGINEERING.md`) against
   that real data — the model architecture and training script would not
   need to change, only the input rows.

This is explicitly **not** attempted in this pass — the task scope is to
document the existing, already-trained model honestly, not to retrain it.
