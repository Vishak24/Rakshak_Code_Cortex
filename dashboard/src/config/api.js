// Live AWS HTTP API (aksdwfbnn5), region ap-south-1, stage $default (no stage path).
// Override with VITE_API_URL / VITE_API_BASE_URL at build time.
export const API_BASE =
  (import.meta.env && (import.meta.env.VITE_API_URL || import.meta.env.VITE_API_BASE_URL)) ||
  'https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com'

export const ENDPOINTS = {
  // SOS — user app creates, police app reads & acts
  sosLive:        `${API_BASE}/sos/live`,
  sosActive:      `${API_BASE}/police/sos/active`,
  sosDispatch:    (id) => `${API_BASE}/sos/dispatch/${id}`,
  sosResolve:     (id) => `${API_BASE}/sos/resolve/${id}`,
  policeSosStatus:(id) => `${API_BASE}/police/sos/${id}/status`,

  // Police app
  policeRoute:    `${API_BASE}/police/route`,
  citizensActive: `${API_BASE}/police/citizens/active`,

  // Patrols
  patrolsList:    `${API_BASE}/patrols`,
  patrolStatus:   (id) => `${API_BASE}/patrols/${id}/status`,
  patrolOptimize: `${API_BASE}/patrol/optimize`,

  // Reports
  reportsSubmit:  `${API_BASE}/reports/submit`,
  reportsGet:     `${API_BASE}/reports`,
  reportsApprove: (id) => `${API_BASE}/reports/approve/${id}`,
  reportsReject:  (id) => `${API_BASE}/reports/reject/${id}`,

  // Dashboard command APIs
  dashboardSnapshot: `${API_BASE}/dashboard/snapshot`,
  dashboardTimeline: `${API_BASE}/dashboard/timeline`,
  heatmapLive:       `${API_BASE}/heatmap/live`,
  predictionZone:    (zoneId) => `${API_BASE}/prediction/zone/${zoneId}`,
}

export default ENDPOINTS
