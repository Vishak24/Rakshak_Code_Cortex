import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { ShieldCheck, Star, ArrowRight, Heart } from 'lucide-react';

export default function ResponseCompleteScreen({ incident, onReset }) {
  const [rating, setRating] = useState(5);
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    // Trigger celebratory confetti
    confetti({
      particleCount: 80,
      spread: 70,
      origin: { y: 0.6 }
    });
  }, []);

  return (
    <div className="min-h-screen bg-dark-950 flex flex-col justify-between p-6 relative overflow-hidden text-white">
      <div className="absolute top-1/3 -left-20 w-80 h-80 rounded-full bg-brand-emerald/15 blur-[120px] pointer-events-none" />

      {/* Header */}
      <div className="pt-8 flex flex-col items-center text-center">
        <motion.div
          initial={{ scale: 0.5, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', damping: 12 }}
          className="w-20 h-20 rounded-full bg-brand-emerald/20 border-2 border-brand-emerald flex items-center justify-center text-brand-emerald mb-4 shadow-[0_0_40px_rgba(0,230,165,0.4)]"
        >
          <ShieldCheck className="w-10 h-10" />
        </motion.div>

        <h2 className="text-2xl font-bold text-white mb-1">Incident Resolved</h2>
        <p className="text-xs text-slate-400">Patrol unit reached scene & verified your safety.</p>
      </div>

      {/* Summary Card */}
      <div className="glass-card p-5 rounded-2xl border border-white/10 my-auto">
        <div className="flex items-center justify-between pb-3 mb-3 border-b border-white/10 text-xs">
          <span className="text-slate-400">Response Time</span>
          <span className="font-bold text-brand-emerald">2 mins 14 secs</span>
        </div>
        <div className="flex items-center justify-between pb-3 mb-3 border-b border-white/10 text-xs">
          <span className="text-slate-400">Responding Officer</span>
          <span className="font-bold text-slate-200">Officer S. Kumar (PATROL-104)</span>
        </div>

        {/* Rating */}
        {!submitted ? (
          <div className="pt-2 text-center">
            <label className="text-xs font-semibold text-slate-300 block mb-2">Rate Patrol Response Speed</label>
            <div className="flex justify-center gap-2 mb-4">
              {[1, 2, 3, 4, 5].map((star) => (
                <button
                  key={star}
                  onClick={() => setRating(star)}
                  className={`p-1 transition-transform ${rating >= star ? 'text-amber-400 scale-110' : 'text-slate-600'}`}
                >
                  <Star className="w-6 h-6 fill-current" />
                </button>
              ))}
            </div>
            <button
              onClick={() => setSubmitted(true)}
              className="w-full py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-bold text-slate-200 transition-colors"
            >
              Submit Feedback
            </button>
          </div>
        ) : (
          <div className="pt-2 text-center text-xs text-brand-emerald font-semibold flex items-center justify-center gap-1">
            <Heart className="w-4 h-4 fill-current" /> Thank you for keeping Chennai safe!
          </div>
        )}
      </div>

      {/* Bottom Button */}
      <div className="pb-6">
        <button
          onClick={onReset}
          className="w-full py-3.5 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-600 text-dark-950 font-bold text-sm flex items-center justify-center gap-2 shadow-[0_4px_20px_rgba(0,230,165,0.3)] hover:shadow-[0_6px_25px_rgba(0,230,165,0.5)] transition-all cursor-pointer"
        >
          Return to Safety Home <ArrowRight className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
