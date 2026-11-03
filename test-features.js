/**
 * Feature smoke tests for Headburst VPS Panel
 */
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

const PORT = 3099;
const PASS = 'test-pass-123';
const base = `http://127.0.0.1:${PORT}`;

function req(method, urlPath, body, cookie) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const r = http.request(
      base + urlPath,
      {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(cookie ? { Cookie: cookie } : {}),
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let buf = '';
        res.on('data', (c) => (buf += c));
        res.on('end', () => {
          let json = {};
          try { json = JSON.parse(buf); } catch { json = { raw: buf }; }
          resolve({ status: res.statusCode, headers: res.headers, json, raw: buf });
        });
      }
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

function getCookie(res) {
  const set = res.headers['set-cookie'];
  if (!set) return '';
  return set.map((c) => c.split(';')[0]).join('; ');
}

async function main() {
  const child = spawn('node', ['server.js'], {
    cwd: path.join(__dirname),
    env: { ...process.env, PORT: String(PORT), PANEL_PASS: PASS, FILE_ROOT: path.join(__dirname, 'data') },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  await new Promise((r) => setTimeout(r, 800));

  const results = [];
  const ok = (name, pass, detail = '') => {
    results.push({ name, pass, detail });
    console.log((pass ? 'PASS' : 'FAIL') + '  ' + name + (detail ? ' — ' + detail : ''));
  };

  try {
    let res = await req('POST', '/api/login', { password: 'wrong' });
    ok('login reject wrong password', res.status === 401);

    res = await req('POST', '/api/login', { password: PASS });
    ok('login accept correct password', res.status === 200 && res.json.ok);
    const cookie = getCookie(res);

    res = await req('GET', '/api/me', null, cookie);
    ok('session me ok', res.json.ok === true);

    res = await req('GET', '/api/status', null, cookie);
    ok('status endpoint', res.status === 200 && typeof res.json.log === 'string');

    res = await req('POST', '/api/passwords', {
      label: 'Test VPS',
      host: '1.2.3.4',
      username: 'root',
      password: 'secret-vps-pass',
      notes: 'unit test',
    }, cookie);
    ok('password add', res.status === 200 && res.json.id);
    const pid = res.json.id;

    res = await req('GET', '/api/passwords', null, cookie);
    ok('password view', res.status === 200 && res.json.entries.some((e) => e.password === 'secret-vps-pass'));

    res = await req('PUT', '/api/passwords/' + pid, { password: 'changed-pass' }, cookie);
    ok('password change', res.status === 200);

    res = await req('GET', '/api/passwords', null, cookie);
    ok('password changed readable', res.json.entries.some((e) => e.password === 'changed-pass'));

    res = await req('DELETE', '/api/passwords/' + pid, null, cookie);
    ok('password delete', res.status === 200);

    res = await req('GET', '/api/files?path=/', null, cookie);
    ok('files list', res.status === 200 && Array.isArray(res.json.items));

    res = await req('POST', '/api/exec', { cmd: 'echo headburst-ok && whoami' }, cookie);
    ok('console exec', res.status === 200 && (res.json.stdout || '').includes('headburst-ok'));

    res = await req('GET', '/api/jobs/does-not-exist', null, cookie);
    ok('job 404', res.status === 404);

    res = await req('GET', '/', null, cookie);
    ok('ui served', res.status === 200 && (res.raw || '').includes('HEADBURST'));
  } catch (e) {
    ok('suite exception', false, e.message);
  }

  child.kill('SIGTERM');
  const failed = results.filter((r) => !r.pass).length;
  console.log('\n' + results.length + ' tests, ' + failed + ' failed');
  process.exit(failed ? 1 : 0);
}

main();
