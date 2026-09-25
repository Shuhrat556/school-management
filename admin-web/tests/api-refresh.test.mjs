// Run with: npm test  (Node's built-in test runner, no extra dependencies)
import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// Minimal browser globals for src/lib/api.js
const store = new Map();
globalThis.localStorage = {
  getItem: (key) => (store.has(key) ? store.get(key) : null),
  setItem: (key, value) => store.set(key, String(value)),
  removeItem: (key) => store.delete(key),
};
globalThis.window = { location: { href: '' } };

const api = await import('../src/lib/api.js');

let refreshCalls;

// The server rotates refresh tokens: a refresh token works once.
function installServer() {
  refreshCalls = 0;
  let validRefresh = 'refresh-1';
  globalThis.fetch = async (path, options = {}) => {
    if (path === '/api/auth/refresh') {
      refreshCalls += 1;
      const { refreshToken } = JSON.parse(options.body);
      await new Promise((resolve) => setTimeout(resolve, 10));
      if (refreshToken !== validRefresh) return new Response('{}', { status: 401 });
      validRefresh = `refresh-${refreshCalls + 1}`;
      return Response.json({ token: 'fresh-access', refreshToken: validRefresh });
    }
    const auth = options.headers?.Authorization;
    if (auth !== 'Bearer fresh-access') return new Response('{}', { status: 401 });
    return Response.json([{ id: 1 }]);
  };
}

beforeEach(() => {
  store.clear();
  store.set('token', 'expired-access');
  store.set('refreshToken', 'refresh-1');
  store.set('user', JSON.stringify({ email: 'teacher@school.test', role: 1 }));
  window.location.href = '';
  installServer();
});

test('concurrent 401s share one token refresh', async () => {
  const results = await Promise.all([api.getDepartments(), api.getDepartments(), api.getDepartments()]);

  assert.equal(refreshCalls, 1);
  for (const result of results) assert.deepEqual(result, [{ id: 1 }]);
  assert.equal(localStorage.getItem('token'), 'fresh-access');
  assert.equal(window.location.href, '');
});

test('a failed refresh signs the user out', async () => {
  store.set('refreshToken', 'stale');

  await api.getDepartments();

  assert.equal(localStorage.getItem('token'), null);
  assert.equal(window.location.href, '/login');
});
