import React, { useState } from 'react';
import PhoneFrame from './components/PhoneFrame';
import LoginScreen from './screens/LoginScreen';
import PatrolFeedScreen from './screens/PatrolFeedScreen';
import TacticalNavigationMap from './screens/TacticalNavigationMap';

export default function App() {
  const [screen, setScreen] = useState('login'); // login | feed | nav
  const [officer, setOfficer] = useState({ badge: 'PATROL-104', name: 'Officer S. Kumar', unit: 'Zone 17 Response' });
  const [selectedIncident, setSelectedIncident] = useState(null);

  const handleLogin = (officerData) => {
    setOfficer(officerData);
    setScreen('feed');
  };

  const handleSelectIncident = (inc) => {
    setSelectedIncident(inc);
    setScreen('nav');
  };

  return (
    <PhoneFrame>
      {screen === 'login' && <LoginScreen onLogin={handleLogin} />}
      {screen === 'feed' && (
        <PatrolFeedScreen
          officer={officer}
          onSelectIncident={handleSelectIncident}
        />
      )}
      {screen === 'nav' && (
        <TacticalNavigationMap
          officer={officer}
          incident={selectedIncident}
          onBack={() => setScreen('feed')}
          onStatusUpdate={(newStatus) => {
            if (newStatus === 'resolved') {
              setTimeout(() => setScreen('feed'), 2000);
            }
          }}
        />
      )}
    </PhoneFrame>
  );
}
