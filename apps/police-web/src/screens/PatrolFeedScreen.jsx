import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { AlertCircle, MapPin, Clock, Shield, Navigation, RefreshCw, CheckCircle2, ChevronRight } from 'lucide-react';
import { api } from '../services/api';

export default function PatrolFeedScreen({ officer, onSelectIncident }) {
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchIncidents = async () => {
    setLoading(true);
    const data = await api.getActiveIncidents();
    if (data && data.length > 0) {
      setIncidents(data);
    } else {
      // Mock active feed if backend empty
      setIncidents([
        {
          sos_id: 'SOS-8821',
          username: 'Ananya Sharma',
          latitude: 13.0418,
          longitude: 80.2341,
          pincode: '600017',
          zone: 'T. Nagar',
          risk_level: 'HIGH',
          status: 'dispatched',
          assigned_patrol_id: officer.badge,
          eta_seconds: 180,
          created_at: new Date().toISOString(),
          distance_km: 1.2
        },
        {
          sos_id: 'SOS-7712',
          username: 'Priya S',
          latitude: 13.0827,
          longitude: 80.2707,
          pincode: '600040',
          zone: 'Anna Nagar',
          risk_level: 'HIGH',
          status: 'active',
          assigned_patrol_id: 'PATROL-101',
          eta_seconds: 340,
          created_at: new Date(Date.now() - 300000).toISOString(),
          distance_km: 3.4
        }
      ]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchIncidents();
    const interval = setInterval(fetchIncidents, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-dark-950 flex flex-col justify-between text-white p-4 relative">
      {/* Top Header Bar */}
      <div className="flex items-center justify-between pb-3 border-b border-white/10">
        <div>
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-police-teal animate-ping" />
            <span className="text-xs font-bold text-police-teal uppercase tracking-wider">{officer.badge} ON DUTY</span>
          </div>
          <h2 className="text-sm font-bold text-white mt-0.5">{officer.name}</h2>
        </div>
        <button
          onClick={fetchIncidents}
          className="p-2 rounded-lg glass-panel hover:border-police-teal/40 text-slate-400 hover:text-white transition-colors"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-police-teal' : ''}`} />
        </button>
      </div>

      {/* Incident List */}
      <div className="my-4 flex-1 space-y-3 overflow-y-auto">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400">Active Emergency Dispatch Feed</h3>
          <span className="text-[10px] bg-rose-500/20 text-rose-400 border border-rose-500/30 px-2 py-0.5 rounded-full font-bold">
            {incidents.length} ALERTS
          </span>
        </div>

        {incidents.map((inc) => {
          const isAssignedToMe = inc.assigned_patrol_id === officer.badge;
          return (
            <div
              key={inc.sos_id || inc.id}
              onClick={() => onSelectIncident(inc)}
              className={`tactical-card p-4 rounded-2xl border transition-all cursor-pointer ${
                isAssignedToMe
                  ? 'border-police-teal bg-police-teal/10 shadow-[0_0_20px_rgba(0,212,180,0.15)]'
                  : 'border-white/10 hover:border-white/20'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-rose-500/20 text-rose-400 border border-rose-500/40">
                    CRITICAL SOS
                  </span>
                  <span className="text-[10px] font-bold text-slate-400">{inc.sos_id || inc.id}</span>
                </div>
                {isAssignedToMe && (
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-police-teal text-dark-950">
                    YOUR UNIT ASSIGNED
                  </span>
                )}
              </div>

              <h4 className="text-base font-bold text-white mb-1">{inc.username || 'Citizen Emergency'}</h4>
              <p className="text-xs text-slate-300 flex items-center gap-1 mb-3">
                <MapPin className="w-3.5 h-3.5 text-police-teal" /> {inc.zone || 'T. Nagar'} (PIN: {inc.pincode || '600017'})
              </p>

              <div className="flex items-center justify-between pt-2 border-t border-white/10 text-xs">
                <span className="text-slate-400 flex items-center gap-1">
                  <Navigation className="w-3.5 h-3.5 text-brand-cyan" /> {inc.distance_km || 1.2} km away
                </span>
                <span className="text-slate-400 flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5 text-amber-400" /> ETA: {Math.round((inc.eta_seconds || 180)/60)} mins
                </span>
                <span className="text-police-teal font-bold flex items-center gap-0.5">
                  View <ChevronRight className="w-4 h-4" />
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
