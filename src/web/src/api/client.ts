import axios from 'axios';

// In Docker (nginx proxy): VITE_API_URL is empty, so requests go to /api (same origin).
// In local dev (npm run dev): set VITE_API_URL=http://localhost:5000 in .env.local
const BASE_URL = import.meta.env.VITE_API_URL ?? '';

export const apiClient = axios.create({
  baseURL: `${BASE_URL}/api`,
  headers: { 'Content-Type': 'application/json' },
});
