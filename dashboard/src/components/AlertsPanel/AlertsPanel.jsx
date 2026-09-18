import React from 'react'
import s from './AlertsPanel.module.css'

function timeAgo(ts) {
  const diff = Math.max(0, Math.floor((Date.now() - new Date(ts)) / 1000))
  if (diff < 60)   return `${diff}s ago`
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  return `${Math.floor(diff / 3600)}h ago`
}

const STATUS_LABEL = {
  dispatched: '🚔 En Route',
  reached:    '📍 On Scene',
  awaiting:   'Awaiting Patrol',
  resolved:   'Resolved',
  cancelled:  'Cancelled',
}

/**
 * Active Incidents — read-only view of the live SOS feed.
 *
 * Dispatch is fully automatic on the backend (POST /sos/live assigns the
 * nearest free unit in the same call), so there is deliberately no dispatch
 * action here: an operator click could only re-issue what already happened.
 */
export default function AlertsPanel({ incidents = [], totalSeen = 0, lang }) {
  const riskLabel = (r) => {
    if (lang !== 'ta') return r
    return r === 'HIGH' ? 'அதிக ஆபத்து' : r === 'MEDIUM' ? 'நடுத்தர' : 'குறைந்த'
  }

  return (
    <aside className={s.panel}>
      <div className={s.hdr}>
        <div className={s.pulse} />
        <span className={s.ttl}>{lang === 'ta' ? 'செயலில் சம்பவங்கள்' : 'ACTIVE INCIDENTS'}</span>
        <span className={s.badge}>{incidents.length}</span>
      </div>

      <div className={s.list}>
        {incidents.length === 0 && (
          <div style={{ color: 'var(--dim)', fontSize: 12, textAlign: 'center', marginTop: 24 }}>
            {totalSeen > 0 ? 'All incidents resolved' : 'No active SOS alerts'}
          </div>
        )}

        {incidents.map((ev, i) => (
          <div key={ev.sos_id} className={`${s.evt}${i === 0 ? ' ' + s.fresh : ''}`}>
            <div className={s.evtTop}>
              <span className={s.evtLoc}>{ev.name}</span>
              <span className={`${s.riskBadge} ${s[ev.risk]}`}>{riskLabel(ev.risk)}</span>
            </div>

            {ev.patrolId && (
              <div className={s.assign}>
                <span className={s.unit}>{ev.patrolId}</span>
                {ev.officer && <span className={s.officer}>{ev.officer}</span>}
                {ev.status === 'dispatched' && ev.etaSeconds != null && (
                  <span className={s.eta}>
                    ETA {Math.max(0, Math.round(ev.etaSeconds))}s
                  </span>
                )}
              </div>
            )}

            <div className={s.evtBot}>
              <span className={s.evtTime}>{timeAgo(ev.ts)}</span>
              <span className={`${s.pill} ${s[ev.status] ?? ''}`}>
                {STATUS_LABEL[ev.status] ?? ev.status}
              </span>
            </div>
          </div>
        ))}
      </div>
    </aside>
  )
}
