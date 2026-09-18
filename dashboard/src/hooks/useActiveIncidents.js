import { useState, useEffect, useRef } from 'react'
import { ENDPOINTS } from '../config/api'
import { ZONES } from '../constants/zones'

const POLL_MS = Number(import.meta.env.VITE_POLL_SOS_FEED_MS) || 2000

// pincode → area name, for display only
const PINCODE_NAME = {}
ZONES.forEach(z => { PINCODE_NAME[z.c] = z.n })

function areaName(row) {
  const raw = row.zone_name ?? row.area_name ?? row.pincode
  if (!raw) return 'Unknown Zone'
  const str = String(raw).trim()
  if (/^\d{6}$/.test(str)) return PINCODE_NAME[str] ? `${PINCODE_NAME[str]} (${str})` : str
  return str
}

/** Backend status → the three UI states the demo cares about. */
function uiStatus(raw) {
  const s = String(raw ?? '').toLowerCase()
  if (s === 'reached' || s === 'on_scene' || s === 'at_scene') return 'reached'
  if (s === 'dispatched' || s === 'en_route')                  return 'dispatched'
  if (s === 'resolved')                                        return 'resolved'
  if (s === 'cancelled')                                       return 'cancelled'
  return 'awaiting'
}

/**
 * Single source of truth for live SOS on the dashboard — polls
 * GET /police/sos/active every 2s. Both the map markers and the Active
 * Incidents panel read from this, so they can never disagree.
 *
 * An incident that leaves the active feed (resolved or cancelled) is moved
 * into `history` and its marker disappears, which is exactly the P4 behaviour.
 *
 * Returns { incidents, history, totalSeen, error }
 */
export function useActiveIncidents() {
  const [incidents, setIncidents] = useState([])
  const [history, setHistory]     = useState([])
  const [totalSeen, setTotalSeen] = useState(0)
  const [error, setError]         = useState(null)

  const seenRef = useRef(new Set())
  const liveRef = useRef(new Map())   // sos_id → last known normalised row

  useEffect(() => {
    let cancelled = false

    const poll = async () => {
      try {
        const res = await fetch(ENDPOINTS.sosActive, { signal: AbortSignal.timeout(8000) })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const raw = await res.json()
        if (!Array.isArray(raw) || cancelled) return

        const rows = raw.map(i => {
          const lat = i.lat ?? i.latitude
          const lng = i.lng ?? i.longitude
          return {
            ...i,
            sos_id:      i.sos_id ?? i.incident_id,
            incident_id: i.sos_id ?? i.incident_id,
            name:        areaName(i),
            risk:        String(i.risk_level ?? 'HIGH').toUpperCase(),
            status:      uiStatus(i.status),
            ts:          new Date(i.created_at ?? i.triggered_at ?? Date.now()),
            latitude:    lat != null ? Number(lat) : null,
            longitude:   lng != null ? Number(lng) : null,
            zone:        i.pincode ?? i.zone_name ?? null,
            etaSeconds:  i.eta_seconds != null ? Number(i.eta_seconds) : null,
            patrolId:    i.assigned_patrol_id ?? null,
            officer:     i.assigned_officer ?? null,
            vehicle:     i.assigned_vehicle ?? null,
            citizen:     i.username ?? i.user_id ?? null,
          }
        })

        // Anything previously live but no longer in the feed has terminated.
        const liveIds = new Set(rows.map(r => r.sos_id))
        const departed = []
        liveRef.current.forEach((row, id) => {
          if (!liveIds.has(id)) departed.push({ ...row, status: 'resolved', resolvedAt: new Date() })
        })

        liveRef.current = new Map(rows.map(r => [r.sos_id, r]))

        let fresh = 0
        rows.forEach(r => {
          if (!seenRef.current.has(r.sos_id)) { seenRef.current.add(r.sos_id); fresh++ }
        })

        setIncidents(rows)
        if (fresh > 0) setTotalSeen(t => t + fresh)
        if (departed.length > 0) setHistory(h => [...departed, ...h].slice(0, 25))
        setError(null)
      } catch (err) {
        if (!cancelled) setError(err.message ?? 'feed unavailable')
      }
    }

    poll()
    const id = setInterval(poll, POLL_MS)
    return () => { cancelled = true; clearInterval(id) }
  }, [])

  return { incidents, history, totalSeen, error }
}
