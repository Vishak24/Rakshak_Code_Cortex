import React from 'react'
import s from './PatrolStats.module.css'

// Matches the map legend exactly — blue is a unit on its patrol route.
const STATUS_COLOR = {
  Patrolling: '#3B82F6',
  Responding: '#F59E0B',
  AtScene:    '#FF3B5C',
  Returning:  '#60A5FA',
}

const STATUS_LABEL = {
  Patrolling: 'Patrolling',
  Responding: '🚔 En Route',
  AtScene:    'At Scene',
  Returning:  'Returning',
}

/**
 * PatrolStats — all patrol units from the live GET /patrols feed (passed in as
 * `patrols` by App so there is a single poller). Shows status + live ETA.
 */
export default function PatrolStats({ patrols = [] }) {
  const total = patrols.length

  return (
    <div className={s.card}>
      <div className={s.hdr}>
        <div className={s.bar} />
        <span className={s.title}>OFFICERS ON DUTY</span>
        <span className={s.totalBadge}>{total} units</span>
      </div>

      <div className={s.unitList}>
        {patrols.map(p => {
          const col   = STATUS_COLOR[p.status] ?? '#3B82F6'
          const label = STATUS_LABEL[p.status] ?? p.status
          const eta   = p.status === 'Responding' && p.eta_seconds != null
            ? ` · ETA ${Math.max(0, Math.round(p.eta_seconds))}s` : ''
          return (
            <div key={p.id} className={s.unitRow}>
              <div className={s.unitDot} style={{ background: col }} />
              <span className={s.unitVehicle}>{p.id}</span>
              <span className={s.unitName}>{p.name ?? p.zone_name ?? p.zone}</span>
              <span className={s.unitStatus} style={{ color: col }}>
                {label}{eta}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
