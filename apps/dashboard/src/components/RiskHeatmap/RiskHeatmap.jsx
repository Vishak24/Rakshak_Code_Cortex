import React, { useEffect, useRef, useState } from 'react'
import L from 'leaflet'
import 'leaflet.heat'
import s from './RiskHeatmap.module.css'
import { riskColor } from '../../constants/zones'

const CHENNAI_CENTER = [13.0827, 80.2707]

// Interpolate between two [lat,lng] points
function lerpPt(a, b, t) {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
}

// ── Patrol vehicles ───────────────────────────────────────────────────────
// Blue police vehicles only. Colour shifts while a unit is on a call so the
// diversion is visible, but the icon is always the same police car.
const PATROL_COLOR = {
  Patrolling: '#3B82F6',   // blue — the default fleet state
  Responding: '#F59E0B',   // amber — diverted to an SOS
  AtScene:    '#FF3B5C',   // red — parked at the incident
  Returning:  '#60A5FA',   // light blue — heading back to route
}
const PATROL_LABEL = {
  Patrolling: 'Patrolling',
  Responding: '🚔 En Route',
  AtScene:    'At Scene',
  Returning:  'Returning',
}

function patrolIcon(status) {
  const col = PATROL_COLOR[status] ?? PATROL_COLOR.Patrolling
  return L.divIcon({
    className: 'patrol-veh',
    iconSize:  [22, 22],
    iconAnchor:[11, 11],
    html: `<div style="width:22px;height:22px;display:flex;align-items:center;justify-content:center;
             border-radius:50%;background:${col};border:1.5px solid rgba(255,255,255,.9);
             box-shadow:0 0 8px ${col}88;">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#fff"
             stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M5 17H3v-5l2-5h14l2 5v5h-2"/>
          <circle cx="7.5" cy="17" r="1.8"/>
          <circle cx="16.5" cy="17" r="1.8"/>
          <path d="M5 12h14"/>
        </svg>
      </div>`,
  })
}

// ── SOS incidents ─────────────────────────────────────────────────────────
// Flashing red while en route, steady blue once the unit reports Reached.
function incidentIcon(status) {
  const reached = status === 'reached'
  const col     = reached ? '#38BDF8' : '#FF3B5C'
  const anim    = reached ? '' : 'animation:sos-blink 0.9s ease-in-out infinite;'
  return L.divIcon({
    className: '',
    iconSize:  [20, 20],
    iconAnchor:[10, 10],
    html: `<div style="${anim}">
      <svg width="20" height="20" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
        <circle cx="10" cy="10" r="8" fill="${col}" fill-opacity="0.85" stroke="#fff" stroke-width="1.6"/>
        <circle cx="10" cy="10" r="3.6" fill="#fff"/>
      </svg>
    </div>`,
  })
}

const POLY_FILL   = { HIGH: 0.20, MEDIUM: 0.15, LOW: 0.10 }
const POLY_WEIGHT = { HIGH: 1.5,  MEDIUM: 1.0,  LOW: 0.8  }

/**
 * Props:
 *   apiData        — Map<pincode, {zoneName, safetyScore, riskLevel, heatWeight, lat, lng}>
 *   lang           — 'en' | 'ta'
 *   onPatrolClick  — (patrol) => void
 *   onZoneSelect   — (pincode) => void  — drives the ML Safety Score panel
 *   incidents      — live active SOS rows from useActiveIncidents
 *   patrols        — live rows from useLivePatrols
 */
export default function RiskHeatmap({
  apiData, lang, onPatrolClick, onZoneSelect, incidents = [], patrols = [],
}) {
  const mapRef           = useRef(null)
  const mapInstance      = useRef(null)
  const heatRef          = useRef(null)
  const patrolLayerRef   = useRef(null)
  const incidentLayerRef = useRef(null)
  const polyRef          = useRef(new Map())   // pincode → L.polygon

  const onPatrolClickRef = useRef(onPatrolClick)
  const onZoneSelectRef  = useRef(onZoneSelect)
  const apiDataRef       = useRef(apiData)
  useEffect(() => { onPatrolClickRef.current = onPatrolClick }, [onPatrolClick])
  useEffect(() => { onZoneSelectRef.current  = onZoneSelect  }, [onZoneSelect])
  useEffect(() => { apiDataRef.current       = apiData       }, [apiData])

  // id -> { marker, cur:[lat,lng], target:[lat,lng], status }
  const patrolMarkersRef = useRef(new Map())
  const patrolsRef       = useRef(patrols)
  useEffect(() => { patrolsRef.current = patrols }, [patrols])

  const [selected, setSelected] = useState(null)

  // ── Init map once ─────────────────────────────────────────────────────────
  useEffect(() => {
    if (mapInstance.current) return

    const bounds = L.latLngBounds(L.latLng(12.80, 80.10), L.latLng(13.23, 80.32))
    const map = L.map(mapRef.current, {
      center: CHENNAI_CENTER, zoom: 12, minZoom: 11, maxZoom: 16,
      maxBounds: bounds, maxBoundsViscosity: 1.0,
      zoomControl: true, attributionControl: false,
    })
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      { subdomains: 'abcd', maxZoom: 19 }).addTo(map)
    mapInstance.current = map

    if (typeof L.heatLayer === 'function') {
      heatRef.current = L.heatLayer([], {
        radius: 38, blur: 28, maxZoom: 14,
        gradient: { 0: '#22C55E', 0.45: '#F59E0B', 1: '#FF3B5C' }, max: 1,
      }).addTo(map)
    }

    fetch('/Final_Chennai_Pincode.kml')
      .then(r => { if (!r.ok) throw new Error('no kml'); return r.text() })
      .then(kmlText => renderKML(map, kmlText))
      .catch(() => { /* zones stay unrendered; heat + markers still work */ })

    patrolLayerRef.current   = L.layerGroup().addTo(map)
    incidentLayerRef.current = L.layerGroup().addTo(map)

    return () => {
      map.remove()
      mapInstance.current = null
      patrolMarkersRef.current.clear()
      polyRef.current.clear()
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Upsert one marker per live patrol; set its interpolation target ───────
  useEffect(() => {
    if (!patrolLayerRef.current) return
    const store = patrolMarkersRef.current
    const seen  = new Set()

    patrols.forEach(p => {
      if (!p.position) return
      const tgt = [p.position.lat, p.position.lng]
      seen.add(p.id)
      let entry = store.get(p.id)

      if (!entry) {
        const marker = L.marker(tgt, { icon: patrolIcon(p.status), zIndexOffset: 200 })
        marker.on('click', () =>
          onPatrolClickRef.current?.(patrolsRef.current.find(x => x.id === p.id) ?? p))
        patrolLayerRef.current.addLayer(marker)
        entry = { marker, cur: tgt, target: tgt, status: p.status }
        store.set(p.id, entry)
      } else {
        entry.target = tgt
        // L.marker has no setStyle — swap the whole icon when status changes
        if (entry.status !== p.status) {
          entry.marker.setIcon(patrolIcon(p.status))
          entry.status = p.status
        }
      }

      const eta = p.eta_seconds != null && p.status === 'Responding'
        ? `<br/>ETA ${Math.max(0, Math.round(p.eta_seconds))}s` : ''
      entry.marker.bindTooltip(
        `<b>${p.name}</b> · ${p.id}<br/>${p.zone_name || p.zone || ''}` +
        `<br/><span style="color:${PATROL_COLOR[p.status] ?? PATROL_COLOR.Patrolling};font-weight:700">` +
        `${PATROL_LABEL[p.status] ?? p.status}</span>${eta}`,
        { direction: 'top', offset: [0, -12], className: 'patrol-tooltip' }
      )
    })

    for (const [id, entry] of store) {
      if (!seen.has(id)) { patrolLayerRef.current.removeLayer(entry.marker); store.delete(id) }
    }
  }, [patrols])

  // ── Smooth interpolation toward each patrol's live target ────────────────
  useEffect(() => {
    const timer = setInterval(() => {
      patrolMarkersRef.current.forEach(entry => {
        const [clat, clng] = entry.cur
        const [tlat, tlng] = entry.target
        if (Math.abs(clat - tlat) < 1e-6 && Math.abs(clng - tlng) < 1e-6) return
        entry.cur = lerpPt(entry.cur, entry.target, 0.12) // ~1.5s catch-up
        entry.marker.setLatLng(entry.cur)
      })
    }, 100)
    return () => clearInterval(timer)
  }, [])

  // ── KML renderer — polygons keyed by pincode so live data can restyle ─────
  function renderKML(map, kmlText) {
    const kml   = new DOMParser().parseFromString(kmlText, 'text/xml')
    const group = L.layerGroup().addTo(map)

    Array.from(kml.querySelectorAll('Placemark')).forEach(pm => {
      const coordsEl = pm.querySelector('coordinates')
      if (!coordsEl) return
      const latLngs = coordsEl.textContent.trim().split(/\s+/)
        .filter(c => c.includes(','))
        .map(c => { const p = c.split(','); return [parseFloat(p[1]), parseFloat(p[0])] })
        .filter(ll => !isNaN(ll[0]) && !isNaN(ll[1]))
      if (latLngs.length < 3) return

      const sd = [...pm.querySelectorAll('SimpleData')].find(el => el.getAttribute('name') === 'Pincode')
      const pincode = sd?.textContent?.trim() || pm.querySelector('name')?.textContent?.trim() || ''

      const live = apiDataRef.current?.get(pincode)
      const risk = live?.riskLevel ?? 'LOW'
      const col  = riskColor(risk)

      const poly = L.polygon(latLngs, {
        color: col, weight: POLY_WEIGHT[risk], opacity: 0.8,
        fillColor: col, fillOpacity: POLY_FILL[risk], interactive: true,
      })
      poly.on('mouseover', () => {
        const r = apiDataRef.current?.get(pincode)?.riskLevel ?? 'LOW'
        poly.setStyle({ fillOpacity: POLY_FILL[r] + 0.15 })
      })
      poly.on('mouseout', () => {
        const r = apiDataRef.current?.get(pincode)?.riskLevel ?? 'LOW'
        poly.setStyle({ fillOpacity: POLY_FILL[r] })
      })
      poly.on('click', () => {
        const d = apiDataRef.current?.get(pincode)
        setSelected({
          pin:  pincode,
          name: d?.zoneName ?? pincode,
          risk: d?.riskLevel ?? 'LOW',
          safetyScore: d?.safetyScore ?? null,
          incidentsToday: d?.incidentsToday ?? 0,
        })
        onZoneSelectRef.current?.(pincode)
      })
      polyRef.current.set(pincode, poly)
      group.addLayer(poly)
    })

    try {
      const gb = group.getLayers().reduce((b, l) => b.extend(l.getBounds()), L.latLngBounds())
      if (gb.isValid()) map.fitBounds(gb, { padding: [20, 20] })
    } catch (_) { /* keep current view */ }
  }

  // ── Heat layer + polygon colours follow the live safety grid ─────────────
  useEffect(() => {
    if (!apiData) return

    if (heatRef.current) {
      const pts = []
      apiData.forEach(z => {
        if (z.lat != null && z.lng != null) pts.push([z.lat, z.lng, z.heatWeight])
      })
      if (pts.length) heatRef.current.setLatLngs(pts)
    }

    polyRef.current.forEach((poly, pincode) => {
      const risk = apiData.get(pincode)?.riskLevel ?? 'LOW'
      const col  = riskColor(risk)
      poly.setStyle({
        color: col, fillColor: col,
        weight: POLY_WEIGHT[risk], fillOpacity: POLY_FILL[risk],
      })
    })
  }, [apiData])

  // ── Incident markers — colour tracks incident status ─────────────────────
  useEffect(() => {
    if (!incidentLayerRef.current) return
    incidentLayerRef.current.clearLayers()

    incidents.forEach(inc => {
      const lat = inc.latitude, lng = inc.longitude
      if (lat == null || lng == null) return

      const unit = inc.patrolId
        ? `<br/>Unit ${inc.patrolId}${inc.officer ? ` · ${inc.officer}` : ''}` : ''
      const eta = inc.status === 'dispatched' && inc.etaSeconds != null
        ? `<br/>ETA ${Math.max(0, Math.round(inc.etaSeconds))}s` : ''
      const state = inc.status === 'reached' ? 'ON SCENE' : 'EN ROUTE'

      const marker = L.marker([lat, lng], { icon: incidentIcon(inc.status), zIndexOffset: 400 })
      marker.bindTooltip(
        `<b>SOS · ${state}</b><br/>${inc.name}${unit}${eta}`,
        { direction: 'top', offset: [0, -12], className: 'patrol-tooltip' }
      )
      incidentLayerRef.current.addLayer(marker)
    })
  }, [incidents])

  const col = selected ? riskColor(selected.risk) : '#fff'

  return (
    <div className={s.wrap}>
      <div ref={mapRef} className={s.mapEl} />

      <div className={s.hdr}>
        <span className={s.ttl}>{lang === 'ta' ? 'சென்னை நேரடி வரைபடம்' : 'CHENNAI LIVE MAP'}</span>
        <span className={s.badge}>
          {lang === 'ta'
            ? `நேரடி · ${patrols.length} ரோந்து`
            : `LIVE · ${patrols.length} PATROLS · ${incidents.length} SOS`}
        </span>
      </div>

      <div className={s.legend}>
        <div className={s.legLbl}>{lang === 'ta' ? 'ஆபத்து நிலை' : 'RISK LEVEL'}</div>
        <div className={s.legRow}><div className={s.legDot} style={{background:'#FF3B5C'}}/><span>{lang === 'ta' ? 'அதிக ஆபத்து' : 'High Risk'}</span></div>
        <div className={s.legRow}><div className={s.legDot} style={{background:'#F59E0B'}}/><span>{lang === 'ta' ? 'நடுத்தர ஆபத்து' : 'Medium Risk'}</span></div>
        <div className={s.legRow}><div className={s.legDot} style={{background:'#22C55E'}}/><span>{lang === 'ta' ? 'குறைந்த ஆபத்து' : 'Low Risk'}</span></div>
        <div className={s.legLbl} style={{marginTop:8}}>PATROL UNITS ({patrols.length})</div>
        <div className={s.legRow}><div className={s.legDot} style={{background:'#3B82F6'}}/><span>Patrolling</span></div>
        <div className={s.legRow}><div className={s.legDot} style={{background:'#F59E0B'}}/><span>En Route</span></div>
        <div className={s.legRow}><div className={s.legDot} style={{background:'#FF3B5C'}}/><span>At Scene</span></div>
      </div>

      {selected && (
        <div className={s.zonePanel}>
          <div className={s.zpHead}>ZONE DETAIL</div>
          <div className={s.zpName}>
            {selected.name} <span style={{color:'var(--dim)',fontWeight:400,fontSize:11}}>({selected.pin})</span>
          </div>
          <div className={s.zpRow}><span className={s.zpKey}>Risk Level</span><span className={s.zpVal} style={{color:col}}>{selected.risk}</span></div>
          <div className={s.zpRow}>
            <span className={s.zpKey}>Safety Score</span>
            <span className={s.zpVal}>{selected.safetyScore != null ? `${selected.safetyScore}/100` : '—'}</span>
          </div>
          <div className={s.zpRow}><span className={s.zpKey}>Incidents Today</span><span className={s.zpVal}>{selected.incidentsToday}</span></div>
          <div className={s.zpFooter}><button className={s.zpDismiss} onClick={() => setSelected(null)}>Dismiss</button></div>
        </div>
      )}
    </div>
  )
}
