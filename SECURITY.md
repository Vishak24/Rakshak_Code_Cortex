# Security

See [`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md) for the full,
honest breakdown of what's in place and what's a known gap in the current
deployment (notably: **no authentication on any route** — acceptable for
this project's current hackathon-demo scope, not for a production
deployment handling real incidents).

## Reporting a vulnerability

This is a hackathon/demo project without a dedicated security contact
process yet. If you find an issue, open a GitHub issue describing it, or
contact the maintainers directly if the issue involves live credentials or
could be actively exploited against the deployed demo (`docs/AWS_RESOURCES.md`
has the current account/API details — don't disclose those in a public
issue if the finding involves them directly).

## Scope

- No embedded IAM credentials in any Lambda — confirmed via
  `get-function-configuration` on every managed function.
- IAM roles are least-privilege, scoped to the specific `rakshak-*`
  resources they need (`docs/SECURITY_MODEL.md`).
- The ML training data is entirely synthetic — no real personal data is
  processed by the model or stored in its training set
  (`docs/DATASET_CARD.md`).
- Live incident data (citizen-submitted SOS reports) contains
  self-reported location and identity fields with no authentication
  backing them — treat any data in the live demo tables as
  non-authoritative and non-sensitive for that reason, not as verified
  incident reports.
