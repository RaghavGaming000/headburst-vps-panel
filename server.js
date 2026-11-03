/**
 * Headburst VPS Panel — local control UI for install scripts
 */
const express = require('express');
const session = require('express-session');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3080;
const ROOT = __dirname;
const SCRIPTS = path.join(ROOT, 'scripts');
const PASS = process.env.PANEL_PASS || 'headburst@vps';

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(
  session({
    secret: process.env.SESSION_SECRET || crypto.randomBytes(16).toString('hex'),
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 8 * 3600 * 1000 },
  })
);
app.use(express.static(path.join(ROOT, 'public')));

function auth(req, res, next) {
  if (req.session && req.session.ok) return next();
  return res.status(401).json({ error: 'login required' });
}

const jobs = new Map();

function runScript(name, args = []) {
  const id = crypto.randomBytes(8).toString('hex');
  const script = path.join(SCRIPTS, name);
  if (!fs.existsSync(script)) {
    jobs.set(id, { status: 'error', log: 'script not found: ' + name, ended: Date.now() });
    return id;
  }
  const log = [];
  jobs.set(id, { status: 'running', log, started: Date.now() });
  const child = spawn('bash', [script, ...args], {
    env: { ...process.env },
    cwd: ROOT,
  });
  child.stdout.on('data', (d) => log.push(d.toString()));
  child.stderr.on('data', (d) => log.push(d.toString()));
  child.on('close', (code) => {
    const j = jobs.get(id);
    if (j) {
      j.status = code === 0 ? 'done' : 'error';
      j.code = code;
      j.ended = Date.now();
    }
  });
  return id;
}

app.post('/api/login', (req, res) => {
  const { password } = req.body || {};
  if (String(password) === PASS) {
    req.session.ok = true;
    return res.json({ ok: true });
  }
  res.status(401).json({ error: 'wrong password' });
});

app.post('/api/logout', (req, res) => {
  req.session.destroy(() => {});
  res.json({ ok: true });
});

app.get('/api/me', (req, res) => {
  res.json({ ok: !!(req.session && req.session.ok) });
});

app.get('/api/status', auth, (req, res) => {
  const id = runScript('status.sh');
  setTimeout(() => {
    const j = jobs.get(id) || { log: [] };
    res.json({ status: j.status, log: (j.log || []).join('') });
  }, 800);
});

app.post('/api/install/panel', auth, (req, res) => {
  const { domain, email, username, password } = req.body || {};
  const id = runScript('install-panel.sh', [
    domain || 'panel.example.com',
    email || 'admin@example.com',
    username || 'admin',
    password || 'ChangeMe123!',
  ]);
  res.json({ jobId: id });
});

app.post('/api/install/wings', auth, (req, res) => {
  res.json({ jobId: runScript('install-wings.sh') });
});

app.post('/api/install/blueprint', auth, (req, res) => {
  res.json({ jobId: runScript('install-blueprint.sh') });
});

app.post('/api/install/theme', auth, (req, res) => {
  const { url, name } = req.body || {};
  if (!url) return res.status(400).json({ error: 'theme url required' });
  res.json({ jobId: runScript('install-theme.sh', [url, name || 'custom-theme']) });
});

app.get('/api/jobs/:id', auth, (req, res) => {
  const j = jobs.get(req.params.id);
  if (!j) return res.status(404).json({ error: 'not found' });
  res.json({
    status: j.status,
    code: j.code,
    log: (j.log || []).join(''),
  });
});

app.get('*', (_req, res) => {
  res.sendFile(path.join(ROOT, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Headburst VPS Panel → http://127.0.0.1:${PORT}`);
  console.log(`Password: ${PASS}`);
});
