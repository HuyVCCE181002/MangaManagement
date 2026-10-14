const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { Payments, PaymentError } = require('./payments');

function createServer(payments, { allowedOrigins = [], maxBodyBytes = 16384, receiptsEnabled = true } = {}) {
  const sessionAttempts = new Map();
  return http.createServer(async (request, response) => {
    const send = (code, data) => {
      response.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      response.end(JSON.stringify(data));
    };
    const origin = request.headers.origin;
    const localOrigin = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin || '');
    if (origin && !localOrigin && !allowedOrigins.includes(origin)) return send(403, { error: 'Origin không được phép.' });
    if (origin) {
      response.setHeader('Access-Control-Allow-Origin', origin);
      response.setHeader('Vary', 'Origin');
      response.setHeader('Access-Control-Allow-Headers', 'content-type, authorization, idempotency-key');
      response.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    }
    if (request.method === 'OPTIONS') return send(204, {});
    try {
      const url = new URL(request.url, 'http://localhost');
      if (url.pathname === '/health' && request.method === 'GET') return send(200, { ready: Boolean(payments.webhookKey) && receiptsEnabled, provider: 'sepay' });
      let body = {};
      if (request.method === 'POST') {
        const chunks = [];
        let size = 0;
        for await (const chunk of request) {
          size += chunk.length;
          if (size > maxBodyBytes) throw new PaymentError(413, 'Yêu cầu quá lớn.');
          chunks.push(chunk);
        }
        const raw = Buffer.concat(chunks).toString('utf8');
        try { body = JSON.parse(raw); } catch (_) { throw new PaymentError(400, 'JSON không hợp lệ.'); }
        if (!body || typeof body !== 'object' || Array.isArray(body)) throw new PaymentError(400, 'JSON không hợp lệ.');
      }
      if (url.pathname === '/webhooks/sepay' && request.method === 'POST') {
        return send(200, payments.webhook(request.headers.authorization, body));
      }
      if (url.pathname === '/sessions' && request.method === 'POST') {
        const ip = request.socket.remoteAddress;
        const now = Date.now();
        for (const [key, entry] of sessionAttempts) if (now - entry.since > 600000) sessionAttempts.delete(key);
        const attempts = sessionAttempts.get(ip) || { count: 0, since: now };
        if (++attempts.count > 30) throw new PaymentError(429, 'Quá nhiều lần đăng nhập. Thử lại sau 10 phút.');
        sessionAttempts.set(ip, attempts);
        return send(200, payments.session(body));
      }
      const userId = payments.authenticate(request.headers.authorization);
      if (url.pathname === '/payments/orders' && request.method === 'POST') {
        if (!payments.webhookKey || !receiptsEnabled) throw new PaymentError(503, 'Chưa bật kết nối SePay. Chủ tài khoản cần liên kết ngân hàng và cấu hình webhook trước khi chuyển tiền.');
        return send(201, payments.createOrder(userId, body, request.headers['idempotency-key']));
      }
      if (url.pathname === '/payments/orders' && request.method === 'GET') return send(200, { orders: payments.orders(userId) });
      const id = /^\/payments\/orders\/([a-f0-9-]{36})$/.exec(url.pathname)?.[1];
      if (id && request.method === 'GET') return send(200, payments.order(userId, id));
      if (id && request.method === 'DELETE') return send(200, payments.cancel(userId, id));
      send(404, { error: 'Không tìm thấy endpoint.' });
    } catch (error) {
      send(error.status || 500, { error: error.status ? error.message : 'Lỗi server. Vui lòng thử lại.' });
    }
  });
}

if (require.main === module) {
  const dataDir = path.join(__dirname, '.data');
  fs.mkdirSync(dataDir, { recursive: true });
  const webhookKey = process.env.SEPAY_WEBHOOK_KEY;
  if (!webhookKey || webhookKey.length < 32) throw new Error('Chạy node backend/setup.js trước để tạo SEPAY_WEBHOOK_KEY.');
  const payments = new Payments(path.join(dataDir, 'payments.sqlite'), { webhookKey });
  const server = createServer(payments, {
    allowedOrigins: (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean),
    receiptsEnabled: process.env.PAYMENT_RECEIPTS_ENABLED === 'true',
  });
  server.requestTimeout = 15000;
  server.listen(Number(process.env.PORT || 8787), process.env.HOST || '127.0.0.1', () => {
    console.log('Payment backend ready on port ' + (process.env.PORT || 8787) + '. Waiting for authenticated SePay receipts.');
  });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => { payments.close(); process.exit(); }));
}

module.exports = { createServer };
