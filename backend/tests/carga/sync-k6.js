import http from 'k6/http';
import { check, sleep } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export const options = {
  vus: 100,
  duration: '60s',
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.API_URL;
const EMAIL = __ENV.EMAIL;
const PASSWORD = __ENV.PASSWORD;

export function setup() {
  const loginRes = http.post(
    `${BASE_URL}/api/login`,
    JSON.stringify({
      email: EMAIL,
      password: PASSWORD,
      device_name: 'k6',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    }
  );

  check(loginRes, {
    'login status es 200': (r) => r.status === 200,
  });

  const body = loginRes.json();
  return { token: body ? body.token : '' };
}

export default function (data) {
  const payload = JSON.stringify({
    tasks: [
      {
        id: uuidv4(),
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
      Authorization: `Bearer ${data.token}`,
    },
  };

  const res = http.post(`${BASE_URL}/api/sync`, payload, params);
  check(res, {
    'status es 200': (r) => r.status === 200,
  });
  sleep(1);
}
