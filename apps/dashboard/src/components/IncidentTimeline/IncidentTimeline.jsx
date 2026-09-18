import React from 'react'
import s from './IncidentTimeline.module.css'
import { useTimeline } from '../../hooks/useTimeline'

const TYPE_COLOR = {
  'Created':          '#FF3B5C',
  'SOS Created':      '#FF3B5C',
  'Patrol Assigned':  '#A855F7',
  'En Route':         '#F59E0B',
  'Dispatched':       '#F59E0B',
  'Reached':          '#38BDF8',
  'Resolved':         '#22C55E',
  'Cancelled':        '#94A3B8',
}

function timeAgo(ts) {
  const t = new Date(ts).getTime()
  if (isNaN(t)) return ''
  const d = Math.max(0, Math.floor((Date.now() - t) / 1000))
  if (d < 60) return `${d}s ago`
  if (d < 3600) return `${Math.floor(d / 60)}m ago`
  if (d < 86400) return `${Math.floor(d / 3600)}h ago`
  return `${Math.floor(d / 86400)}d ago`
}

/**
 * Live incident timeline — GET /dashboard/timeline, newest-first, auto-refresh 5s.
 */
export default function IncidentTimeline() {
  const { events } = useTimeline(40)

  return (
    <div className={s.card}>
      <div className={s.hdr}>
        <div className={s.bar} />
        <span className={s.title}>INCIDENT TIMELINE</span>
        <span className={s.count}>{events.length}</span>
      </div>

      <div className={s.scroll}>
        {events.length === 0 && (
          <div className={s.empty}>No incident activity yet</div>
        )}
        {events.map((e, i) => {
          const col = TYPE_COLOR[e.type] ?? '#94A3B8'
          return (
            <div key={`${e.sos_id}-${e.type}-${e.ts}-${i}`} className={s.row}>
              <div className={s.dot} style={{ background: col }} />
              <div className={s.body}>
                <div className={s.line1}>
                  <span className={s.type} style={{ color: col }}>{e.type}</span>
                  <span className={s.zone}>{e.zone_name ?? e.pincode ?? ''}</span>
                  <span className={s.ago}>{timeAgo(e.ts)}</span>
                </div>
                <div className={s.detail}>
                  {e.detail ?? ''}{e.patrol_id ? ` · ${e.patrol_id}` : ''}
                  <span className={s.sid}>{e.sos_id}</span>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
