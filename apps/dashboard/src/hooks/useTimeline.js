import { useState, useEffect, useRef } from 'react'
import { ENDPOINTS } from '../config/api'

/**
 * Polls GET /dashboard/timeline every 5s — flattened, newest-first incident
 * events across all incidents. Returns { events, generatedAt }.
 */
export function useTimeline(limit = 40) {
  const [events, setEvents] = useState([])
  const [generatedAt, setGeneratedAt] = useState(null)
  const timer = useRef(null)

  useEffect(() => {
    const poll = async () => {
      try {
        const res = await fetch(`${ENDPOINTS.dashboardTimeline}?limit=${limit}`, {
          signal: AbortSignal.timeout(8000),
        })
        if (!res.ok) return
        const data = await res.json()
        const list = Array.isArray(data?.events) ? data.events : (Array.isArray(data) ? data : [])
        setEvents(list)
        if (data?.generated_at) setGeneratedAt(data.generated_at)
      } catch {
        // keep last known events
      }
    }
    poll()
    timer.current = setInterval(poll, 5000)
    return () => clearInterval(timer.current)
  }, [limit])

  return { events, generatedAt }
}
