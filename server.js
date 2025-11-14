// server.js
// Express + WebSocket server with simple authentication for owners and Defesa Civil
// - Serves static files from project folder
// - Endpoints: /api/register-owner, /api/login, /api/login-defense, /api/whoami
// - Persists users to users.json (simple file store)
// - Protects WebSocket connections: requires token query param

const express = require('express');
const cors = require('cors');
const http = require('http');
const https = require('https');
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const os = require('os');
const child_process = require('child_process');

// Import new Phase 4 modules
const deviceRegistryModule = require('./device-registry-init');
const healthChecks = require('./health-checks');

const PORT = process.env.PORT || 8080;
const OWNER_CODE = process.env.OWNER_CODE || 'OWNER-SECRET-CHANGEME';
const DEFENSE_CODE = process.env.DEFENSE_CODE || 'DEFENSE-SECRET-CHANGEME';
const USERS_FILE = path.join(__dirname, 'users.json');

// Load or initialize users file
function loadUsers() {
  try {
    const raw = fs.readFileSync(USERS_FILE, 'utf8');
    return JSON.parse(raw || '[]');
  } catch (e) {
    return [];
  }
}
function saveUsers(users) {
  fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2), 'utf8');
}

const users = loadUsers(); // array of { id, username, passwordHash, role }

// token store in-memory: token -> { userId, role, expires }
const tokens = new Map();
function issueToken(userId, role) {
  const token = uuidv4();
  const expires = Date.now() + 24*60*60*1000; // 24h
  tokens.set(token, { userId, role, expires });
  return token;
}
function validateToken(token) {
  const rec = tokens.get(token);
  if (!rec) return null;
  if (Date.now() > rec.expires) { tokens.delete(token); return null; }
  return rec;
}

// Verify Dilithium signature by invoking the Rust verifier CLI.
// The verifier uses native pqc_dilithium (no external OpenSSL dependency)
// Expects: dilithium_verify <pub-key-file> <message-file> <sig-file>
function verifyDilithiumSignature(deviceId, dilithium_pubkey, dilithium_signature) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dil-verify-'));
  const pubPath = path.join(tmp, 'pub.key');
  const sigPath = path.join(tmp, 'sig.bin');
  const msgPath = path.join(tmp, 'msg.bin');

  try {
    // Write public key (expect hex string from pqc_dilithium keygen)
    if (typeof dilithium_pubkey === 'string' && dilithium_pubkey.match(/^[0-9a-f]*$/i)) {
      // Hex string
      fs.writeFileSync(pubPath, Buffer.from(dilithium_pubkey, 'hex'));
    } else if (typeof dilithium_pubkey === 'string') {
      // Try base64, then raw
      try {
        fs.writeFileSync(pubPath, Buffer.from(dilithium_pubkey, 'base64'));
      } catch (e) {
        fs.writeFileSync(pubPath, dilithium_pubkey, 'utf8');
      }
    } else {
      // Buffer
      fs.writeFileSync(pubPath, dilithium_pubkey);
    }

    // signature is base64 (from device)
    fs.writeFileSync(sigPath, Buffer.from(dilithium_signature, 'base64'));
    
    // message is deviceId bytes
    fs.writeFileSync(msgPath, Buffer.from(String(deviceId), 'utf8'));

    // Find dilithium_verify binary
    const binOverride = process.env.DILITHIUM_VERIFIER_BIN;
    const binName = process.platform === 'win32' ? 'dilithium_verify.exe' : 'dilithium_verify';
    const defaultBin = path.join(__dirname, 'meu_projeto_dilithium', 'target', 'release', binName);
    const binPath = binOverride ? binOverride : defaultBin;

    if (!fs.existsSync(binPath)) {
      throw new Error(`dilithium_verify not found at ${binPath}. Build with: cd meu_projeto_dilithium && cargo build --release`);
    }

    // Call the verifier: dilithium_verify <pub-key-file> <message-file> <sig-file>
    const res = child_process.spawnSync(binPath, [pubPath, msgPath, sigPath], {
      encoding: 'utf8',
      timeout: 10000,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    if (res.error) throw res.error;
    
    if (res.status === 0) {
      return true; // Valid signature
    } else if (res.status === 1) {
      console.warn(`Dilithium verification failed for ${deviceId}: invalid signature`);
      return false;
    } else {
      throw new Error(`Dilithium verifier error: ${res.stderr || res.stdout || 'unknown'}`);
    }
  } finally {
    // cleanup
    try { fs.unlinkSync(pubPath); fs.unlinkSync(sigPath); fs.unlinkSync(msgPath); fs.rmdirSync(tmp); } catch (e) {}
  }
}

// Helper to attempt adding peer to wg config and (optionally) to live interface
function addWireguardPeer(deviceId, wg_pubkey, wg_ip) {
  try {
    const WG_CONF = process.env.WG_CONFIG_PATH || path.join(__dirname, 'wg-config', 'wg0.conf');
    const ipParts = wg_ip.split('/')[0].split('.');
    const index = parseInt(ipParts[3], 10);
    const addScript = path.join(__dirname, 'add_peer.sh');
    if (!fs.existsSync(addScript)) {
      console.warn('add_peer.sh not found; skipping wg config update');
      return { ok: false, reason: 'add_peer_missing' };
    }

    const spawnRes = child_process.spawnSync(addScript, [deviceId, wg_pubkey, WG_CONF, '10.0.0', String(index)], { encoding: 'utf8', timeout: 10000 });
    if (spawnRes.error) return { ok: false, reason: spawnRes.error.message };
    if (spawnRes.status !== 0) return { ok: false, reason: spawnRes.stderr || spawnRes.stdout };

    // Try to add peer to running wg interface if wg is available and process has permission
    try {
      const wgBin = 'wg';
      if (child_process.spawnSync(wgBin, ['--version']).status === 0) {
        // Use `wg set` to add peer
        const setRes = child_process.spawnSync(wgBin, ['set', 'wg0', 'peer', wg_pubkey, 'allowed-ips', wg_ip], { encoding: 'utf8', timeout: 8000 });
        if (setRes.error || setRes.status !== 0) {
          // Not fatal; return warning
          return { ok: true, note: 'peer-added-to-file-only', wg_cmd_error: setRes.stderr || setRes.stdout };
        }
      }
    } catch (e) {
      // ignore
    }

    return { ok: true };
  } catch (e) {
    return { ok: false, reason: String(e) };
  }
}

const app = express();
app.use(cors());
app.use(express.json());

// serve static files (this project folder)
app.use(express.static(__dirname));
// track requests for health checks
app.use(healthChecks.trackRequests);

// Register owner - requires OWNER_CODE
app.post('/api/register-owner', (req, res) => {
  const { username, password, ownerCode } = req.body || {};
  if (!username || !password || !ownerCode) return res.status(400).json({ error: 'username,password,ownerCode required' });
  if (ownerCode !== OWNER_CODE) return res.status(403).json({ error: 'invalid owner code' });
  if (users.find(u => u.username === username)) return res.status(409).json({ error: 'user exists' });
  const hash = bcrypt.hashSync(password, 10);
  const id = uuidv4();
  const user = { id, username, passwordHash: hash, role: 'owner' };
  users.push(user); saveUsers(users);
  const token = issueToken(id, 'owner');
  res.json({ token, role: 'owner' });
});

// Login (owners and other registered users)
app.post('/api/login', (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'username,password required' });
  const user = users.find(u => u.username === username);
  if (!user) return res.status(401).json({ error: 'invalid credentials' });
  if (!bcrypt.compareSync(password, user.passwordHash)) return res.status(401).json({ error: 'invalid credentials' });
  const token = issueToken(user.id, user.role);
  res.json({ token, role: user.role });
});

// Defesa Civil login by secret code only (no persistent user created)
app.post('/api/login-defense', (req, res) => {
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error: 'code required' });
  if (code !== DEFENSE_CODE) return res.status(403).json({ error: 'invalid defense code' });
  const token = issueToken('defense-' + uuidv4(), 'defense');
  res.json({ token, role: 'defense' });
});

// whoami
app.get('/api/whoami', (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const rec = validateToken(token);
  if (!rec) return res.status(401).json({ error: 'invalid token' });
  res.json({ role: rec.role, userId: rec.userId });
});

// Device registry in-memory (persists during server runtime)
const deviceRegistry = new Map(); // deviceId -> { dilithium_pubkey, wg_pubkey, wg_ip, registered_at, owner_id }

// Device onboarding endpoint
// Expects: { deviceId, dilithium_pubkey (base64), wg_pubkey, dilithium_signature (base64 of signed payload) }
// For now, simplified: accepts registration without verification (real impl would verify signature)
app.post('/api/device-onboard', async (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const rec = validateToken(token);
  
  // only owners or defense can onboard devices
  if (!rec || (rec.role !== 'owner' && rec.role !== 'defense')) {
    return res.status(403).json({ error: 'unauthorized role' });
  }

  const { deviceId, dilithium_pubkey, wg_pubkey, dilithium_signature } = req.body || {};
  if (!deviceId || !wg_pubkey) return res.status(400).json({ error: 'deviceId and wg_pubkey required' });

  // If Dilithium fields are provided, attempt to verify signature.
  // Requirement: the device must have signed the UTF-8 bytes of the deviceId string.
  const verifyEnabled = (process.env.DILITHIUM_VERIFY || '1') !== '0';
  if (verifyEnabled && dilithium_pubkey && dilithium_signature) {
    try {
      const ok = verifyDilithiumSignature(deviceId, dilithium_pubkey, dilithium_signature);
      if (!ok) return res.status(403).json({ error: 'invalid dilithium signature' });
    } catch (e) {
      console.error('Dilithium verification error:', e);
      return res.status(500).json({ error: 'dilithium verification failed', detail: String(e) });
    }
  }

  // Assign IP to device. Prefer persisted registry count if available.
  let deviceCount = deviceRegistry.size;
  try {
    if (deviceRegistryModule && typeof deviceRegistryModule.getDeviceCount === 'function') {
      const cnt = await deviceRegistryModule.getDeviceCount();
      if (typeof cnt === 'number') deviceCount = cnt;
    }
  } catch (e) {
    console.warn('Could not get device count from persistent registry, falling back to in-memory count');
  }

  const wg_ip = `10.0.0.${2 + deviceCount}/32`; // starts at 10.0.0.2

  const record = {
    deviceId,
    dilithium_pubkey: dilithium_pubkey || null,
    wg_pubkey,
    wg_ip,
    registered_at: Date.now(),
    owner_id: rec.userId
  };

  // Store in-memory cache
  deviceRegistry.set(deviceId, record);

  // Persist to sqlite device registry if available
  try {
    if (deviceRegistryModule && typeof deviceRegistryModule.registerDevice === 'function') {
      await deviceRegistryModule.registerDevice({
        owner_id: rec.userId,
        device_id: deviceId,
        public_key: dilithium_pubkey || null,
        wireguard_key: wg_pubkey,
        dilithium_key: dilithium_pubkey || null,
        allocated_ip: wg_ip
      });
    }
  } catch (e) {
    console.warn('Persisting device to registry failed:', e && e.message);
  }

  // Attempt to add the peer to WireGuard config and (optionally) live interface
  const wgResult = addWireguardPeer(deviceId, wg_pubkey, wg_ip);
  console.log(`Device onboarded: ${deviceId} with IP ${wg_ip}`, wgResult);

  res.json({
    status: 'onboarded',
    deviceId,
    wg_ip,
    server_address: '10.0.0.1',
    server_port: 51820,
    wireguard: wgResult
  });
});

// Get WireGuard peer config for device
app.get('/api/get-wg-config/:deviceId', async (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const rec = validateToken(token);
  
  if (!rec || (rec.role !== 'owner' && rec.role !== 'defense')) {
    return res.status(403).json({ error: 'unauthorized' });
  }

  const { deviceId } = req.params;
  let device = deviceRegistry.get(deviceId);
  if (!device && deviceRegistryModule && typeof deviceRegistryModule.getDevice === 'function') {
    try {
      const persisted = await deviceRegistryModule.getDevice(deviceId);
      if (persisted) {
        device = {
          deviceId: persisted.device_id,
          dilithium_pubkey: persisted.dilithium_key || null,
          wg_pubkey: persisted.wireguard_key || null,
          wg_ip: persisted.allocated_ip || null,
          registered_at: persisted.created_at || Date.now(),
          owner_id: persisted.owner_id
        };
        // cache it
        deviceRegistry.set(deviceId, device);
      }
    } catch (e) {
      console.warn('Error fetching device from registry:', e && e.message);
    }
  }

  if (!device) return res.status(404).json({ error: 'device not found' });

  // Return WireGuard config snippet for the device
  // Device would use this to configure its wg0 interface
  const config = `# WireGuard config for ${deviceId}
[Interface]
PrivateKey = <device-private-key>
Address = ${device.wg_ip}
DNS = 8.8.8.8

[Peer]
PublicKey = <server-public-key>
AllowedIPs = 10.0.0.0/24
Endpoint = <server-ip>:51820
PersistentKeepalive = 25
`;
  res.json({
    deviceId,
    config,
    device_ip: device.wg_ip,
    server_address: '10.0.0.1'
  });
});

// Telemetry endpoint for devices via HTTP (used by Lightway VPN or direct HTTP)
// REQUIRES: Owner authentication via Bearer token
// Devices send: { deviceId, value, timestamp? }
app.post('/api/telemetry', (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const tokenRec = validateToken(token);
  if (!tokenRec || tokenRec.role !== 'owner') {
    return res.status(403).json({ error: 'only owners can submit telemetry' });
  }

  const { deviceId, value, timestamp } = req.body || {};
  if (!deviceId || value === undefined) {
    return res.status(400).json({ error: 'deviceId and value required' });
  }

  // Verify device is registered
  const device = deviceRegistry.get(deviceId);
  if (!device) {
    return res.status(404).json({ error: 'device not registered' });
  }

  // Broadcast to all WebSocket clients
  const msg = {
    deviceId,
    value: Number(value),
    timestamp: timestamp || Date.now(),
    source: 'http-telemetry'
  };
  broadcast(msg);

  console.log(`Telemetry received from ${deviceId}: ${value}`);
  res.json({ status: 'ok', received: msg });
});

// Get devices list (requires authentication: owner or defense)
app.get('/api/devices', (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const tokenRec = validateToken(token);
  if (!tokenRec || (tokenRec.role !== 'owner' && tokenRec.role !== 'defense')) {
    return res.status(403).json({ error: 'authentication required' });
  }

  const deviceList = [];
  for (let i = 1; i <= 6; i++) {
    const id = `D${i}`;
    deviceList.push({
      id,
      status: deviceStatus[i-1] || 'offline',
      lastAlert: deviceAlerts[i-1] || null,
      lastValue: chartData[i-1]?.[chartData[i-1].length - 1] || null,
    });
  }
  res.json(deviceList);
});

// Get chart data (requires authentication: owner or defense)
app.get('/api/chart/:deviceId', (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const tokenRec = validateToken(token);
  if (!tokenRec || (tokenRec.role !== 'owner' && tokenRec.role !== 'defense')) {
    return res.status(403).json({ error: 'authentication required' });
  }

  const { deviceId } = req.params;
  const devIdx = deviceIndexFromId(deviceId);
  if (devIdx < 0) return res.status(400).json({ error: 'invalid device id (D1..D6)' });
  res.json({ data: chartData[devIdx] || [], deviceId });
});

// Health check endpoint (for load balancers and monitors)
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: Date.now()
  });
});

// create http server and attach ws
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// devices list for simulator broadcast
const devices = ['D1','D2','D3','D4','D5','D6'];

function randomValueForDevice(dIndex) {
  const base = 20 + (dIndex + 1) * 5;
  const noise = (Math.random() * 10) - 5;
  const spike = Math.random() < 0.02 ? (30 + Math.random() * 100) : 0;
  return Math.max(0, base + noise + spike).toFixed(2);
}

// Broadcast wrapper
function broadcast(obj) {
  const s = JSON.stringify(obj);
  wss.clients.forEach(function each(client) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(s);
    }
  });
}

// periodic simulator only sends to clients that passed auth (we will only accept auth connections)
setInterval(() => {
  devices.forEach((dev, idx) => {
    const msg = { deviceId: dev, value: Number(randomValueForDevice(idx)) };
    broadcast(msg);
  });
}, 1000);

// handle ws connections - expect token in query ?token=...
wss.on('connection', function connection(ws, req) {
  // validate token from query
  const url = new URL(req.url, `http://${req.headers.host}`);
  const token = url.searchParams.get('token');
  const rec = validateToken(token);
  if (!rec) {
    ws.send(JSON.stringify({ error: 'unauthorized' }));
    ws.close();
    return;
  }
  ws._auth = rec; // attach auth info
  console.log('WS client connected, role=', rec.role);

  ws.on('message', function incoming(message) {
    try {
      const parsed = JSON.parse(message.toString());
      // if parsed has deviceId & value, broadcast it
      if (parsed.deviceId && parsed.value !== undefined) {
        broadcast(parsed);
      } else {
        ws.send(JSON.stringify({ echo: parsed }));
      }
    } catch (e) {
      const n = Number(message.toString());
      if (!isNaN(n)) broadcast(n);
      else ws.send(JSON.stringify({ error: 'message not understood' }));
    }
  });

  ws.on('close', () => console.log('WS client disconnected'));
});

// Start server after initializing health checks and device registry
async function startServer() {
  try {
    await healthChecks.init();

    // initialize persistent device registry (sqlite)
    try {
      await deviceRegistryModule.init();
      const persisted = await deviceRegistryModule.loadAllDevices();
      persisted.forEach(d => {
        deviceRegistry.set(d.device_id, {
          deviceId: d.device_id,
          dilithium_pubkey: d.dilithium_key || null,
          wg_pubkey: d.wireguard_key || d.wireguard_key,
          wg_ip: d.allocated_ip || d.allocated_ip,
          registered_at: d.created_at || Date.now(),
          owner_id: d.owner_id
        });
      });
    } catch (e) {
      console.warn('Device registry init failed, continuing with in-memory registry:', e && e.message);
    }

    server.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));

    console.log('To configure OWNER_CODE and DEFENSE_CODE, set environment variables before starting the server.');
    console.log('Example (PowerShell): $env:OWNER_CODE="MYOWNER"; $env:DEFENSE_CODE="MYDEFENSE"; npm start');
  } catch (e) {
    console.error('Failed to start server:', e);
    process.exit(1);
  }
}

startServer();

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down...');
  try { await deviceRegistryModule.close(); } catch (e) {}
  process.exit(0);
});
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  try { await deviceRegistryModule.close(); } catch (e) {}
  process.exit(0);
});
