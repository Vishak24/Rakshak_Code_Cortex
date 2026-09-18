import React, { useState, useCallback, useEffect, useRef } from 'react'
import s from './Reports.module.css'
import { ENDPOINTS } from '../../config/api'

// ── Column definitions ────────────────────────────────────────────────────────
const COLUMNS = [
  { key: 'latitude',                   label: 'Latitude',              type: 'number', step: '0.0001' },
  { key: 'longitude',                  label: 'Longitude',             type: 'number', step: '0.0001' },
  { key: 'pincode',                    label: 'Pincode',               type: 'number', sticky: true   },
  { key: 'hour',                       label: 'Hour',                  type: 'number', min: 0, max: 23 },
  { key: 'day_of_week',                label: 'Day of Week',           type: 'number', min: 0, max: 6  },
  { key: 'is_weekend',                 label: 'Is Weekend',            type: 'select', options: ['0','1'] },
  { key: 'is_night',                   label: 'Is Night',              type: 'select', options: ['0','1'] },
  { key: 'is_evening',                 label: 'Is Evening',            type: 'select', options: ['0','1'] },
  { key: 'is_rush_hour',               label: 'Is Rush Hour',          type: 'select', options: ['0','1'] },
  { key: 'reporting_delay_minutes',    label: 'Reporting Delay (min)', type: 'number' },
  { key: 'response_time_minutes',      label: 'Response Time (min)',   type: 'number' },
  { key: 'victim_age',                 label: 'Victim Age',            type: 'number' },
  { key: 'signal_count_last_7d',       label: 'Signals Last 7d',       type: 'number' },
  { key: 'signal_count_last_30d',      label: 'Signals Last 30d',      type: 'number' },
  { key: 'signal_density_ratio',       label: 'Signal Density Ratio',  type: 'number', step: '0.01' },
  { key: 'area_encoded',               label: 'Area Encoded',          type: 'number' },
  { key: 'neighborhood_encoded',       label: 'Neighborhood Encoded',  type: 'number' },
]

// ── Seed data ─────────────────────────────────────────────────────────────────
const SEED_ROWS = [
  { latitude: 13.0600, longitude: 80.2400, pincode: 600017, hour: 21, day_of_week: 5, is_weekend: 1, is_night: 0, is_evening: 1, is_rush_hour: 0, reporting_delay_minutes: 12, response_time_minutes: 8,  victim_age: 24, signal_count_last_7d: 14, signal_count_last_30d: 45, signal_density_ratio: 0.31, area_encoded: 3,  neighborhood_encoded: 7  },
  { latitude: 13.1067, longitude: 80.2206, pincode: 600006, hour: 23, day_of_week: 6, is_weekend: 1, is_night: 1, is_evening: 0, is_rush_hour: 0, reporting_delay_minutes: 20, response_time_minutes: 14, victim_age: 31, signal_count_last_7d: 8,  signal_count_last_30d: 29, signal_density_ratio: 0.28, area_encoded: 1,  neighborhood_encoded: 2  },
  { latitude: 13.1200, longitude: 80.2850, pincode: 600007, hour: 18, day_of_week: 2, is_weekend: 0, is_night: 0, is_evening: 1, is_rush_hour: 1, reporting_delay_minutes: 5,  response_time_minutes: 6,  victim_age: 19, signal_count_last_7d: 21, signal_count_last_30d: 60, signal_density_ratio: 0.35, area_encoded: 5,  neighborhood_encoded: 11 },
  { latitude: 13.0500, longitude: 80.2100, pincode: 600058, hour: 9,  day_of_week: 1, is_weekend: 0, is_night: 0, is_evening: 0, is_rush_hour: 1, reporting_delay_minutes: 3,  response_time_minutes: 10, victim_age: 27, signal_count_last_7d: 6,  signal_count_last_30d: 22, signal_density_ratio: 0.27, area_encoded: 8,  neighborhood_encoded: 15 },
  { latitude: 12.9800, longitude: 80.1700, pincode: 600081, hour: 22, day_of_week: 4, is_weekend: 0, is_night: 1, is_evening: 0, is_rush_hour: 0, reporting_delay_minutes: 35, response_time_minutes: 22, victim_age: 22, signal_count_last_7d: 18, signal_count_last_30d: 52, signal_density_ratio: 0.35, area_encoded: 12, neighborhood_encoded: 19 },
]

let nextId = SEED_ROWS.length + 1

function makeBlankRow() {
  const row = {}
  COLUMNS.forEach(c => { row[c.key] = '' })
  return row
}

// ── Auto-derive time-based flags from hour / day_of_week ─────────────────────
function applyAutoCalc(row, changedKey) {
  const updated = { ...row }
  const hour = Number(updated.hour)
  const dow  = Number(updated.day_of_week)

  if (changedKey === 'hour' || changedKey === 'day_of_week') {
    if (!isNaN(hour)) {
      updated.is_night     = (hour >= 22 || hour <= 5)  ? 1 : 0
      updated.is_evening   = (hour >= 17 && hour <= 21) ? 1 : 0
      updated.is_rush_hour = [8, 9, 17, 18, 19].includes(hour) ? 1 : 0
    }
    if (!isNaN(dow)) {
      updated.is_weekend = (dow === 0 || dow === 6) ? 1 : 0
    }
  }

  // Auto signal density ratio
  const s7  = Number(updated.signal_count_last_7d)
  const s30 = Number(updated.signal_count_last_30d)
  if (
    (changedKey === 'signal_count_last_7d' || changedKey === 'signal_count_last_30d') &&
    !isNaN(s7) && !isNaN(s30) && s30 > 0
  ) {
    updated.signal_density_ratio = parseFloat((s7 / s30).toFixed(2))
  }

  return updated
}

export default function Reports({ resolvedIncidents = [] }) {
  const [rows, setRows]         = useState(() =>
    SEED_ROWS.map((r, i) => ({ ...r, _id: i, approvalStatus: 'pending' }))
  )
  const [editing, setEditing]   = useState({})
  const [reqState, setReqState] = useState({})
  const [flashIds, setFlashIds] = useState(new Set()) // row ids currently flashing
  const seenIncidentIds         = useRef(new Set())   // prevent duplicate prepends

  // ── Load existing reports from backend on mount ───────────────────────────
  useEffect(() => {
    const load = async () => {
      try {
        const res = await fetch(ENDPOINTS.reportsGet, { signal: AbortSignal.timeout(8000) })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const items = await res.json()
        if (!Array.isArray(items) || items.length === 0) return
        const remoteRows = items.map((item, i) => ({
          ...item,
          _id:            nextId++,
          approvalStatus: item.status ?? 'pending',
        }))
        setRows(prev => {
          // Avoid duplicates if the same incident_id already exists locally
          const existingIds = new Set(prev.map(r => r.incident_id).filter(Boolean))
          const fresh = remoteRows.filter(r => !existingIds.has(r.incident_id))
          return [...prev, ...fresh]
        })
      } catch {
        console.warn('Reports API unavailable, showing local data only')
      }
    }
    load()
  }, []) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!resolvedIncidents || resolvedIncidents.length === 0) return
    const toAdd = resolvedIncidents.filter(inc => !seenIncidentIds.current.has(inc._incidentId ?? inc.pincode + inc.hour))
    if (toAdd.length === 0) return

    const newRows = toAdd.map(inc => {
      const id = nextId++
      const uid = inc._incidentId ?? (inc.pincode + inc.hour + id)
      seenIncidentIds.current.add(uid)
      return { ...inc, _id: id }
    })

    setRows(prev => [...newRows, ...prev])
    const newIds = new Set(newRows.map(r => r._id))
    setFlashIds(prev => new Set([...prev, ...newIds]))
    setTimeout(() => {
      setFlashIds(prev => {
        const next = new Set(prev)
        newIds.forEach(id => next.delete(id))
        return next
      })
    }, 2000)
  }, [resolvedIncidents])

  // ── Cell edit ─────────────────────────────────────────────────────────────
  const startEdit = useCallback((rowId, colKey, isReadOnly) => {
    if (isReadOnly) return
    setEditing(prev => ({ ...prev, [`${rowId}_${colKey}`]: true }))
  }, [])

  const commitEdit = useCallback((rowId, colKey, rawValue) => {
    setRows(prev => prev.map(r => {
      if (r._id !== rowId) return r
      const col = COLUMNS.find(c => c.key === colKey)
      const value = col?.type === 'number' ? (rawValue === '' ? '' : Number(rawValue)) : rawValue
      const updated = { ...r, [colKey]: value }
      return applyAutoCalc(updated, colKey)
    }))
    setEditing(prev => { const n = { ...prev }; delete n[`${rowId}_${colKey}`]; return n })
  }, [])

  // ── Add blank row ─────────────────────────────────────────────────────────
  const addRow = () => {
    setRows(prev => [...prev, { ...makeBlankRow(), _id: nextId++, approvalStatus: 'pending' }])
  }

  // ── Submit for review ─────────────────────────────────────────────────────
  const submitRow = async (rowId) => {
    const row = rows.find(r => r._id === rowId)
    if (!row) return
    setReqState(prev => ({ ...prev, [rowId]: 'submitting' }))
    try {
      await fetch(ENDPOINTS.reportsSubmit, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(row),
        signal: AbortSignal.timeout(8000),
      })
    } catch { /* silently continue — optimistic UI */ }
    setRows(prev => prev.map(r => r._id === rowId ? { ...r, approvalStatus: 'pending' } : r))
    setReqState(prev => { const n = { ...prev }; delete n[rowId]; return n })
  }

  // ── Approve ───────────────────────────────────────────────────────────────
  const approveRow = async (rowId) => {
    const row = rows.find(r => r._id === rowId)
    setReqState(prev => ({ ...prev, [rowId]: 'approving' }))
    try {
      await fetch(ENDPOINTS.reportsApprove(row?.incident_id ?? rowId), {
        method: 'PATCH',
        signal: AbortSignal.timeout(8000),
      })
    } catch { /* optimistic */ }
    setRows(prev => prev.map(r => r._id === rowId ? { ...r, approvalStatus: 'approved' } : r))
    setReqState(prev => { const n = { ...prev }; delete n[rowId]; return n })
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  const rejectRow = async (rowId) => {
    const row = rows.find(r => r._id === rowId)
    setReqState(prev => ({ ...prev, [rowId]: 'rejecting' }))
    try {
      await fetch(ENDPOINTS.reportsReject(row?.incident_id ?? rowId), {
        method: 'PATCH',
        signal: AbortSignal.timeout(8000),
      })
    } catch { /* optimistic */ }
    setRows(prev => prev.map(r => r._id === rowId ? { ...r, approvalStatus: 'rejected' } : r))
    setReqState(prev => { const n = { ...prev }; delete n[rowId]; return n })
  }

  // ── Summary counts ────────────────────────────────────────────────────────
  const total    = rows.length
  const pending  = rows.filter(r => r.approvalStatus === 'pending').length
  const approved = rows.filter(r => r.approvalStatus === 'approved').length
  const rejected = rows.filter(r => r.approvalStatus === 'rejected').length

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className={s.wrap}>
      {/* Toolbar */}
      <div className={s.toolbar}>
        <div className={s.titleRow}>
          <div className={s.bar} />
          <span className={s.title}>INCIDENT SIGNAL REPORTS</span>
        </div>
        <button className={s.addBtn} onClick={addRow}>+ Add Zone</button>
      </div>

      {/* Summary bar */}
      <div className={s.summaryBar}>
        <span className={s.sumItem}>Total: <b>{total}</b></span>
        <span className={s.sumItem + ' ' + s.sumPending}>⏳ Pending: <b>{pending}</b></span>
        <span className={s.sumItem + ' ' + s.sumApproved}>✅ Approved: <b>{approved}</b></span>
        <span className={s.sumItem + ' ' + s.sumRejected}>❌ Rejected: <b>{rejected}</b></span>
      </div>

      {/* Table */}
      <div className={s.tableWrap}>
        <table className={s.table}>
          <thead>
            <tr>
              {COLUMNS.map(c => (
                <th key={c.key} className={c.sticky ? s.stickyTh : ''}>{c.label}</th>
              ))}
              <th className={s.statusTh}>Status</th>
              <th className={s.actionTh}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(row => {
              const isRejected  = row.approvalStatus === 'rejected'
              const isApproved  = row.approvalStatus === 'approved'
              const isPending   = row.approvalStatus === 'pending'
              const busy        = !!reqState[row._id]
              const rowClass    = [
                s.dataRow,
                isApproved ? s.rowApproved : '',
                isRejected ? s.rowRejected : '',
                flashIds.has(row._id) ? s.rowFlash : '',
              ].filter(Boolean).join(' ')

              return (
                <tr key={row._id} className={rowClass}>
                  {COLUMNS.map(c => {
                    const eKey      = `${row._id}_${c.key}`
                    const isEditing = !!editing[eKey]
                    const readOnly  = isRejected

                    return (
                      <td
                        key={c.key}
                        className={[
                          c.sticky ? s.stickyTd : '',
                          s.cell,
                          readOnly ? s.cellReadOnly : '',
                        ].filter(Boolean).join(' ')}
                        onClick={() => !isEditing && startEdit(row._id, c.key, readOnly)}
                      >
                        {isEditing && !readOnly ? (
                          c.type === 'select' ? (
                            <select
                              className={s.cellSelect}
                              defaultValue={String(row[c.key])}
                              autoFocus
                              onBlur={e => commitEdit(row._id, c.key, e.target.value)}
                              onChange={e => commitEdit(row._id, c.key, e.target.value)}
                            >
                              {c.options.map(o => (
                                <option key={o} value={o}>{o}</option>
                              ))}
                            </select>
                          ) : (
                            <input
                              className={s.cellInput}
                              type={c.type ?? 'text'}
                              step={c.step}
                              min={c.min}
                              max={c.max}
                              defaultValue={row[c.key]}
                              autoFocus
                              onBlur={e => commitEdit(row._id, c.key, e.target.value)}
                              onKeyDown={e => {
                                if (e.key === 'Enter')  e.target.blur()
                                if (e.key === 'Escape') {
                                  setEditing(prev => { const n = { ...prev }; delete n[eKey]; return n })
                                }
                              }}
                            />
                          )
                        ) : (
                          <span className={s.cellText}>{row[c.key] ?? ''}</span>
                        )}
                      </td>
                    )
                  })}

                  {/* Status column */}
                  <td className={s.statusTd}>
                    {isPending  && <span className={s.badgePending}>⏳ Pending</span>}
                    {isApproved && <span className={s.badgeApproved}>✅ Approved</span>}
                    {isRejected && <span className={s.badgeRejected}>❌ Rejected</span>}
                  </td>

                  {/* Actions column */}
                  <td className={s.actionTd}>
                    <div className={s.actionGroup}>
                      {/* Submit for review — always available unless busy */}
                      {!isPending && !isApproved && (
                        <button
                          className={s.btnSubmit}
                          onClick={() => submitRow(row._id)}
                          disabled={busy}
                        >
                          {reqState[row._id] === 'submitting' ? '…' : 'Submit'}
                        </button>
                      )}

                      {/* Admin approve / reject — shown when pending */}
                      {isPending && (
                        <>
                          <button
                            className={s.btnApprove}
                            onClick={() => approveRow(row._id)}
                            disabled={busy}
                            title="Approve"
                          >
                            {reqState[row._id] === 'approving' ? '…' : '✅'}
                          </button>
                          <button
                            className={s.btnReject}
                            onClick={() => rejectRow(row._id)}
                            disabled={busy}
                            title="Reject"
                          >
                            {reqState[row._id] === 'rejecting' ? '…' : '❌'}
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
