import React from 'react'
import s from './StatsCard.module.css'

const ICONS = {
  sos: <svg viewBox="0 0 24 24"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>,
  car: <svg viewBox="0 0 24 24"><path d="M5 17H3v-5l2-5h14l2 5v5h-2"/><circle cx="7.5" cy="17" r="2"/><circle cx="16.5" cy="17" r="2"/><path d="M5 12h14"/></svg>,
  bolt: <svg viewBox="0 0 24 24"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>,
  check: <svg viewBox="0 0 24 24"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>,
}

/**
 * Analytics Summary Cards — every value comes straight from
 * GET /dashboard/snapshot. Renders "—" while the snapshot is still in flight
 * rather than substituting a placeholder number.
 */
export default function StatsRow({ snapshot, lang }) {
  const activeSos  = snapshot?.incidents?.active_total
  const onPatrol   = snapshot?.patrols?.on_patrol
  const responding = (snapshot?.patrols?.responding ?? 0) + (snapshot?.patrols?.at_scene ?? 0)
  const resolved   = snapshot?.resolved_today

  const show = (v) => (v == null ? '—' : v)

  const cards = [
    {
      key: 'sos', tone: 'd', icon: ICONS.sos, value: show(activeSos),
      label: lang === 'ta' ? 'செயலில் SOS' : 'Active SOS',
    },
    {
      key: 'patrol', tone: 's', icon: ICONS.car, value: show(onPatrol),
      label: lang === 'ta' ? 'ரோந்தில்' : 'Units On Patrol',
    },
    {
      key: 'resp', tone: 'w', icon: ICONS.bolt,
      value: snapshot ? responding : '—',
      label: lang === 'ta' ? 'பதிலளிக்கிறது' : 'Responding',
    },
    {
      key: 'res', tone: 's', icon: ICONS.check, value: show(resolved),
      label: lang === 'ta' ? 'இன்று தீர்க்கப்பட்டது' : 'Resolved Today',
    },
  ]

  return (
    <div className={s.row}>
      {cards.map(c => (
        <div key={c.key} className={s.card}>
          <div className={`${s.ico} ${s[c.tone]}`}>{c.icon}</div>
          <div>
            <div className={`${s.val} ${s[c.tone]}`}>{c.value}</div>
            <div className={s.lbl}>{c.label}</div>
          </div>
        </div>
      ))}
    </div>
  )
}
