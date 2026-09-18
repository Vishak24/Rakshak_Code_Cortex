import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Shield, Phone, UserCheck, ArrowRight } from 'lucide-react';

const PRESETS = [
  { id: '1', name: 'Ananya Sharma', phone: '+91 98765 43210', pincode: '600017', zone: 'T. Nagar' },
  { id: '2', name: 'Priya Sundaram', phone: '+91 98765 12345', pincode: '600040', zone: 'Anna Nagar' },
  { id: '3', name: 'Kavitha R', phone: '+91 98400 99887', pincode: '600020', zone: 'Adyar' },
];

export default function LoginScreen({ onLogin }) {
  const [selectedUser, setSelectedUser] = useState(PRESETS[0]);
  const [phoneNumber, setPhoneNumber] = useState(PRESETS[0].phone);

  const handleSelect = (user) => {
    setSelectedUser(user);
    setPhoneNumber(user.phone);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    onLogin(selectedUser);
  };

  return (
    <div className="min-h-screen bg-dark-950 flex flex-col justify-center p-6 relative overflow-hidden">
      <div className="absolute top-0 right-0 w-80 h-80 rounded-full bg-brand-cyan/10 blur-[120px] pointer-events-none" />

      <div className="w-full max-w-sm mx-auto">
        <div className="flex flex-col items-center text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-brand-red/20 border border-brand-red/40 flex items-center justify-center text-brand-red mb-3 shadow-[0_0_30px_rgba(255,46,84,0.3)]">
            <Shield className="w-8 h-8" />
          </div>
          <h2 className="text-2xl font-bold text-white">Citizen Access</h2>
          <p className="text-xs text-slate-400 mt-1">Select a quick preset profile or enter your phone</p>
        </div>

        {/* Presets */}
        <div className="mb-6 space-y-2">
          <label className="text-xs font-bold text-slate-400 uppercase tracking-wider block">Demo Presets</label>
          {PRESETS.map((p) => (
            <div
              key={p.id}
              onClick={() => handleSelect(p)}
              className={`glass-card p-3 rounded-xl border flex items-center justify-between cursor-pointer transition-all ${
                selectedUser.id === p.id
                  ? 'border-brand-cyan bg-brand-cyan/10 shadow-[0_0_15px_rgba(0,212,255,0.2)]'
                  : 'border-white/5 hover:border-white/20'
              }`}
            >
              <div className="flex items-center gap-3">
                <div className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs ${selectedUser.id === p.id ? 'bg-brand-cyan text-dark-950' : 'bg-slate-800 text-slate-300'}`}>
                  {p.name.charAt(0)}
                </div>
                <div>
                  <h4 className="text-xs font-bold text-white">{p.name}</h4>
                  <p className="text-[10px] text-slate-400">{p.zone} ({p.pincode})</p>
                </div>
              </div>
              <UserCheck className={`w-4 h-4 ${selectedUser.id === p.id ? 'text-brand-cyan' : 'text-slate-600'}`} />
            </div>
          ))}
        </div>

        {/* Input Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Mobile Phone Number</label>
            <div className="relative flex items-center">
              <Phone className="w-4 h-4 absolute left-3.5 text-slate-400" />
              <input
                type="tel"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(e.target.value)}
                placeholder="+91 98765 43210"
                className="w-full pl-10 pr-4 py-3 rounded-xl glass-input text-white text-sm focus:outline-none focus:border-brand-cyan transition-colors"
                required
              />
            </div>
          </div>

          <button
            type="submit"
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-rose-600 to-brand-red text-white font-bold text-sm flex items-center justify-center gap-2 shadow-[0_4px_20px_rgba(255,46,84,0.4)] hover:shadow-[0_6px_25px_rgba(255,46,84,0.6)] transition-all cursor-pointer"
          >
            Authenticate Session <ArrowRight className="w-4 h-4" />
          </button>
        </form>
      </div>
    </div>
  );
}
