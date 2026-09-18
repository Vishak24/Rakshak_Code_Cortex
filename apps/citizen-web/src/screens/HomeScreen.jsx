import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MapPin, Moon, Shield, Bell, User, Map as MapIcon, ChevronRight } from 'lucide-react';
import SafetyGauge from '../components/SafetyGauge';
import ContactsList from '../components/ContactsList';
import SosButton from '../components/SosButton';
import { api } from '../services/api';

const ZONES = [
  { pincode: '600017', name: 'T. Nagar' },
  { pincode: '600040', name: 'Anna Nagar' },
  { pincode: '600020', name: 'Adyar' },
  { pincode: '600042', name: 'Velachery' },
];

export default function HomeScreen({ user, onTriggerSos, onSelectZone }) {
  const [selectedZone, setSelectedZone] = useState(ZONES[0]);
  const [prediction, setPrediction] = useState(null);
  const [isNightWatch, setIsNightWatch] = useState(false);
  const [showZonePicker, setShowZonePicker] = useState(false);

  useEffect(() => {
    async function fetchScore() {
      const res = await api.getZonePrediction(selectedZone.pincode);
      if (res) setPrediction(res);
    }
    fetchScore();
  }, [selectedZone]);

  const handleZoneChange = (z) => {
    setSelectedZone(z);
    setShowZonePicker(false);
    if (onSelectZone) onSelectZone(z.pincode);
  };

  return (
    <div className={`min-h-screen flex flex-col justify-between p-4 relative overflow-hidden transition-colors duration-500 ${isNightWatch ? 'bg-black text-rose-100' : 'bg-dark-950 text-slate-100'}`}>
      {/* Night Watch Ambient Tint */}
      {isNightWatch && (
        <div className="absolute inset-0 bg-rose-950/20 pointer-events-none z-0" />
      )}

      {/* Top Header */}
      <div className="relative z-10 flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-10 h-10 rounded-xl bg-brand-red/20 border border-brand-red/40 flex items-center justify-center text-brand-red shadow-[0_0_15px_rgba(255,46,84,0.3)]">
            <Shield className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-xs font-bold text-slate-400 uppercase tracking-wider">RAKSHAK SENTINEL</h2>
            <p className="text-sm font-bold text-white">{user?.name || 'Ananya Sharma'}</p>
          </div>
        </div>

        {/* Location Picker Pill */}
        <button
          onClick={() => setShowZonePicker(true)}
          className="glass-card px-3 py-1.5 rounded-full border border-white/10 flex items-center gap-1.5 text-xs text-brand-cyan hover:border-brand-cyan/40 transition-colors cursor-pointer"
        >
          <MapPin className="w-3.5 h-3.5" />
          <span className="font-semibold">{selectedZone.name}</span>
          <ChevronRight className="w-3.5 h-3.5 text-slate-400" />
        </button>
      </div>

      {/* Night Watch Toggle */}
      <div className="relative z-10 mb-4 flex items-center justify-between glass-card p-3 rounded-xl border border-white/5">
        <div className="flex items-center gap-2.5">
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${isNightWatch ? 'bg-rose-500 text-white' : 'bg-slate-800 text-slate-400'}`}>
            <Moon className="w-4 h-4" />
          </div>
          <div>
            <h4 className="text-xs font-bold text-white">Night Watch Companion</h4>
            <p className="text-[10px] text-slate-400">Low-light high contrast mode for 10 PM - 5 AM</p>
          </div>
        </div>
        <button
          onClick={() => setIsNightWatch(!isNightWatch)}
          className={`w-11 h-6 rounded-full p-1 transition-colors ${isNightWatch ? 'bg-rose-600' : 'bg-slate-700'}`}
        >
          <div className={`w-4 h-4 rounded-full bg-white transition-transform ${isNightWatch ? 'translate-x-5' : 'translate-x-0'}`} />
        </button>
      </div>

      {/* Safety Gauge Card */}
      <div className="relative z-10">
        <SafetyGauge
          score={prediction?.safetyScore ?? 84}
          riskLevel={prediction?.riskLevel ?? 'LOW'}
          pincode={selectedZone.pincode}
          zoneName={selectedZone.name}
        />
      </div>

      {/* Hero SOS Button */}
      <div className="relative z-10 my-auto">
        <SosButton onClick={onTriggerSos} />
      </div>

      {/* Emergency Contacts */}
      <div className="relative z-10">
        <ContactsList />
      </div>

      {/* Zone Picker Modal */}
      <AnimatePresence>
        {showZonePicker && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-end justify-center p-4"
          >
            <motion.div
              initial={{ y: 100 }}
              animate={{ y: 0 }}
              exit={{ y: 100 }}
              className="w-full max-w-sm glass-panel p-5 rounded-2xl border border-white/10"
            >
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-bold text-white uppercase tracking-wider">Select Chennai Zone</h3>
                <button onClick={() => setShowZonePicker(false)} className="text-slate-400 text-xs font-bold">Close</button>
              </div>
              <div className="space-y-2">
                {ZONES.map((z) => (
                  <button
                    key={z.pincode}
                    onClick={() => handleZoneChange(z)}
                    className={`w-full p-3 rounded-xl border flex items-center justify-between text-xs font-semibold cursor-pointer transition-colors ${
                      selectedZone.pincode === z.pincode
                        ? 'border-brand-cyan bg-brand-cyan/10 text-brand-cyan'
                        : 'border-white/5 hover:border-white/20 text-slate-300'
                    }`}
                  >
                    <span>{z.name}</span>
                    <span className="text-[10px] text-slate-400">PIN: {z.pincode}</span>
                  </button>
                ))}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
