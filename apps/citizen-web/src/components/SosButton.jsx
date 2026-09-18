import React from 'react';
import { motion } from 'framer-motion';
import { ShieldAlert } from 'lucide-react';

export default function SosButton({ onClick, isTriggering = false }) {
  return (
    <div className="relative flex flex-col items-center justify-center my-6">
      {/* Outer Pulse Rings */}
      <motion.div
        className="absolute w-56 h-56 rounded-full bg-brand-red/20 pointer-events-none"
        animate={{ scale: [1, 1.35, 1], opacity: [0.6, 0.1, 0.6] }}
        transition={{ duration: 2.5, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute w-44 h-44 rounded-full bg-brand-red/30 pointer-events-none"
        animate={{ scale: [1, 1.25, 1], opacity: [0.8, 0.2, 0.8] }}
        transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut', delay: 0.3 }}
      />

      {/* Main SOS Trigger Button */}
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.94 }}
        onClick={onClick}
        disabled={isTriggering}
        className="relative z-10 w-36 h-36 rounded-full bg-gradient-to-tr from-rose-700 via-brand-red to-red-500 shadow-[0_0_50px_rgba(255,46,84,0.65)] border-4 border-white/20 flex flex-col items-center justify-center text-white cursor-pointer select-none group transition-all"
      >
        <ShieldAlert className="w-12 h-12 mb-1 group-hover:rotate-12 transition-transform duration-300 drop-shadow-md" />
        <span className="text-2xl font-black tracking-widest uppercase drop-shadow-md">SOS</span>
        <span className="text-[10px] font-semibold tracking-wider text-rose-200 opacity-90">TAP FOR HELP</span>
      </motion.button>
    </div>
  );
}
