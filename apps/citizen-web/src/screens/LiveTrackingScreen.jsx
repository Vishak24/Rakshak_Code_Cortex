import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import { Shield, PhoneCall, Clock, Navigation, CheckCircle2, AlertTriangle, ShieldCheck, Car } from 'lucide-react';
import { api } from '../services/api';

// Custom Leaflet Icons
const citizenIcon = new L.DivIcon({
  className: 'custom-citizen-icon',
  html: `<div class="relative flex items-center justify-center">
          <span class="absolute w-8 h-8 rounded-full bg-rose-500/40 animate-ping"></span>
          <div class="w-6 h-6 rounded-full bg-rose-600 border-2 border-white flex items-center justify-center text-white shadow-lg text-xs">📍</div>
        </div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12]
});

const patrolIcon = new L.DivIcon({
  className: 'custom-patrol-icon',
  html: `<div class="relative flex items-center justify-center">
          <span class="absolute w-9 h-9 rounded-full bg-cyan-500/30 animate-pulse"></span>
          <div class="w-7 h-7 rounded-full bg-cyan-500 border-2 border-white flex items-center justify-center text-dark-950 font-black shadow-lg text-xs">🚔</div>
        </div>`,
  iconSize: [28, 28],
  iconAnchor: [14, 14]
});

const SAFETY_TIPS = [
  "Stay in a well-lit area if possible while awaiting patrol arrival.",
  "Keep your mobile screen unlocked for instant officer communication.",
  "Rakshak AI continuously monitors unit speed and optimal route dispatch.",
  "Emergency contacts have been notified with your live GPS location."
];

export default function LiveTrackingScreen({ sosData, onComplete }) {
  const [incident, setIncident] = useState(sosData);
  const [tipIndex, setTipIndex] = useState(0);

  const sosId = sosData?.sos_id || sosData?.id || 'SOS-DEMO';
  const assignedPatrolId = incident?.assigned_patrol_id || 'PATROL-104';
  const status = incident?.status || 'dispatched';
  const etaSeconds = incident?.eta_seconds || 180;

  // Poll incident status every 3 seconds
  useEffect(() => {
    const interval = setInterval(async () => {
      if (!sosId) return;
      const updated = await api.getIncident(sosId);
      if (updated) {
        setIncident(updated);
        if (updated.status === 'resolved') {
          onComplete(updated);
        }
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [sosId, onComplete]);

  // Rotate tips
  useEffect(() => {
    const tipInterval = setInterval(() => {
      setTipIndex(prev => (prev + 1) % SAFETY_TIPS.length);
    }, 6000);
    return () => clearInterval(tipInterval);
  }, []);

  const citizenCoords = [incident?.latitude || 13.0418, incident?.longitude || 80.2341];
  const patrolCoords = [
    (incident?.latitude || 13.0418) + 0.008,
    (incident?.longitude || 80.2341) - 0.009
  ];

  const formatEta = (secs) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}m ${s < 10 ? '0' : ''}${s}s`;
  };

  return (
    <div className="min-h-screen bg-dark-950 flex flex-col justify-between relative overflow-hidden text-white">
      {/* Top Header */}
      <div className="p-4 glass-panel border-b border-white/10 z-20 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="w-2.5 h-2.5 rounded-full bg-brand-emerald animate-ping" />
          <div>
            <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Live SOS Dispatch</h3>
            <p className="text-[10px] text-slate-400">ID: {sosId}</p>
          </div>
        </div>
        <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-brand-cyan/10 border border-brand-cyan/30 text-brand-cyan text-xs font-bold">
          <Clock className="w-3.5 h-3.5" /> ETA: {formatEta(etaSeconds)}
        </div>
      </div>

      {/* Map View */}
      <div className="relative flex-1 w-full z-10 min-h-[320px]">
        <MapContainer
          center={citizenCoords}
          zoom={14}
          zoomControl={false}
          className="w-full h-full"
        >
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <Marker position={citizenCoords} icon={citizenIcon}>
            <Popup>You are here</Popup>
          </Marker>
          <Marker position={patrolCoords} icon={patrolIcon}>
            <Popup>Responding Unit {assignedPatrolId}</Popup>
          </Marker>
          <Polyline
            positions={[patrolCoords, citizenCoords]}
            color="#00D4FF"
            weight={4}
            dashArray="8, 8"
          />
        </MapContainer>

        {/* Live Status Pill Overlay */}
        <div className="absolute top-4 left-4 right-4 z-[1000] glass-card p-3 rounded-xl border border-white/10 flex items-center justify-between shadow-xl">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-brand-cyan/20 border border-brand-cyan/40 flex items-center justify-center text-brand-cyan">
              <Car className="w-4 h-4" />
            </div>
            <div>
              <h4 className="text-xs font-bold text-white">Unit {assignedPatrolId} En Route</h4>
              <p className="text-[10px] text-slate-400">Officer S. Kumar • Speed 42 km/h</p>
            </div>
          </div>
          <a
            href="tel:112"
            className="px-3 py-1.5 rounded-lg bg-brand-emerald text-dark-950 font-bold text-xs flex items-center gap-1 shadow-md hover:bg-emerald-400 transition-colors"
          >
            <PhoneCall className="w-3 h-3" /> Call Officer
          </a>
        </div>
      </div>

      {/* Bottom Panel */}
      <div className="p-4 glass-panel border-t border-white/10 z-20 space-y-4">
        {/* Progress Stepper */}
        <div className="flex items-center justify-between relative px-2">
          <div className="absolute left-6 right-6 top-1/2 -translate-y-1/2 h-0.5 bg-slate-800 -z-10" />
          <div className="flex flex-col items-center gap-1">
            <div className="w-6 h-6 rounded-full bg-brand-emerald text-dark-950 flex items-center justify-center font-bold text-xs">
              ✓
            </div>
            <span className="text-[10px] text-slate-300 font-semibold">Dispatched</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <div className="w-6 h-6 rounded-full bg-brand-cyan text-dark-950 flex items-center justify-center font-bold text-xs animate-pulse">
              ➔
            </div>
            <span className="text-[10px] text-brand-cyan font-semibold">En Route</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <div className="w-6 h-6 rounded-full bg-slate-800 text-slate-500 border border-slate-700 flex items-center justify-center font-bold text-xs">
              3
            </div>
            <span className="text-[10px] text-slate-500 font-semibold">Arrived</span>
          </div>
        </div>

        {/* Safety Tip Revolving Banner */}
        <div className="bg-dark-900/90 p-3 rounded-xl border border-white/5 flex items-start gap-2.5">
          <ShieldCheck className="w-4 h-4 text-brand-cyan shrink-0 mt-0.5" />
          <div>
            <span className="text-[10px] font-bold text-brand-cyan uppercase tracking-wider block">Safety Advisory</span>
            <p className="text-xs text-slate-300">{SAFETY_TIPS[tipIndex]}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
