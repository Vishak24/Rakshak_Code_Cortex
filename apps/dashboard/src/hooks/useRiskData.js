import { useState, useEffect, useCallback, useRef } from 'react'
import { ENDPOINTS } from '../config/api'

const POLL_MS = Number(import.meta.env.VITE_POLL_HEATMAP_MS) || 10_000

/**
 * Live per-zone safety grid from GET /heatmap/live (SageMaker-backed, adjusted
 * for recent + active incidents). No mock data — if the API is unreachable the
 * previous live snapshot is retained and `error` is set.
 *
 * IMPORTANT — the API returns `safety_score` where **high = safe**
 * (Guindy 100 = LOW risk, T. Nagar 13 = HIGH risk). The heat layer wants a
 * *danger* weight, so `heatWeight = 1 - safety_score/100`.
 *
 * Returns:
 *   zones   — raw live rows: { pincode, zone_name, lat, lng, safety_score,
 *             risk_level, incidents_today, active_incidents, source }
 *   data    — Map<pincode, { zoneName, safetyScore, riskLevel, heatWeight,
 *             lat, lng, incidentsToday, activeIncidents, source }>
 */
export function useRiskData() {
  const [zones, setZones]     = useState([])
  const [data, setData]       = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState(null)
  const timer                 = useRef(null)

  const fetchAll = useCallback(async () => {
    try {
      const res = await fetch(ENDPOINTS.heatmapLive, { signal: AbortSignal.timeout(8000) })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)

      const payload = await res.json()
      const rows = Array.isArray(payload?.zones) ? payload.zones : []
      if (rows.length === 0) throw new Error('empty zone grid')

      const map = new Map()
      rows.forEach(r => {
        const safety = r.safety_score != null ? Number(r.safety_score) : null
        map.set(String(r.pincode), {
          zoneName:        r.zone_name ?? String(r.pincode),
          safetyScore:     safety,
          riskLevel:       (r.risk_level ?? 'LOW').toUpperCase(),
          // danger weight for the heat layer: high safety → cool, low safety → hot
          heatWeight:      safety != null ? Math.max(0, Math.min(1, 1 - safety / 100)) : 0.5,
          lat:             r.lat != null ? Number(r.lat) : null,
          lng:             r.lng != null ? Number(r.lng) : null,
          incidentsToday:  r.incidents_today ?? 0,
          activeIncidents: r.active_incidents ?? 0,
          source:          r.source ?? 'model',
        })
      })

      setZones(rows)
      setData(map)
      setError(null)
    } catch (err) {
      // Keep the last known live grid rather than substituting mock values.
      setError(err.message ?? 'heatmap unavailable')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAll()
    timer.current = setInterval(fetchAll, POLL_MS)
    return () => clearInterval(timer.current)
  }, [fetchAll])

  return { zones, data, loading, error, refetch: fetchAll }
}
