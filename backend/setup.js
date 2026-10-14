const fs = require('node:fs');
const path = require('node:path');
const { randomBytes } = require('node:crypto');

const filename = path.join(__dirname, '.env');
if (fs.existsSync(filename)) {
  console.log('backend/.env already exists; existing configuration preserved.');
} else {
  fs.writeFileSync(filename, [
    'HOST=127.0.0.1',
    'PORT=8787',
    'ALLOWED_ORIGINS=',
    'PAYMENT_RECEIPTS_ENABLED=false',
    `SEPAY_WEBHOOK_KEY=${randomBytes(32).toString('hex')}`,
    '',
  ].join('\n'), { flag: 'wx', mode: 0o600 });
  console.log('Created backend/.env with a random webhook key. Copy the key into SePay webhook settings; never into Flutter.');
}
