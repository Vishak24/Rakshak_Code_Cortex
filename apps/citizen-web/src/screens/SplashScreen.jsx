import React from 'react';
import { motion } from 'framer-motion';
import { Shield, ArrowRight, Zap, Radio } from 'lucide-react';

export default function SplashScreen({ onStart }) {
  return (
    <div className="min-h-screen bg-dark-950 flex flex-col items-center justify-between p-6 relative overflow-hidden">
      {/* Background Glow Accents */}
      <div className="absolute top-1/4 -left-20 w-72 h-72 rounded-full bg-brand-red/15 blur-[100px] pointer-events-none" />
      <div className="absolute bottom-1/4 -right-20 w-72 h-72 rounded-full bg-brand-cyan/15 blur-[100px] pointer-events-none" />

      {/* Top Tagline */}
      <div className="pt-8 flex items-center gap-2">
        <span className="w-2 h-2 rounded-full bg-brand-emerald animate-ping" />
        <span className="text-xs font-bold tracking-widest text-slate-400 uppercase">Chennai AI Emergency Response</span>
      </div>

      {/* Central Branding */}
      <div className="flex flex-col items-center text-center my-auto max-w-sm">
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ duration: 0.8, ease: 'easeOut' }}
          className="relative mb-6"
        >
          <div className="w-28 h-28 rounded-3xl bg-gradient-to-br from-rose-600 via-brand-red to-rose-900 flex items-center justify-center shadow-[0_0_60px_rgba(255,46,84,0.5)] border border-rose-400/30">
            <Shield className="w-14 h-14 text-white drop-shadow-md" />
          </div>
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 15, repeat: Infinity, ease: 'linear' }}
            className="absolute -inset-3 border border-dashed border-rose-500/30 rounded-full pointer-events-none"
          />
        </motion.div>

        <motion.h1
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.2 }}
          className="text-4xl font-black tracking-tight text-white mb-2"
        >
          RAKSHAK <span className="text-brand-red text-2xl font-semibold">v1.0</span>
        </motion.h1>

        <motion.p
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.3 }}
          className="text-sm text-slate-400 font-medium leading-relaxed mb-6"
        >
          Instant 1-Tap Emergency Dispatch with AI Patrol Optimization & Real-Time Citizen Protection.
        </motion.p>

        <div className="flex items-center gap-4 text-xs font-semibold text-slate-400 mb-8 bg-dark-900/80 px-4 py-2 rounded-full border border-white/10">
          <span className="flex items-center gap-1.5"><Zap className="w-3.5 h-3.5 text-brand-cyan" /> Sub-200ms AI</span>
          <span className="text-slate-600">•</span>
          <span className="flex items-center gap-1.5"><Radio className="w-3.5 h-3.5 text-brand-emerald" /> 20 Patrol Fleet</span>
        </div>
      </div>

      {/* Bottom CTA */}
      <motion.div
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.4 }}
        className="w-full max-w-sm pb-6"
      >
        <button
          onClick={onStart}
          className="w-full py-4 rounded-xl bg-gradient-to-r from-rose-600 to-brand-red text-white font-bold text-base flex items-center justify-center gap-2 shadow-[0_10px_30px_rgba(255,46,84,0.4)] hover:shadow-[0_15px_40px_rgba(255,46,84,0.6)] active:scale-98 transition-all cursor-pointer"
        >
          Open Safety Console <ArrowRight className="w-5 h-5" />
        </button>
      </motion.div>
    </div>
  );
}
