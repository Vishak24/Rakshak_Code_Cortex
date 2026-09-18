import React, { useState, useEffect } from 'react'
import s from './Sidebar.module.css'

function pad(n) { return String(n).padStart(2, '0') }

function LiveClock() {
  const [time, setTime] = useState(() => {
    const now = new Date()
    return `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
  })

  useEffect(() => {
    const id = setInterval(() => {
      const now = new Date()
      setTime(`${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`)
    }, 1000)
    return () => clearInterval(id)
  }, [])

  return <span className={s.clockDigits}>{time}</span>
}

export default function Sidebar({ lang, onLangToggle, onRefetch, isRefetching, activeView, onViewChange }) {
  return (
    <aside className={s.sidebar}>
      {/* Brand */}
      <div className={s.brand}>
        <svg width="30" height="30" viewBox="0 0 30 30" fill="none">
          <path d="M15 2L3 7V15C3 21.075 8.325 26.85 15 29C21.675 26.85 27 21.075 27 15V7L15 2Z"
            fill="rgba(0,212,180,0.12)" stroke="#00D4B4" strokeWidth="1.5"/>
          <path d="M10 15L13.5 18.5L20 12" stroke="#00D4B4" strokeWidth="2"
            strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
        <div>
          <div className={s.brandName}>RAKSHAK</div>
          <div className={s.brandSub}>Safety Intelligence</div>
        </div>
      </div>

      {/* Nav */}
      <nav className={s.nav}>
        <div
          className={`${s.navItem} ${activeView === 'dashboard' ? s.active : ''}`}
          onClick={() => onViewChange?.('dashboard')}
        >
          <svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>
          <span>{lang === 'ta' ? 'டாஷ்போர்டு' : 'Dashboard'}</span>
        </div>
        <div
          className={`${s.navItem} ${activeView === 'reports' ? s.active : ''}`}
          onClick={() => onViewChange?.('reports')}
        >
          <svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14,2 14,8 20,8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
          <span>{lang === 'ta' ? 'அறிக்கைகள்' : 'Reports'}</span>
        </div>
        <div className={s.navItem}>
          <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
          <span>{lang === 'ta' ? 'அமைப்புகள்' : 'Settings'}</span>
        </div>
      </nav>

      {/* Clock + Refresh — replaces Active Patrols */}
      <div className={s.clockPanel}>
        <div className={s.clockLabel}>CURRENT TIME</div>
        <LiveClock />
        <button
          className={`${s.refreshBtn}${isRefetching ? ' ' + s.refreshing : ''}`}
          onClick={onRefetch}
          disabled={isRefetching}
          title="Refresh all zone scores"
        >
          {/* Spinner / refresh icon */}
          <svg
            className={isRefetching ? s.spin : ''}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <polyline points="23 4 23 10 17 10"/>
            <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
          </svg>
          {isRefetching ? 'Refreshing…' : 'Refresh Scores'}
        </button>
      </div>

      {/* Footer */}
      <div className={s.footer}>
        <div className={s.liveRow}>
          <div className={s.liveDot}/>
          <div>
            <div className={s.liveLbl}>{lang === 'ta' ? 'நேரடி' : 'LIVE'}</div>
            <div className={s.liveSub}>{lang === 'ta' ? 'சென்னை கட்டளை' : 'Chennai Command'}</div>
          </div>
        </div>
        <button className={s.langBtn} onClick={onLangToggle}>
          <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
          <span>{lang === 'ta' ? 'English' : 'தமிழ்'}</span>
        </button>
      </div>
    </aside>
  )
}
