import React, { useState, useEffect, useRef } from 'react';
import { motion } from 'framer-motion';
import { AlertCircle, XCircle } from 'lucide-react';

export default function SosCountdownScreen({ onConfirm, onCancel }) {
  const [seconds, setSeconds] = useState(3);
  const [holdProgress, setHoldProgress] = useState(0);
  const holdIntervalRef = useRef(null);

  useEffect(() => {
    if (seconds <= 0) {
      onConfirm();
      return;
    }
    const timer = setTimeout(() => {
      setSeconds(prev => prev - 1);
    }, 1000);

    return () => clearTimeout(timer);
  }, [seconds, onConfirm]);

  const startCancelHold = () => {
    setHoldProgress(0);
    holdIntervalRef.current = setInterval(() => {
      setHoldProgress(prev => {
        if (prev >= 100) {
          clearInterval(holdIntervalRef.current);
          onCancel();
          return 100;
        }
        return prev + 10;
      });
    }, 50);
  };

  const stopCancelHold = () => {
    if (holdIntervalRef.current) {
      clearInterval(holdIntervalRef.current);
    }
    setHoldProgress(0);
  };

  return (
    <div className="fixed inset-0 z-50 bg-dark-950 flex flex-col items-center justify-between p-6 overflow-hidden">
      {/* Background Pulse Effect */}
      <motion.div
        key={seconds}
        initial={{ scale: 0.8, opacity: 0.8 }}
        animate={{ scale: 2, opacity: 0 }}
        transition={{ duration: 0.9, ease: 'easeOut' }}
        className="absolute w-96 h-96 rounded-full bg-brand-red/30 pointer-events-none"
      />

      <div className="pt-10 flex flex-col items-center text-center">
        <span className="px-3 py-1 rounded-full bg-brand-red/20 border border-brand-red/40 text-brand-red text-xs font-bold tracking-widest uppercase mb-2 animate-pulse">
          EMERGENCY DISPATCH INITIATING
        </span>
        <h2 className="text-xl font-bold text-white">Sending SOS Signal to Patrol Network</h2>
      </div>

      {/* Countdown Circle */}
      <div className="relative w-64 h-64 flex items-center justify-center">
        <svg className="w-full h-full transform -rotate-90">
          <circle
            cx="128"
            cy="128"
            r="110"
            stroke="rgba(255, 46, 84, 0.2)"
            strokeWidth="12"
            fill="transparent"
          />
          <motion.circle
            cx="128"
            cy="128"
            r="110"
            stroke="#FF2E54"
            strokeWidth="12"
            fill="transparent"
            strokeDasharray={2 * Math.PI * 110}
            animate={{ strokeDashoffset: (2 * Math.PI * 110) * (seconds / 3) }}
            transition={{ duration: 1, ease: 'linear' }}
            strokeLinecap="round"
          />
        </svg>

        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <motion.span
            key={seconds}
            initial={{ scale: 1.5, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="text-8xl font-black text-white drop-shadow-[0_0_30px_rgba(255,46,84,0.8)]"
          >
            {seconds}
          </motion.span>
          <span className="text-xs font-bold text-rose-300 tracking-wider uppercase mt-1">SECONDS</span>
        </div>
      </div>

      {/* Cancel Hold Interaction */}
      <div className="w-full max-w-sm pb-8 flex flex-col items-center">
        <p className="text-xs text-slate-400 mb-3 text-center">False Alarm? Press and hold below to cancel dispatch.</p>

        <button
          onMouseDown={startCancelHold}
          onMouseUp={stopCancelHold}
          onTouchStart={startCancelHold}
          onTouchEnd={stopCancelHold}
          onClick={onCancel}
          className="relative w-full py-4 rounded-xl glass-panel border border-white/10 text-white font-bold text-sm flex items-center justify-center gap-2 overflow-hidden cursor-pointer select-none active:scale-98 transition-all"
        >
          {/* Fill progress background */}
          <div
            className="absolute left-0 top-0 bottom-0 bg-slate-700/80 transition-all pointer-events-none"
            style={{ width: `${holdProgress}%` }}
          />
          <XCircle className="w-5 h-5 text-rose-400 relative z-10" />
          <span className="relative z-10">CANCEL SOS DISPATCH</span>
        </button>
      </div>
    </div>
  );
}
