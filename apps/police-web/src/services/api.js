import axios from 'axios';

const API_BASE = 'https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com';

const client = axios.create({
  baseURL: API_BASE,
  timeout: 8000,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const api = {
  // Get active emergency incidents sorted by distance
  async getActiveIncidents(officerLat = 13.0827, officerLng = 80.2707) {
    try {
      const res = await client.get(`/incidents/active?officer_lat=${officerLat}&officer_lng=${officerLng}`);
      return Array.isArray(res.data) ? res.data : [];
    } catch (err) {
      console.warn('API /incidents/active fallback to legacy endpoint:', err.message);
      try {
        const res = await client.get(`/police/sos/active?officer_lat=${officerLat}&officer_lng=${officerLng}`);
        return Array.isArray(res.data) ? res.data : [];
      } catch (_) {
        return [];
      }
    }
  },

  // Update incident status (e.g. status='reached' or 'dispatched')
  async updateIncidentStatus(sosId, status = 'reached', officerId = 'PATROL-104', notes = '') {
    try {
      const res = await client.patch(`/incident/${sosId}/status`, {
        status,
        officer_id: officerId,
        notes
      });
      return res.data;
    } catch (err) {
      // Legacy fallback
      const res = await client.patch(`/police/sos/${sosId}/status`, {
        status,
        officer_id: officerId,
        notes
      });
      return res.data;
    }
  },

  // Resolve incident
  async resolveIncident(sosId, officerId = 'PATROL-104') {
    try {
      const res = await client.patch(`/incident/${sosId}/resolve`, {
        officer_id: officerId,
        notes: 'Officer verified citizen safety at scene.'
      });
      return res.data;
    } catch (err) {
      // Legacy fallback
      const res = await client.patch(`/sos/resolve/${sosId}`);
      return res.data;
    }
  },

  // Get active patrols
  async getPatrols() {
    try {
      const res = await client.get('/patrols');
      return Array.isArray(res.data) ? res.data : [];
    } catch (_) {
      return [];
    }
  },

  // Get route details
  async getPoliceRoute(fromLat, fromLng, toLat, toLng, sosId) {
    try {
      const res = await client.get(`/police/route?from_lat=${fromLat}&from_lng=${fromLng}&to_lat=${toLat}&to_lng=${toLng}&sos_id=${sosId}`);
      return res.data;
    } catch (_) {
      return null;
    }
  }
};
