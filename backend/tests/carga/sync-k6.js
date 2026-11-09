import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 100,
  duration: '30s',
  thresholds: {
    http_req_duration: ['p(95)<500'], // RNF-02: p95 <= 500 ms con 100 usuarios concurrentes
  },
};

const BASE_URL = __ENV.API_URL || 'http://127.0.0.1:8000';
const TOKEN = __ENV.API_TOKEN || '';

export default function () {
  const payload = JSON.stringify({
    tasks: [
      {
        id: '6f1c0000-0000-4000-8000-000000000001',
        titulo: 'Prueba de carga RNF-02',
        prioridad: 2,
        completada: false,
        pomodoros_estimados: 2,
        updated_at: new Date().toISOString(),
      },
    ],
    sessions: [],
    tareas_eliminadas: [],
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Bearer ${TOKEN}`,
    },
  };

  const res = http.post(`${BASE_URL}/api/sync`, payload, params);
  check(res, {
    'status es 200 o 401': (r) => r.status === 200 || r.status === 401,
  });
  sleep(1);
}
