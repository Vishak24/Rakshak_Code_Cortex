import React, { useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import L from 'leaflet';
import { PhoneCall, Navigation, CheckCircle2, ShieldAlert, ArrowLeft, Clock } from 'lucide-react';
import { api } from '../services/api';

const officerIcon = new L.DivIcon({
  className: 'custom-officer-icon',
  html: `<div class="relative flex items-center justify-center">
          <span class="absolute w-9 h-9 rounded-full bg-cyan-500/40 animate-ping"></span>
          <div class="w-7 h-7 rounded-full bg-cyan-500 border-2 border-white flex items-center justify-center text-dark-950 font-black shadow-lg text-xs">🚔</div>
        </div>`,
  iconSize: [28, 28],
  iconAnchor: [14, 14]
});

const citizenSosIcon = new L.DivIcon({
  className: 'custom-sos-icon',
  html: `<div class="relative flex items-center justify-center">
          <span class="absolute w-10 h-10 rounded-full bg-rose-500/50 animate-ping"></span>
          <div class="w-7 h-7 rounded-full bg-rose-600 border-2 border-white flex items-center justify-center text-white shadow-lg text-xs">🆘</div>
        </div>`,
  iconSize: [28, 28],
  iconAnchor: [14, 14]
});

export default function TacticalNavigationMap({ officer, incident, onBack, onStatusUpdate }) {
  const [status, setStatus] = useState(incident?.status || 'dispatched');
  const [loading, setLoading] = useState(false);

  const sosId = incident?.sos_id || incident?.id || 'SOS-DEMO';
  const officerCoords = [13.0827, 80.2707];
  const citizenCoords = [incident?.latitude || 13.0418, incident?.longitude || 80.2341];

  const handleMarkReached = async () => {
    setLoading(true);
    await api.updateIncidentStatus(sosId, 'reached', officer.badge);
    setStatus('reached');
    if (onStatusUpdate) onStatusUpdate('reached');
    setLoading(false);
  };

  const handleResolve = async () => {
    setLoading(true);
    await api.resolveIncident(sosId, officer.badge);
    setStatus('resolved');
    if (onStatusUpdate) onStatusUpdate('resolved');
    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-dark-950 flex flex-col justify-between text-white relative overflow-hidden">
      {/* Top Bar */}
      <div className="p-4 glass-panel border-b border-white/10 z-20 flex items-center justify-between">
        <button onClick={onBack} className="p-2 rounded-lg bg-dark-900 border border-white/10 text-slate-300 hover:text-white flex items-center gap-1 text-xs">
          <ArrowLeft className="w-4 h-4" /> Back
        </button>
        <div className="text-center">
          <h3 className="text-xs font-bold text-police-teal uppercase tracking-wider">TACTICAL NAV</h3>
          <p className="text-[10px] text-slate-400">Target: {incident?.username || 'Citizen'}</p>
        </div>
        <a href="tel:9876543210" className="p-2 rounded-lg bg-brand-emerald text-dark-950 font-bold text-xs flex items-center gap-1">
          <PhoneCall className="w-3.5 h-3.5" /> Call
        </a>
      </div>

      {/* Map View */}
      <div className="relative flex-1 w-full z-10 min-h-[360px]">
        <MapContainer center={citizenCoords} zoom={14} zoomControl={false} className="w-full h-full">
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <Marker position={officerCoords} icon={officerIcon}>
            <Popup>Your Unit ({officer.badge})</Popup>
          </Marker>
          <Marker position={citizenCoords} icon={citizenSosIcon}>
            <Popup>Citizen SOS Signal</Popup>
          </Marker>
          <Polyline positions={[officerCoords, citizenCoords]} color="#00D4B4" weight={5} dashArray="6, 6" />
        </MapContainer>

        {/* Floating ETA chip */}
        <div className="absolute top-4 left-4 right-4 z-[1000] glass-card p-3 rounded-xl border border-white/10 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Navigation className="w-4 h-4 text-police-teal" />
            <div>
              <span className="text-[10px] text-slate-400 block uppercase font-semibold">Distance & ETA</span>
              <span className="text-xs font-bold text-white">1.2 km • 3 mins via Mount Rd</span>
            </div>
          </div>
          <span className="px-2.5 py-1 rounded-full text-[10px] font-black bg-police-teal/20 text-police-teal border border-police-teal/40 uppercase">
            {status}
          </span>
        </div>
      </div>

      {/* Status Action Workflow Bottom Sheet */}
      <div className="p-4 glass-panel border-t border-white/10 z-20 space-y-3">
        {/* Status Stepper */}
        <div className="flex items-center justify-between text-xs px-4">
          <span className={`font-bold ${status === 'dispatched' ? 'text-police-teal' : 'text-slate-500'}`}>1. DISPATCHED</span>
          <span className="text-slate-600">➔</span>
          <span className={`font-bold ${status === 'reached' ? 'text-police-teal' : 'text-slate-500'}`}>2. REACHED SCENE</span>
          <span className="text-slate-600">➔</span>
          <span className={`font-bold ${status === 'resolved' ? 'text-brand-emerald' : 'text-slate-500'}`}>3. RESOLVED</span>
        </div>

        {/* Action Buttons */}
        {status === 'dispatched' && (
          <button
            onClick={handleMarkReached}
            disabled={loading}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-teal-500 to-police-teal text-dark-950 font-extrabold text-sm flex items-center justify-center gap-2 shadow-[0_4px_20px_rgba(0,212,180,0.4)] hover:shadow-[0_6px_25px_rgba(0,212,180,0.6)] cursor-pointer transition-all"
          >
            <CheckCircle2 className="w-5 h-5" /> Mark Officer Reached Scene
          </button>
        )}

        {status === 'reached' && (
          <button
            onClick={handleResolve}
            disabled={loading}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-600 text-dark-950 font-extrabold text-sm flex items-center justify-center gap-2 shadow-[0_4px_20px_rgba(0,230,165,0.4)] hover:shadow-[0_6px_25px_rgba(0,230,165,0.6)] cursor-pointer transition-all"
          >
            <CheckCircle2 className="w-5 h-5" /> Verify Citizen & Resolve Incident
          </button>
        )}

        {status === 'resolved' && (
          <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-center text-xs font-bold text-emerald-400">
            ✔ Incident Closed — Patrol Unit Returned to Fleet Ready State
          </div>
        )}
      </div>
    </div>
  );
}
