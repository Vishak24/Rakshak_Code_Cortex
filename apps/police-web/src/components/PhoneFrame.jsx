import React from 'react';

export default function PhoneFrame({ children }) {
  return (
    <div className="min-h-screen bg-black flex items-center justify-center p-0 md:p-6 overflow-hidden">
      {/* Desktop Hardware Outer Frame */}
      <div className="w-full h-full md:w-[390px] md:h-[844px] md:rounded-[44px] bg-dark-950 border-0 md:border-[10px] md:border-slate-800 shadow-[0_0_80px_rgba(0,212,180,0.15)] flex flex-col relative overflow-hidden">
        {/* Speaker / Notch Bar */}
        <div className="hidden md:flex justify-center pt-2 pb-1 bg-dark-950 shrink-0 z-50">
          <div className="w-28 h-4 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full bg-slate-800" />
            <div className="w-10 h-1 rounded-full bg-slate-800" />
          </div>
        </div>

        {/* App Content */}
        <div className="flex-1 w-full h-full relative overflow-y-auto overflow-x-hidden flex flex-col">
          {children}
        </div>
      </div>
    </div>
  );
}
