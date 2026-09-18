import React from 'react';
import { motion } from 'framer-motion';
import { ShieldCheck, ShieldAlert, AlertTriangle } from 'lucide-react';

export default function SafetyGauge({ score = 84, riskLevel = 'LOW', pincode = '600017', zoneName = 'T. Nagar' }) {
  const getScoreColor = (s) => {
    if (s >= 75) return { stroke: '#00E6A5', text: 'text-brand-emerald', bg: 'bg-emerald-500/10 border-emerald-500/20' };
    if (s >= 50) return { stroke: '#F59E0B', text: 'text-brand-amber', bg: 'bg-amber-500/10 border-amber-500/20' };
    return { stroke: '#FF2E54', text: 'text-brand-red', bg: 'bg-rose-500/10 border-rose-500/20' };
  };

  const style = getScoreColor(score);
  const circumference = 2 * Math.PI * 40;
  const strokeDashoffset = circumference - (score / 100) * circumference;

  return (
    <div className="glass-card rounded-2xl p-5 border border-white/10 shadow-xl relative overflow-hidden">
      {/* Background ambient glow */}
      <div className="absolute -top-10 -right-10 w-36 h-36 rounded-full bg-brand-cyan/10 blur-3xl pointer-events-none" />

      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xs font-semibold tracking-wider text-slate-400 uppercase">Zone Safety Score</span>
            <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${style.bg} ${style.text}`}>
              {riskLevel} RISK
            </span>
          </div>
          <h3 className="text-xl font-bold text-white flex items-center gap-1.5">
            {zoneName} <span className="text-xs text-slate-400 font-medium">({pincode})</span>
          </h3>
          <p className="text-xs text-slate-400 mt-1 flex items-center gap-1">
            {score >= 75 ? (
              <ShieldCheck className="w-3.5 h-3.5 text-brand-emerald" />
            ) : score >= 50 ? (
              <AlertTriangle className="w-3.5 h-3.5 text-brand-amber" />
            ) : (
              <ShieldAlert className="w-3.5 h-3.5 text-brand-red" />
            )}
            {score >= 75 ? 'Safe Zone — Patrols active nearby' : score >= 50 ? 'Moderate Alert — Stay vigilant' : 'High Priority Patrol Sector'}
          </p>
        </div>

        {/* Circular Gauge */}
        <div className="relative w-24 h-24 flex items-center justify-center">
          <svg className="w-24 h-24 transform -rotate-90">
            <circle
              cx="48"
              cy="48"
              r="40"
              stroke="rgba(255,255,255,0.08)"
              strokeWidth="7"
              fill="transparent"
            />
            <motion.circle
              cx="48"
              cy="48"
              r="40"
              stroke={style.stroke}
              strokeWidth="7"
              fill="transparent"
              strokeDasharray={circumference}
              initial={{ strokeDashoffset: circumference }}
              animate={{ strokeDashoffset }}
              transition={{ duration: 1.5, ease: 'easeOut' }}
              strokeLinecap="round"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-2xl font-black text-white">{score}</span>
            <span className="text-[9px] font-bold text-slate-400 tracking-wider">/ 100</span>
          </div>
        </div>
      </div>
    </div>
  );
}
