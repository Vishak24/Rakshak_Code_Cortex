import React from 'react';
import { PhoneCall, Plus, UserCheck } from 'lucide-react';

const CONTACTS = [
  { id: '1', name: 'Ramesh (Father)', phone: '+91 98401 22100', avatar: '👨‍👧' },
  { id: '2', name: 'Anita (Sister)', phone: '+91 98402 33211', avatar: '👩‍💼' },
  { id: '3', name: 'Chennai Control', phone: '112', avatar: '🚔' },
];

export default function ContactsList() {
  return (
    <div className="mt-4">
      <div className="flex items-center justify-between mb-2">
        <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400">Emergency Contacts</h4>
        <button className="text-xs text-brand-cyan hover:underline flex items-center gap-1 font-semibold">
          <Plus className="w-3.5 h-3.5" /> Add New
        </button>
      </div>

      <div className="grid grid-cols-3 gap-2">
        {CONTACTS.map((c) => (
          <div key={c.id} className="glass-card rounded-xl p-2.5 flex flex-col items-center text-center border border-white/5 hover:border-brand-cyan/30 transition-all cursor-pointer group">
            <span className="text-2xl mb-1 group-hover:scale-110 transition-transform">{c.avatar}</span>
            <span className="text-xs font-semibold text-slate-200 truncate w-full">{c.name}</span>
            <span className="text-[10px] text-slate-400 truncate w-full">{c.phone}</span>
            <a
              href={`tel:${c.phone}`}
              className="mt-2 text-[10px] bg-brand-cyan/10 hover:bg-brand-cyan/20 text-brand-cyan px-2 py-0.5 rounded-full font-bold flex items-center gap-1 transition-colors"
            >
              <PhoneCall className="w-2.5 h-2.5" /> Call
            </a>
          </div>
        ))}
      </div>
    </div>
  );
}
