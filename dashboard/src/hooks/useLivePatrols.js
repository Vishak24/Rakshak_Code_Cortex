import { useState, useEffect, useRef, useCallback } from 'react'
import { ENDPOINTS } from '../config/api'

const POLL_MS = Number(import.meta.env.VITE_POLL_PATROLS_MS) || 3000

/**
 * Live patrol state from GET /patrols (backend computes each unit's position on
 * every request from its route + elapsed time). Poll every 3s.
 *
 * Returns:
 *   patrols        — normalised rows: { id, name, officer, vehicle, zone,
 *                    zone_name, status, position:{lat,lng}, eta_seconds,
 *                    assigned_sos_id, heading }
 *   patrolStates   — alias of `patrols` (back-compat with PatrolStats)
 *   updatePatrolStatus(id, status) — optimistic local override between polls
 */
const STATUS_MAP = (raw) => {
  const s = String(raw ?? '').toLowerCase().replace(/[_\s]+/g, '')
  if (s.startsWith('respond') || s === 'enroute' || s === 'ontheway') return 'Responding'
  if (s === 'atscene' || s === 'onscene')                              return 'AtScene'
  if (s.startsWith('return'))                                          return 'Returning'
  return 'Patrolling'
}

export function useLivePatrols() {
  const [patrols, setPatrols] = useState([])
  const timer = useRef(null)

  const fetchPatrols = useCallback(async () => {
    try {
      const res = await fetch(ENDPOINTS.patrolsList, { signal: AbortSignal.timeout(8000) })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = await res.json()
      if (!Array.isArray(data)) return
      setPatrols(data.map((it, idx) => {
        const pos = it.position ?? {}
        return {
          id:              it.patrol_id ?? it.id ?? `P${String(idx + 1).padStart(3, '0')}`,
          name:            it.name ?? it.officer ?? 'Unit',
          officer:         it.officer ?? it.name ?? 'Officer',
          vehicle:         it.vehicle ?? '—',
          zone:            it.zone ?? '',
          zone_name:       it.zone_name ?? it.zone ?? '',
          status:          STATUS_MAP(it.status),
          position:        (pos.lat != null && pos.lng != null)
                             ? { lat: Number(pos.lat), lng: Number(pos.lng) }
                             : null,
          eta_seconds:     it.eta_seconds != null ? Number(it.eta_seconds) : null,
          assigned_sos_id: it.assigned_sos_id ?? null,
          heading:         it.heading ?? 'patrol',
        }
      }))
    } catch {
      // keep last known state on error
    }
  }, [])

  const updatePatrolStatus = useCallback((patrolId, newStatus) => {
    setPatrols(prev => prev.map(p => p.id === patrolId ? { ...p, status: STATUS_MAP(newStatus) } : p))
  }, [])

  useEffect(() => {
    fetchPatrols()
    timer.current = setInterval(fetchPatrols, POLL_MS)
    return () => clearInterval(timer.current)
  }, [fetchPatrols])

  return { patrols, patrolStates: patrols, updatePatrolStatus, refetch: fetchPatrols }
}
