# Security Model

Written honestly: what's actually in place, and what's a known,
acknowledged gap for a hackathon-scope demo. Neither list is hidden from
the other.

## In place

- **No embedded IAM credentials.** Every Lambda uses its execution role
  (`rakshak-lambda-role`) via the default credential chain — confirmed
  this pass via `get-function-configuration` on every managed function,
  and by inspection of `rakshak-reports-handler`, which previously had
  embedded access keys that stopped working when the underlying IAM user
  key was deactivated (`UnrecognizedClientException`); it was rewritten to
  use the role instead.
- **Least-privilege IAM.** `rakshak-lambda-role` has exactly: CloudWatch
  Logs (basic execution), S3 read-only (for model artifacts),
  DynamoDB CRUD scoped to the `rakshak-*` tables (inline policy, not
  `dynamodb:*` on `*`), and `sagemaker:InvokeEndpoint` scoped to the one
  named endpoint. No admin, no wildcard resource ARNs.
- **Input validation on incident creation.** `POST /sos` rejects an
  empty/non-object body, and rejects lat/lng outside a Chennai bounding
  box (`12.7–13.4`, `79.9–80.4`) as `400` rather than silently creating a
  junk incident — this used to return `201` for a malformed or clearly
  out-of-area payload.
- **Status-transition validation.** `PATCH .../status` rejects unknown
  status strings (`400`) and rejects moving a terminal incident
  (`resolved`/`cancelled`) back to a live state (`400`) — previously
  accepted arbitrary strings.
- **Structured error responses.** Every handler wraps its router in
  `try/except`, returning a JSON `500` with a message rather than a raw
  Lambda crash trace reaching the client.
- **CORS is explicit and scoped to real methods** (`GET,POST,PATCH,OPTIONS`)
  — not a wildcard-everything configuration, even though the origin is `*`.

## Known gaps (not fixed in this pass — stated, not hidden)

- **No authentication or authorization on any route.** Every endpoint,
  including patrol status changes and incident resolution, is callable by
  anyone with the base URL. Acceptable for a demo where the "attacker"
  surface is a public hackathon judge, not acceptable for a real
  deployment handling real incidents. The fix is a Lambda authorizer (JWT
  from a real citizen/officer login) in front of the HTTP API — no code
  change needed in the handlers themselves, since `rc.parse_body`/routing
  don't currently assume anything about caller identity beyond
  self-reported `user_id`/`officer_id` fields.
- **No rate limiting.** HTTP API supports per-route throttling
  (`ThrottleSettings`) — not configured. A public `POST /sos` with no
  rate limit is a plausible abuse vector (junk-incident flooding); the
  Chennai bounding-box check limits nonsense payloads but not volume.
- **`user_id`/`officer_id` are self-reported, unverified strings.** Without
  authentication, nothing stops a caller from claiming any identity.
  Directly downstream of the "no auth" gap above.
- **DynamoDB scans on a couple of hot paths** (`DATABASE_SCHEMA.md`'s GSI
  note) are a cost/DoS-surface consideration at scale, not a data-exposure
  one — every scan result is already meant to be visible to any caller
  given the "no auth" gap.
- **No WAF** in front of API Gateway.
- **IAM access key rotation**: an IAM *user* access key (referenced in
  prior project docs as deactivated-but-not-deleted,
  `AKIA...7YPR`-prefixed) was not re-verified as fully deleted this pass —
  flagged in `AWS_RESOURCES.md`, action item: confirm deletion via
  `aws iam list-access-keys` on whichever user owns it.

## Data handling

- **No PII beyond what a citizen voluntarily submits** in an SOS
  (self-reported name/user_id, GPS location, optional victim age on the
  ML side as a feature default, not stored per-incident). No payment
  data, no auth credentials stored anywhere in this backend.
- **The ML dataset contains no real personal data** — it's synthetic
  (`DATASET_CARD.md`); there is no re-identification risk because no row
  corresponds to a real person or event.

## If this were a real deployment

Priority order: (1) authentication + authorization in front of every
write route at minimum, (2) rate limiting on `POST /sos` and
`POST /predict`, (3) SNS-connected alarms so the existing CloudWatch
alarms actually notify someone (`OBSERVABILITY.md`), (4) a formal review
of what "risk score" data should and shouldn't be exposed to which caller
role once auth exists.
