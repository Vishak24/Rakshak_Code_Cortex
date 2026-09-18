import React, { useState, useCallback } from 'react'
import Sidebar           from './components/Sidebar/Sidebar'
import RiskHeatmap       from './components/RiskHeatmap/RiskHeatmap'
import AlertsPanel       from './components/AlertsPanel/AlertsPanel'
import Reports           from './components/Reports/Reports'
import PatrolDetailPanel from './components/PatrolDetailPanel/PatrolDetailPanel'
import PatrolStats       from './components/PatrolStats/PatrolStats'
import IncidentTimeline  from './components/IncidentTimeline/IncidentTimeline'
import StatsRow          from './components/StatsCard/StatsCard'
import SafetyScorePanel  from './components/SafetyScore/SafetyScorePanel'
import { useRiskData }        from './hooks/useRiskData'
import { useLivePatrols }     from './hooks/useLivePatrols'
import { useActiveIncidents } from './hooks/useActiveIncidents'
import { useSnapshot }        from './hooks/useSnapshot'
import styles from './App.module.css'

const RISK_COLOR = { HIGH: '#FF3B5C', MEDIUM: '#F59E0B', LOW: '#22C55E' }

export default function App() {
  const [lang, setLang]             = useState('en')
  const [activeView, setActiveView] = useState('dashboard')
  const [selectedPatrolId, setSelectedPatrolId] = useState(null)
  // Zone driving the ML Safety Score panel. T. Nagar is the demo zone, so the
  // panel is already populated when the dashboard opens.
  const [selectedZone, setSelectedZone] = useState('600017')

  const { data: zoneMap, loading, error, refetch } = useRiskData()
  const { patrols }                                = useLivePatrols()
  const { incidents, totalSeen }                   = useActiveIncidents()
  const { snapshot }                               = useSnapshot()

  const selectedPatrol = selectedPatrolId
    ? patrols.find(p => p.id === selectedPatrolId) ?? null
    : null

  const handlePatrolClick = useCallback((patrol) => {
    setSelectedPatrolId(patrol?.id ?? null)
  }, [])

  // Most dangerous zones first — this is the list judges scan.
  const zoneRows = zoneMap
    ? Array.from(zoneMap.entries())
        .sort((a, b) => (a[1].safetyScore ?? 100) - (b[1].safetyScore ?? 100))
        .slice(0, 10)
    : []

  return (
    <div className={activeView === 'reports' ? styles.appReports : styles.app}>
      <Sidebar
        lang={lang}
        onLangToggle={() => setLang(l => l === 'en' ? 'ta' : 'en')}
        onRefetch={refetch}
        isRefetching={loading}
        activeView={activeView}
        onViewChange={setActiveView}
      />

      <main className={styles.main}>
        {error && (
          <div className={styles.errorBanner}>
            ⚠ Live safety grid unreachable ({error}) — showing last known scores
          </div>
        )}

        {activeView === 'dashboard' && (
          <>
            {/* Analytics summary — straight from GET /dashboard/snapshot */}
            <StatsRow snapshot={snapshot} lang={lang} />

            <RiskHeatmap
              apiData={zoneMap}
              lang={lang}
              onPatrolClick={handlePatrolClick}
              onZoneSelect={setSelectedZone}
              incidents={incidents}
              patrols={patrols}
            />

            <div className={styles.chartsRow}>
              {/* Zone risk list — doubles as the selector for the ML panel */}
              <div className={styles.chartCard}>
                <div className={styles.chartHdr}>
                  <div className={styles.chartBar} style={{ background: 'var(--accent)' }} />
                  <span className={styles.chartTtl}>ZONE SAFETY (LOWEST FIRST)</span>
                </div>
                <div className={styles.overviewBody}>
                  {loading && zoneRows.length === 0 && (
                    <span style={{ color: 'var(--muted)', fontSize: 12 }}>Loading live grid…</span>
                  )}
                  {zoneRows.length > 0 && (
                    <table className={styles.ovTable}>
                      <thead>
                        <tr><th>Zone</th><th>Risk</th><th>Safety</th></tr>
                      </thead>
                      <tbody>
                        {zoneRows.map(([code, d]) => (
                          <tr
                            key={code}
                            style={{
                              cursor: 'pointer',
                              background: selectedZone === code ? 'rgba(0,212,180,0.08)' : undefined,
                            }}
                            onClick={() => setSelectedZone(code)}
                          >
                            <td>{d.zoneName} <span style={{ color: 'var(--dim)' }}>{code}</span></td>
                            <td style={{ color: RISK_COLOR[d.riskLevel] ?? 'var(--muted)', fontWeight: 700 }}>
                              {d.riskLevel}
                            </td>
                            <td>{d.safetyScore != null ? `${d.safetyScore}/100` : '—'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>

              {/* Live patrol roster from /patrols */}
              <PatrolStats patrols={patrols} />

              {/* Live incident timeline from /dashboard/timeline */}
              <IncidentTimeline />
            </div>
          </>
        )}

        {activeView === 'reports' && (
          <Reports resolvedIncidents={[]} />
        )}
      </main>

      {activeView === 'dashboard' && (
        <div className={styles.rightCol}>
          <SafetyScorePanel pincode={selectedZone} />
          <AlertsPanel
            incidents={incidents}
            totalSeen={totalSeen}
            lang={lang}
          />
        </div>
      )}

      <PatrolDetailPanel
        patrol={selectedPatrol}
        onClose={() => setSelectedPatrolId(null)}
      />
    </div>
  )
}
