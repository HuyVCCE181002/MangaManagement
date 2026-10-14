const { DatabaseSync } = require('node:sqlite');
const { randomUUID, randomBytes, scryptSync, timingSafeEqual, createHash } = require('node:crypto');
const catalog = require('./catalog.json');

class PaymentError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

class Payments {
  constructor(filename, { webhookKey, now = Date.now, accountNumber = '070118746463' } = {}) {
    this.webhookKey = webhookKey;
    this.now = now;
    this.accountNumber = accountNumber;
    this.db = new DatabaseSync(filename);
    this.db.exec(`
      PRAGMA foreign_keys=ON;
      PRAGMA journal_mode=WAL;
      PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, salt TEXT NOT NULL, password_hash TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), request_key TEXT NOT NULL,
        transfer_code TEXT UNIQUE NOT NULL, package_json TEXT NOT NULL, promo_code TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount>0), status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, verified_at INTEGER,
        paid_at INTEGER, UNIQUE(user_id,request_key)
      );
      CREATE TABLE IF NOT EXISTS bank_events (
        id TEXT PRIMARY KEY, reference TEXT UNIQUE NOT NULL, fingerprint TEXT NOT NULL,
        disposition TEXT NOT NULL, order_id TEXT, received_at INTEGER NOT NULL, payload_json TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS credits (
        order_id TEXT PRIMARY KEY REFERENCES orders(id), user_id TEXT NOT NULL REFERENCES users(id),
        event_id TEXT UNIQUE NOT NULL REFERENCES bank_events(id), coins INTEGER NOT NULL CHECK(coins>0)
      );
    `);
  }

  atomic(fn) {
    this.db.exec('BEGIN IMMEDIATE');
    try { const result = fn(); this.db.exec('COMMIT'); return result; }
    catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }

  session({ username, password }) {
    if (typeof username !== 'string' || !/^[a-z0-9_.-]{3,64}$/i.test(username) ||
        typeof password !== 'string' || password.length < 4 || password.length > 256) {
      throw new PaymentError(400, 'Tên đăng nhập hoặc mật khẩu không hợp lệ.');
    }
    username = username.toLowerCase();
    return this.atomic(() => {
      let user = this.db.prepare('SELECT * FROM users WHERE username=?').get(username);
      // A first payment login creates a payment account. Existing accounts
      // require their original password; client-supplied local user IDs are ignored.
      if (!user) {
        const salt = randomBytes(16).toString('hex');
        const hash = scryptSync(password, salt, 64).toString('hex');
        user = { id: randomUUID(), username, salt, password_hash: hash };
        this.db.prepare('INSERT INTO users VALUES (?,?,?,?)').run(user.id, username, salt, hash);
      } else if (!timingSafeEqual(scryptSync(password, user.salt, 64), Buffer.from(user.password_hash, 'hex'))) {
        throw new PaymentError(401, 'Mật khẩu tài khoản thanh toán không đúng.');
      }
      const token = randomBytes(32).toString('hex');
      const expiresAt = this.now() + 24 * 60 * 60 * 1000;
      this.db.prepare('DELETE FROM sessions WHERE expires_at<=?').run(this.now());
      this.db.prepare('INSERT INTO sessions VALUES (?,?,?)').run(this.digest(token), user.id, expiresAt);
      return { token, expiresAt: new Date(expiresAt).toISOString() };
    });
  }

  digest(value) { return createHash('sha256').update(value).digest('hex'); }

  authenticate(header) {
    const token = /^Bearer ([a-f0-9]{64})$/.exec(header || '')?.[1];
    const session = token && this.db.prepare('SELECT user_id FROM sessions WHERE token_hash=? AND expires_at>?')
      .get(this.digest(token), this.now());
    if (!session) throw new PaymentError(401, 'Vui lòng đăng nhập lại.');
    return session.user_id;
  }

  publicOrder(row) {
    if (!row) return null;
    const status = row.status === 'pending' && row.expires_at <= this.now() ? 'expired' : row.status;
    return {
      id: row.id, transferCode: row.transfer_code, package: JSON.parse(row.package_json),
      promoCode: row.promo_code, amount: row.amount, status,
      createdAt: new Date(row.created_at).toISOString(), expiresAt: new Date(row.expires_at).toISOString(),
      paidAt: row.paid_at ? new Date(row.paid_at).toISOString() : null,
      verifiedAt: row.verified_at ? new Date(row.verified_at).toISOString() : null,
      bankBin: '970403', accountNumber: this.accountNumber, accountName: 'NGO VIET TRINH',
    };
  }

  createOrder(userId, input, requestKey) {
    if (!/^[a-zA-Z0-9-]{16,80}$/.test(requestKey || '')) throw new PaymentError(400, 'Thiếu mã chống tạo đơn trùng.');
    // Only the package ID and promotion code are accepted. Price/coins/status
    // never come from the browser or from the client's local SQLite database.
    const pkg = catalog.packages.find((p) => p.id === input.packageId && p.active !== false);
    if (!pkg) throw new PaymentError(400, 'Gói coins không khả dụng trên server.');
    const promo = String(input.promoCode || '').trim().toUpperCase();
    if (promo && !Object.hasOwn(catalog.promotions, promo)) throw new PaymentError(400, 'Mã khuyến mãi không hợp lệ.');
    return this.atomic(() => {
      let row = this.db.prepare('SELECT * FROM orders WHERE user_id=? AND request_key=?').get(userId, requestKey);
      if (row) {
        if (JSON.parse(row.package_json).id !== pkg.id || row.promo_code !== promo) throw new PaymentError(409, 'Mã yêu cầu đã dùng cho đơn khác.');
        return this.publicOrder(row);
      }
      row = this.db.prepare("SELECT * FROM orders WHERE user_id=? AND status='pending' AND expires_at>? ORDER BY created_at DESC LIMIT 1")
        .get(userId, this.now());
      if (row) {
        if (JSON.parse(row.package_json).id !== pkg.id || row.promo_code !== promo) throw new PaymentError(409, 'Bạn còn một giao dịch đang chờ. Hãy cập nhật giao dịch đó.');
        return this.publicOrder(row);
      }
      const id = randomUUID();
      const code = `MANGA${randomBytes(8).toString('hex').toUpperCase()}`;
      const amount = Math.round(pkg.price * (1 - (catalog.promotions[promo] || 0) / 100));
      const created = this.now();
      this.db.prepare(`INSERT INTO orders (id,user_id,request_key,transfer_code,package_json,promo_code,amount,created_at,expires_at)
        VALUES (?,?,?,?,?,?,?,?,?)`).run(id, userId, requestKey, code, JSON.stringify(pkg), promo, amount, created, created + 600000);
      return this.publicOrder(this.db.prepare('SELECT * FROM orders WHERE id=?').get(id));
    });
  }

  orders(userId) {
    return this.db.prepare('SELECT * FROM orders WHERE user_id=? ORDER BY created_at DESC').all(userId).map((row) => this.publicOrder(row));
  }

  order(userId, id) {
    const order = this.publicOrder(this.db.prepare('SELECT * FROM orders WHERE id=? AND user_id=?').get(id, userId));
    if (!order) throw new PaymentError(404, 'Không tìm thấy giao dịch.');
    return order;
  }

  cancel(userId, id) {
    this.db.prepare("UPDATE orders SET status='cancelled' WHERE id=? AND user_id=? AND status='pending'").run(id, userId);
    return this.order(userId, id);
  }

  webhook(header, event) {
    const expected = `Apikey ${this.webhookKey}`;
    if (!this.webhookKey || typeof header !== 'string' || Buffer.byteLength(header) !== Buffer.byteLength(expected) ||
        !timingSafeEqual(Buffer.from(header), Buffer.from(expected))) {
      throw new PaymentError(401, 'Webhook không được xác thực.');
    }
    if (!Number.isSafeInteger(event.id) || event.id <= 0 || typeof event.referenceCode !== 'string' || !event.referenceCode ||
        !Number.isSafeInteger(event.transferAmount) || event.transferAmount <= 0 || typeof event.transactionDate !== 'string') {
      throw new PaymentError(400, 'Dữ liệu SePay không hợp lệ.');
    }
    const date = event.transactionDate;
    if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(date)) throw new PaymentError(400, 'Thời gian giao dịch không hợp lệ.');
    const paidAt = Date.parse(date.replace(' ', 'T') + '+07:00');
    if (!Number.isFinite(paidAt)) throw new PaymentError(400, 'Thời gian giao dịch không hợp lệ.');
    const id = String(event.id);
    const reference = `${event.gateway}:${event.referenceCode}`;
    const fingerprint = this.digest(JSON.stringify([event.id, event.gateway, event.accountNumber, event.transferType, event.transferAmount, date, event.content, event.code, event.referenceCode]));
    return this.atomic(() => {
      const previous = this.db.prepare('SELECT * FROM bank_events WHERE id=? OR reference=?').get(id, reference);
      if (previous) {
        if (previous.fingerprint !== fingerprint) throw new PaymentError(409, 'Giao dịch ngân hàng đã được ghi nhận với dữ liệu khác.');
        return { success: true };
      }
      const codes = (`${event.code || ''} ${event.content || ''}`).toUpperCase().match(/MANGA[A-F0-9]{16}(?![A-F0-9])/g) || [];
      const matches = [...new Set(codes)].map((code) => this.db.prepare('SELECT * FROM orders WHERE transfer_code=?').get(code)).filter(Boolean);
      const row = matches.length === 1 ? matches[0] : null;
      let disposition = 'unmatched';
      if (event.transferType !== 'in' || event.accountNumber !== this.accountNumber || !/^sacombank$/i.test(event.gateway || '')) disposition = 'wrong_destination';
      else if (row) {
        if (row.status !== 'pending') disposition = 'order_closed';
        else if (event.transferAmount !== row.amount) disposition = 'wrong_amount';
        else if (paidAt < row.created_at - 1000 || paidAt > row.expires_at || paidAt > this.now() + 60000) disposition = 'outside_payment_window';
        else disposition = 'credited';
      }
      this.db.prepare('INSERT INTO bank_events VALUES (?,?,?,?,?,?,?)').run(id, reference, fingerprint, disposition, row?.id || null, this.now(), JSON.stringify(event));
      if (disposition === 'credited') {
        const pkg = JSON.parse(row.package_json);
        this.db.prepare('INSERT INTO credits VALUES (?,?,?,?)').run(row.id, row.user_id, id, pkg.coins + pkg.bonusCoins);
        this.db.prepare("UPDATE orders SET status='completed',paid_at=?,verified_at=? WHERE id=? AND status='pending'")
          .run(paidAt, this.now(), row.id);
      }
      // Authenticated unmatched/mismatched receipts are retained for manual
      // reconciliation. Never turn them into fake success or discard them.
      return { success: true };
    });
  }

  close() { this.db.close(); }
}

module.exports = { Payments, PaymentError };
