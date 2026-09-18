import { useState, useEffect, useRef } from 'react'
import { ENDPOINTS } from '../config/api'

const POLL_MS = Number(import.meta.env.VITE_POLL_DASHBOARD_SNAPSHOT_MS) || 5000

/**
 * Live command snapshot from GET /dashboard/snapshot — the source for the
 * Analytics Summary Cards. Every number here is computed server-side from
 * DynamoDB; nothing is derived or invented client-side.
 *
 * Shape: { generated_at, patrols:{total,on_patrol,responding,at_scene,returning},
 *          officers_available, officers_on_duty,
 *          incidents:{active_total,awaiting,dispatched,on_scene},
 *          resolved_today, cancelled_today, high_risk_zones[], active_incident_ids[] }
 */
export function useSnapshot() {
  const [snapshot, setSnapshot] = useState(null)
  const [error, setError]       = useState(null)
  const timer                   = useRef(null)

  useEffect(() => {
    const poll = async () => {
      try {
        const res = await fetch(ENDPOINTS.dashboardSnapshot, { signal: AbortSignal.timeout(8000) })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        setSnapshot(await res.json())
        setError(null)
      } catch (err) {
        setError(err.message ?? 'snapshot unavailable')
      }
    }
    poll()
    timer.current = setInterval(poll, POLL_MS)
    return () => clearInterval(timer.current)
  }, [])

  return { snapshot, error }
}
