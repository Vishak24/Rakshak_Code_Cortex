import React, { useState, useEffect } from 'react'
import s from './SafetyScorePanel.module.css'
import { ENDPOINTS } from '../../config/api'

const POLL_MS = Number(import.meta.env.VITE_POLL_PREDICTION_MS) || 15_000

const RISK_COLOR = { HIGH: '#FF3B5C', MEDIUM: '#F59E0B', LOW: '#22C55E' }

function scoreColor(score) {
  if (score == null) return 'var(--muted)'
  if (score >= 60) return '#22C55E'
  if (score >= 34) return '#F59E0B'
  return '#FF3B5C'
}

/**
 * The single ML Safety Score panel — GET /prediction/zone/{pincode}, served by
 * the live XGBoost model on SageMaker. Every value shown is straight from the
 * model response; there are no client-side defaults or fallbacks.
 *
 * The API returns SAFETY (0–100, high = safe) plus its own risk label, so both
 * are displayed as-is and never re-derived.
 *
 * Props: pincode — the selected zone (defaults to T. Nagar 600017)
 */
export default function SafetyScorePanel({ pincode = '600017' }) {
  const [result, setResult]   = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState(null)

  useEffect(() => {
    if (!pincode) return
    let cancelled = false

    const fetchScore = async (showSpinner) => {
      if (showSpinner) setLoading(true)
      try {
        const res = await fetch(ENDPOINTS.predictionZone(String(pincode)), {
          signal: AbortSignal.timeout(12000),
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const d = await res.json()
        if (cancelled) return
        setResult(d)
        setError(null)
      } catch (err) {
        if (!cancelled) setError(err.message ?? 'model unavailable')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    fetchScore(true)
    const id = setInterval(() => fetchScore(false), POLL_MS)
    return () => { cancelled = true; clearInterval(id) }
  }, [pincode])

  const score = result?.safetyScore != null ? Math.round(result.safetyScore) : null
  const risk  = (result?.riskLevel ?? '').toUpperCase()
  const conf  = result?.confidence != null ? Math.round(result.confidence * 100) : null
  const src   = result?.source ?? null

  return (
    <div className={s.panel}>
      <div className={s.hdr}>
        <div className={s.bar} />
        <span className={s.title}>ML SAFETY SCORE</span>
        {src && (
          <span className={`${s.badge} ${src === 'sagemaker' ? s.badgeLive : ''}`}>
            {src === 'sagemaker' ? 'SageMaker' : src}
          </span>
        )}
      </div>

      {loading && !result && <div className={s.empty}>Querying model…</div>}

      {error && !result && (
        <div className={s.error}>Model unreachable — {error}</div>
      )}

      {result && (
        <>
          <div className={s.scoreRow}>
            <span className={s.score} style={{ color: scoreColor(score) }}>
              {score != null ? score : '—'}
            </span>
            <div className={s.scoreMeta}>
              <span className={s.outOf}>/ 100</span>
              <span className={s.scoreLbl}>SAFETY SCORE</span>
            </div>
          </div>

          <div className={s.rows}>
            <div className={s.row}>
              <span className={s.key}>Zone</span>
              <span className={s.val}>{result.zone ?? result.pincode ?? '—'}</span>
            </div>
            <div className={s.row}>
              <span className={s.key}>Pincode</span>
              <span className={s.valMono}>{result.pincode ?? pincode}</span>
            </div>
            <div className={s.row}>
              <span className={s.key}>Risk Level</span>
              <span className={s.val} style={{ color: RISK_COLOR[risk] ?? 'var(--muted)', fontWeight: 700 }}>
                {risk || '—'}
              </span>
            </div>
            <div className={s.row}>
              <span className={s.key}>Confidence</span>
              <span className={s.valMono}>{conf != null ? `${conf}%` : '—'}</span>
            </div>
          </div>

          <div className={s.meter}>
            <div
              className={s.meterFill}
              style={{
                width: `${score ?? 0}%`,
                background: scoreColor(score),
              }}
            />
          </div>
          <div className={s.foot}>
            Higher is safer · live XGBoost inference
            {error && <span className={s.stale}> · retrying</span>}
          </div>
        </>
      )}
    </div>
  )
}
