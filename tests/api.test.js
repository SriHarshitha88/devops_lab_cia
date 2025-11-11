const request = require('supertest');
const app = require('../server');

describe('API Endpoints', () => {
  test('GET /api should return welcome message', async () => {
    const response = await request(app)
      .get('/api')
      .expect(200);

    expect(response.body.message).toContain('Welcome');
  });

  test('GET /health should return OK status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.status).toBe('OK');
  });

  test('GET /api/users should return list of users', async () => {
    const response = await request(app)
      .get('/api/users')
      .expect(200);

    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body.length).toBeGreaterThan(0);
  });

  test('GET /health should include uptime', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body).toHaveProperty('uptime');
    expect(typeof response.body.uptime).toBe('number');
  });
});