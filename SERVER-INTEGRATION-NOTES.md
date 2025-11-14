# Server.js Integration Guide - Phase 4 Final Polish

## Overview

The `server.js` file needs to be updated to use the new Phase 4 modules:

1. **device-registry-init.js** — SQLite device persistence
2. **health-checks.js** — System health monitoring

## Step 1: Add Module Imports

At the top of `server.js`, after existing requires, add:

```javascript
// Import new Phase 4 modules
const deviceRegistryModule = require('./device-registry-init');
const healthChecks = require('./health-checks');
```

## Step 2: Replace In-Memory Device Registry

**OLD (Line ~211):**
```javascript
// Device registry in-memory (persists during server runtime)
const deviceRegistry = new Map(); // deviceId -> { dilithium_pubkey, wg_pubkey, wg_ip, registered_at, owner_id }
```

**NEW:**
```javascript
// Device registry now uses SQLite (persistent across server restarts)
// Initialized on server startup with loadAllDevices()
let deviceRegistry = null;
```

## Step 3: Update Device Onboarding Endpoint

**Replace the POST `/api/device-onboard` endpoint (lines ~215-257) with:**

```javascript
// Device onboarding endpoint
// Now persists to SQLite via device-registry-init.js
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

  // If Dilithium fields are provided, attempt to verify signature
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

  try {
    // Get device count from SQLite registry
    const deviceCount = await deviceRegistryModule.getDeviceCount();
    const wg_ip = `10.0.0.${2 + deviceCount}/32`; // starts at 10.0.0.2

    // Persist to SQLite
    const deviceData = {
      device_id: deviceId,
      owner_id: rec.userId,
      device_type: 'sensor',
      device_name: deviceId,
      public_key: dilithium_pubkey || wg_pubkey,
      ip_address: wg_ip,
      wg_public_key: wg_pubkey,
      status: 'active',
    };

    await deviceRegistryModule.registerDevice(deviceData);

    // Attempt to add the peer to WireGuard config
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
  } catch (e) {
    console.error('Error onboarding device:', e);
    res.status(500).json({ error: 'failed to onboard device', detail: String(e) });
  }
});
```

## Step 4: Update Get WireGuard Config Endpoint

**Replace the GET `/api/get-wg-config/:deviceId` endpoint (lines ~259-290) with:**

```javascript
// Get WireGuard peer config for device
app.get('/api/get-wg-config/:deviceId', async (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  const rec = validateToken(token);
  
  if (!rec || (rec.role !== 'owner' && rec.role !== 'defense')) {
    return res.status(403).json({ error: 'unauthorized' });
  }

  try {
    const { deviceId } = req.params;
    const device = await deviceRegistryModule.getDevice(deviceId);
    if (!device) return res.status(404).json({ error: 'device not found' });

    // Return WireGuard config snippet for the device
    const config = `# WireGuard config for ${deviceId}
[Interface]
PrivateKey = <device-private-key>
Address = ${device.ip_address}
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
      device_ip: device.ip_address,
      server_address: '10.0.0.1'
    });
  } catch (e) {
    res.status(500).json({ error: 'failed to get config', detail: String(e) });
  }
});
```

## Step 5: Update Telemetry Endpoint

**Replace the POST `/api/telemetry` endpoint (lines ~292-314) with:**

```javascript
// Telemetry endpoint for devices via HTTP
app.post('/api/telemetry', async (req, res) => {
  const { deviceId, value, timestamp } = req.body || {};
  if (!deviceId || value === undefined) {
    return res.status(400).json({ error: 'deviceId and value required' });
  }

  try {
    // Verify device is registered (and update last_seen)
    const device = await deviceRegistryModule.getDevice(deviceId);
    if (!device) {
      return res.status(404).json({ error: 'device not registered' });
    }

    // Update last seen timestamp in registry
    await deviceRegistryModule.updateLastSeen(deviceId);

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
  } catch (e) {
    console.error('Telemetry error:', e);
    res.status(500).json({ error: 'telemetry failed', detail: String(e) });
  }
});
```

## Step 6: Add Health Check Endpoint

**Replace the GET `/health` endpoint (lines ~316-320) with:**

```javascript
// Health check endpoints
app.get('/api/health', (req, res) => {
  const status = healthChecks.getStatus();
  const statusCode = status.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(status);
});

// Kubernetes liveness probe
app.get('/api/livez', (req, res) => {
  healthChecks.livenessProbe(req, res);
});

// Kubernetes readiness probe
app.get('/api/readyz', (req, res) => {
  healthChecks.readinessProbe(req, res);
});

// Legacy health endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: Date.now()
  });
});
```

## Step 7: Add Health Check Tracking Middleware

**Before the telemetry endpoint (around line ~315), add:**

```javascript
// Track request statistics for health checks
app.use(healthChecks.trackRequests);
```

## Step 8: Server Initialization

**Replace the server startup section (lines ~335-355) with:**

```javascript
// Create HTTP/HTTPS servers
const httpApp = express();
httpApp.use(cors());
httpApp.use(express.json());
httpApp.use(express.static(__dirname));
httpApp.use(app);

const httpServer = http.createServer(httpApp);

// Initialize HTTPS if certificates exist
let httpsServer = null;
const CERT_PATH = process.env.CERT_PATH || path.join(__dirname, 'certificates/server.crt');
const KEY_PATH = process.env.KEY_PATH || path.join(__dirname, 'certificates/server.key');

if (fs.existsSync(CERT_PATH) && fs.existsSync(KEY_PATH)) {
  try {
    const cert = fs.readFileSync(CERT_PATH);
    const key = fs.readFileSync(KEY_PATH);
    httpsServer = https.createServer({ cert, key }, app);
    const HTTPS_PORT = process.env.HTTPS_PORT || 8443;
    httpsServer.listen(HTTPS_PORT, () => {
      console.log(`HTTPS server running on https://localhost:${HTTPS_PORT}`);
    });
  } catch (e) {
    console.warn('Failed to start HTTPS server:', e.message);
  }
}

// WebSocket on HTTP
const wss = new WebSocket.Server({ server: httpServer });

// Devices list for simulator broadcast
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

// Periodic simulator
setInterval(() => {
  devices.forEach((dev, idx) => {
    const msg = { deviceId: dev, value: Number(randomValueForDevice(idx)) };
    broadcast(msg);
  });
}, 1000);

// Handle WS connections
wss.on('connection', function connection(ws, req) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const token = url.searchParams.get('token');
  const rec = validateToken(token);
  if (!rec) {
    ws.send(JSON.stringify({ error: 'unauthorized' }));
    ws.close();
    return;
  }
  ws._auth = rec;
  console.log('WS client connected, role=', rec.role);

  ws.on('message', function incoming(message) {
    try {
      const parsed = JSON.parse(message.toString());
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

// Server startup with device registry initialization
const PORT = process.env.PORT || 8080;

async function startServer() {
  try {
    // Initialize device registry (loads from SQLite)
    await deviceRegistryModule.init();
    await deviceRegistryModule.loadAllDevices();
    console.log('✓ Device registry initialized and loaded from SQLite');

    // Start HTTP server
    httpServer.listen(PORT, () => {
      console.log(`✓ HTTP server running on http://localhost:${PORT}`);
      console.log(`✓ WebSocket endpoint: ws://localhost:${PORT}`);
    });
  } catch (e) {
    console.error('✗ Failed to start server:', e.message);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n✓ Shutting down gracefully...');
  try {
    await deviceRegistryModule.close();
    httpServer.close(() => console.log('✓ Server closed'));
    if (httpsServer) httpsServer.close();
  } catch (e) {
    console.error('Error during shutdown:', e);
  }
  process.exit(0);
});

startServer();

console.log('📝 To configure OWNER_CODE and DEFENSE_CODE, set environment variables:');
console.log('   Example (PowerShell): $env:OWNER_CODE="MYOWNER"; $env:DEFENSE_CODE="MYDEFENSE"; npm start');
```

## Summary of Changes

| Component | Change | Benefit |
|-----------|--------|---------|
| Device Registry | In-memory Map → SQLite via `device-registry-init.js` | Devices persist across server restarts |
| Onboarding | Synchronous → Async with await | Properly handles database operations |
| Health Checks | Basic `/health` → Comprehensive via `health-checks.js` | Memory, CPU, disk, services monitoring |
| Telemetry | No registry update → Calls `updateLastSeen()` | Track device activity |
| HTTPS | Not configured → Auto-detected from certificates | Support secure connections |
| Shutdown | Abrupt → Graceful with database cleanup | Prevent data loss |

## Testing Integration

1. **Start the server:**
   ```bash
   npm start
   ```

2. **Check device persistence:**
   ```bash
   curl -k https://localhost:8443/api/health
   ```

3. **Register a device, restart server, verify it's still there:**
   ```bash
   # Register device
   curl -X POST https://localhost:8443/api/device-onboard \
     -H "Authorization: Bearer TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"deviceId":"TEST-1","wg_pubkey":"abc123"}'
   
   # Restart server
   # Re-query - device should still be in registry
   ```

4. **Check health status:**
   ```bash
   curl -k https://localhost:8443/api/health | jq
   ```

5. **Run test suite:**
   ```bash
   bash test-rmada.sh
   ```

## Next Steps

1. ✅ Review the changes and make sure they make sense
2. ✅ Apply the changes to `server.js` (use the snippets above)
3. ✅ Run `npm install` to ensure all dependencies are installed
4. ✅ Start the server with `npm start`
5. ✅ Run tests with `bash test-rmada.sh` or `node test-suite.js`
6. ✅ Verify device persistence across restart
7. ✅ Check `/api/health` endpoint
8. ✅ Mark Stage 3 Phase 4 as 100% complete! 🎉
