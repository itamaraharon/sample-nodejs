const request = require('supertest');
const app = require('../app');

describe('sample-nodejs endpoints', () => {
    test('GET /my-app returns 200', async () => {
        const res = await request(app).get('/my-app');
        expect(res.status).toBe(200);
    });

    test('GET /about returns 200', async () => {
        const res = await request(app).get('/about');
        expect(res.status).toBe(200);
    });

    test('GET /ready returns 200', async () => {
        const res = await request(app).get('/ready');
        expect(res.status).toBe(200);
    });

    test('GET /live returns 200', async () => {
        const res = await request(app).get('/live');
        expect(res.status).toBe(200);
    });

    test('GET /metrics returns 200', async () => {
        const res = await request(app).get('/metrics');
        expect(res.status).toBe(200);
    });
});
