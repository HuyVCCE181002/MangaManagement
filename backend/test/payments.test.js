const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Payments } = require('../payments');
const { createServer } = require('../server');

const key = 'private-test-webhook-key-long-enough';
const started = Date.parse('2026-10-14T03:00:00+07:00');
function fixture(t) {
  let time = started;
  const p = new Payments(':memory:', { webhookKey: key, now: () => time });
  t.after(() => p.close());
  const token = p.session({ username: 'reader', password: 'reader123' }).token;
  const user = p.authenticate(`Bearer ${token}`);
  const order = () => p.createOrder(user, { packageId: 'pkg_4', amount: 1, coins: 999999, status: 'completed' }, randomUUID());
  const receipt = (o, overrides = {}) => ({ id: 77, gateway: 'Sacombank', transactionDate: '2026-10-14 03:00:10',
    accountNumber: '070118746463', transferType: 'in', transferAmount: o.amount,
    content: `Nap coin ${o.transferCode}`, referenceCode: 'BANK77', ...overrides });
  return { p, user, order, receipt, advance: (ms) => { time += ms; } };
}

test('server prices and coin rules cannot be replaced by browser fields; order creation is idempotent', (t) => {
  const { p, user, order } = fixture(t);
  const o = order();
  assert.equal(o.amount, 160000);
  assert.equal(o.package.coins + o.package.bonusCoins, 2400);
  assert.equal(o.status, 'pending');
  assert.equal(order().id, o.id);
  const requestKey = randomUUID();
  const a = p.createOrder(user, { packageId: 'pkg_4' }, requestKey);
  assert.equal(p.createOrder(user, { packageId: 'pkg_4' }, requestKey).id, a.id);
});

test('signed provider receipt credits exactly once, including duplicate/concurrent retry calls', (t) => {
  const { p, user, order, receipt } = fixture(t);
  const o = order();
  for (let i = 0; i < 5; i++) assert.deepEqual(p.webhook(`Apikey ${key}`, receipt(o)), { success: true });
  assert.equal(p.order(user, o.id).status, 'completed');
  assert.equal(p.db.prepare('SELECT SUM(coins) AS coins FROM credits').get().coins, 2400);
  assert.equal(p.db.prepare('SELECT COUNT(*) AS n FROM credits').get().n, 1);
});

test('unsigned, outgoing, wrong account, wrong amount, missing bank, or fake client status never credit', (t) => {
  const { p, order, receipt } = fixture(t);
  const o = order();
  assert.throws(() => p.webhook('', receipt(o)), { status: 401 });
  const cases = [{ transferType: 'out' }, { accountNumber: '000' }, { transferAmount: 1 }, { gateway: undefined }];
  cases.forEach((extra, i) => p.webhook(`Apikey ${key}`, receipt(o, { id: 80 + i, referenceCode: `OTHER${i}`, ...extra })));
  assert.equal(p.db.prepare('SELECT COUNT(*) AS n FROM credits').get().n, 0);
});

test('expiry uses server time; delayed callback for a timely payment still reconciles', (t) => {
  const { p, user, order, receipt, advance } = fixture(t);
  const o = order();
  advance(601000);
  assert.equal(p.order(user, o.id).status, 'expired');
  p.webhook(`Apikey ${key}`, receipt(o));
  assert.equal(p.order(user, o.id).status, 'completed');
});

test('late transfers are retained for reconciliation and cannot credit a new order', (t) => {
  const { p, user, order, receipt, advance } = fixture(t);
  const old = order();
  advance(601000);
  const fresh = order();
  assert.notEqual(fresh.transferCode, old.transferCode);
  p.webhook(`Apikey ${key}`, receipt(old, { transactionDate: '2026-10-14 03:11:00' }));
  assert.equal(p.order(user, old.id).status, 'expired');
  assert.equal(p.order(user, fresh.id).status, 'pending');
  assert.equal(p.db.prepare('SELECT disposition FROM bank_events').get().disposition, 'outside_payment_window');
});

test('users cannot read another account orders or log in with the wrong password', (t) => {
  const { p, order } = fixture(t);
  const o = order();
  assert.throws(() => p.session({ username: 'reader', password: 'wrong' }), { status: 401 });
  const second = p.authenticate('Bearer ' + p.session({ username: 'another', password: 'secret' }).token);
  assert.throws(() => p.order(second, o.id), { status: 404 });
});

test('HTTP API integrates order before QR, authenticated webhook and polling without a simulation route', async (t) => {
  const { p } = fixture(t);
  const server = createServer(p);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  const session = await fetch(base + '/sessions', { method: 'POST', body: JSON.stringify({ username: 'reader', password: 'reader123' }) }).then((r) => r.json());
  const response = await fetch(base + '/payments/orders', { method: 'POST', headers: { Authorization: 'Bearer ' + session.token, 'Idempotency-Key': randomUUID() }, body: JSON.stringify({ packageId: 'pkg_1' }) });
  assert.equal(response.status, 201);
  const o = await response.json();
  const unauth = await fetch(base + '/webhooks/sepay', { method: 'POST', body: JSON.stringify({}) });
  assert.equal(unauth.status, 401);
  const webhook = await fetch(base + '/webhooks/sepay', { method: 'POST', headers: { Authorization: `Apikey ${key}` }, body: JSON.stringify({ id: 99, gateway: 'Sacombank', transactionDate: '2026-10-14 03:00:10', accountNumber: '070118746463', transferType: 'in', transferAmount: 10000, content: o.transferCode, referenceCode: 'BANK99' }) });
  assert.deepEqual(await webhook.json(), { success: true });
  const polled = await fetch(base + '/payments/orders/' + o.id, { headers: { Authorization: 'Bearer ' + session.token } }).then((r) => r.json());
  assert.equal(polled.status, 'completed');
});
