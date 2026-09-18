import React, { useState } from 'react';
import SplashScreen from './screens/SplashScreen';
import LoginScreen from './screens/LoginScreen';
import HomeScreen from './screens/HomeScreen';
import SosCountdownScreen from './screens/SosCountdownScreen';
import LiveTrackingScreen from './screens/LiveTrackingScreen';
import ResponseCompleteScreen from './screens/ResponseCompleteScreen';
import { api } from './services/api';

export default function App() {
  const [screen, setScreen] = useState('splash'); // splash | login | home | countdown | tracking | complete
  const [user, setUser] = useState({ name: 'Ananya Sharma', phone: '+91 98765 43210', pincode: '600017' });
  const [sosData, setSosData] = useState(null);

  const handleLogin = (userData) => {
    setUser(userData);
    setScreen('home');
  };

  const handleStartSos = () => {
    setScreen('countdown');
  };

  const handleConfirmSos = async () => {
    try {
      const res = await api.triggerSos({
        userId: 'USER-999',
        username: user.name,
        latitude: 13.0418,
        longitude: 80.2341,
        pincode: user.pincode || '600017',
        riskLevel: 'HIGH',
      });
      setSosData(res);
      setScreen('tracking');
    } catch (err) {
      console.error('Failed to trigger SOS:', err);
      // Create fallback demo data
      setSosData({
        sos_id: 'SOS-' + Math.floor(1000 + Math.random() * 9000),
        status: 'dispatched',
        assigned_patrol_id: 'PATROL-104',
        eta_seconds: 180,
        latitude: 13.0418,
        longitude: 80.2341
      });
      setScreen('tracking');
    }
  };

  const handleCancelSos = () => {
    setScreen('home');
  };

  const handleResponseResolved = (finalIncident) => {
    setSosData(finalIncident);
    setScreen('complete');
  };

  return (
    <div className="w-full min-h-screen bg-dark-950 font-sans antialiased text-slate-100 flex justify-center">
      <div className="w-full max-w-md min-h-screen relative bg-dark-950 shadow-2xl border-x border-white/5 flex flex-col">
        {screen === 'splash' && <SplashScreen onStart={() => setScreen('login')} />}
        {screen === 'login' && <LoginScreen onLogin={handleLogin} />}
        {screen === 'home' && (
          <HomeScreen
            user={user}
            onTriggerSos={handleStartSos}
            onSelectZone={(p) => setUser(prev => ({ ...prev, pincode: p }))}
          />
        )}
        {screen === 'countdown' && (
          <SosCountdownScreen
            onConfirm={handleConfirmSos}
            onCancel={handleCancelSos}
          />
        )}
        {screen === 'tracking' && (
          <LiveTrackingScreen
            sosData={sosData}
            onComplete={handleResponseResolved}
          />
        )}
        {screen === 'complete' && (
          <ResponseCompleteScreen
            incident={sosData}
            onReset={() => setScreen('home')}
          />
        )}
      </div>
    </div>
  );
}
