import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Shield, Key, Lock, ArrowRight, Radio } from 'lucide-react';

const OFFICER_PRESETS = [
  { badge: 'PATROL-104', name: 'Officer S. Kumar', unit: 'Zone 17 Response' },
  { badge: 'PATROL-101', name: 'Officer R. Varma', unit: 'Zone 40 Response' },
  { badge: 'PATROL-108', name: 'Officer M. Selvam', unit: 'Zone 20 Response' },
];

export default function LoginScreen({ onLogin }) {
  const [selectedOfficer, setSelectedOfficer] = useState(OFFICER_PRESETS[0]);
  const [password, setPassword] = useState('••••••••');

  const handleSubmit = (e) => {
    e.preventDefault();
    onLogin(selectedOfficer);
  };

  return (
    <div className="min-h-screen bg-dark-950 flex flex-col justify-between p-6 relative overflow-hidden text-white">
      <div className="absolute top-0 right-0 w-72 h-72 rounded-full bg-police-teal/10 blur-[100px] pointer-events-none" />

      {/* Top Header */}
      <div className="pt-6 flex items-center justify-between">
        <div className="flex items-center gap-1.5 text-xs text-police-teal font-bold uppercase tracking-wider">
          <Radio className="w-3.5 h-3.5 animate-pulse" /> POLICE DISPATCH MESH
        </div>
        <span className="text-[10px] text-slate-500 font-mono">v1.0 ENCRYPTED</span>
      </div>

      {/* Central Identity Form */}
      <div className="my-auto">
        <div className="flex flex-col items-center text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-police-teal/10 border border-police-teal/40 flex items-center justify-center text-police-teal mb-3 shadow-[0_0_30px_rgba(0,212,180,0.25)]">
            <Shield className="w-8 h-8" />
          </div>
          <h2 className="text-2xl font-bold text-white">Officer Console</h2>
          <p className="text-xs text-slate-400 mt-1">Authenticate Unit Duty Badge to Access Emergency Feed</p>
        </div>

        {/* Officer Presets */}
        <div className="mb-6 space-y-2">
          <label className="text-xs font-bold text-slate-400 uppercase tracking-wider block">Select Active Duty Patrol</label>
          {OFFICER_PRESETS.map((o) => (
            <div
              key={o.badge}
              onClick={() => setSelectedOfficer(o)}
              className={`tactical-card p-3 rounded-xl border flex items-center justify-between cursor-pointer transition-all ${
                selectedOfficer.badge === o.badge
                  ? 'border-police-teal bg-police-teal/10 shadow-[0_0_15px_rgba(0,212,180,0.2)]'
                  : 'border-white/5 hover:border-white/20'
              }`}
            >
              <div className="flex items-center gap-3">
                <div className={`w-9 h-9 rounded-lg flex items-center justify-center font-black text-xs ${selectedOfficer.badge === o.badge ? 'bg-police-teal text-dark-950' : 'bg-slate-800 text-slate-300'}`}>
                  🚔
                </div>
                <div>
                  <h4 className="text-xs font-bold text-white">{o.badge} — {o.name}</h4>
                  <p className="text-[10px] text-slate-400">{o.unit}</p>
                </div>
              </div>
              <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${selectedOfficer.badge === o.badge ? 'bg-police-teal/20 text-police-teal' : 'text-slate-500'}`}>
                {selectedOfficer.badge === o.badge ? 'READY' : 'SELECT'}
              </span>
            </div>
          ))}
        </div>

        {/* Password input */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Security Auth Key</label>
            <div className="relative flex items-center">
              <Lock className="w-4 h-4 absolute left-3.5 text-slate-500" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pl-10 pr-4 py-3 rounded-xl bg-dark-900 border border-white/10 text-white text-sm focus:outline-none focus:border-police-teal transition-colors"
                required
              />
            </div>
          </div>

          <button
            type="submit"
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-teal-500 to-police-teal text-dark-950 font-extrabold text-sm flex items-center justify-center gap-2 shadow-[0_4px_20px_rgba(0,212,180,0.4)] hover:shadow-[0_6px_25px_rgba(0,212,180,0.6)] transition-all cursor-pointer"
          >
            Log In Duty Console <ArrowRight className="w-4 h-4" />
          </button>
        </form>
      </div>

      <div className="pb-4 text-center text-[10px] text-slate-500">
        Greater Chennai Police Department • Serverless SOS Dispatch
      </div>
    </div>
  );
}
