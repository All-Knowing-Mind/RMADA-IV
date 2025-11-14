# RMADA Stage 3 — Database Reference

## Overview

This guide documents the SQLite database schema, operations, and best practices.

---

## Database Schema

### Tables (8 Total)

#### 1. `users`

Stores owner and defense team accounts.

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('owner', 'defense')) DEFAULT 'defense',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login DATETIME,
  is_active BOOLEAN DEFAULT 1
);

CREATE INDEX idx_username ON users(username);
```

**Columns:**
- `id` — Unique user ID
- `username` — Login name (unique)
- `email` — Contact email (unique)
- `password_hash` — bcryptjs hash
- `role` — 'owner' or 'defense'
- `created_at` — Registration timestamp
- `last_login` — Last login time
- `is_active` — Account active flag

**Example:**
```json
{
  "id": 1,
  "username": "admin",
  "email": "admin@rmada.local",
  "role": "owner",
  "created_at": "2024-01-15 10:00:00",
  "is_active": 1
}
```

#### 2. `devices`

Registered IoT devices (LoRa, sensors, gateways).

```sql
CREATE TABLE devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,
  device_id TEXT UNIQUE NOT NULL,
  device_type TEXT DEFAULT 'LoRa',
  description TEXT,
  public_key TEXT NOT NULL,
  wireguard_key TEXT,
  lightway_key TEXT,
  dilithium_key TEXT,
  is_active BOOLEAN DEFAULT 1,
  last_seen DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(owner_id) REFERENCES users(id)
);

CREATE INDEX idx_device_id ON devices(device_id);
CREATE INDEX idx_owner_id ON devices(owner_id);
```

**Columns:**
- `id` — Unique device ID
- `owner_id` — Owner user ID (FK)
- `device_id` — Device identifier (unique)
- `device_type` — 'LoRa', 'sensor', 'gateway', etc.
- `public_key` — Device's public key
- `wireguard_key` — WireGuard public key (if VPN)
- `lightway_key` — Lightway public key (if VPN)
- `dilithium_key` — Dilithium public key (post-quantum)
- `is_active` — Active flag
- `last_seen` — Last communication timestamp

**Example:**
```json
{
  "id": 1,
  "owner_id": 1,
  "device_id": "lora-greenhouse-01",
  "device_type": "LoRa",
  "description": "Temperature and humidity sensor",
  "is_active": 1,
  "last_seen": "2024-01-15 14:32:00",
  "created_at": "2024-01-15 09:00:00"
}
```

#### 3. `telemetry`

Time-series sensor readings.

```sql
CREATE TABLE telemetry (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT DEFAULT '',
  metadata JSON,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(device_id) REFERENCES devices(device_id)
);

CREATE INDEX idx_device_timestamp ON telemetry(device_id, timestamp DESC);
CREATE INDEX idx_timestamp ON telemetry(timestamp DESC);
```

**Columns:**
- `id` — Record ID
- `device_id` — Source device
- `value` — Sensor reading (temperature, humidity, etc.)
- `unit` — Unit of measurement ('°C', '%RH', 'ppm', etc.)
- `metadata` — JSON with additional data (location, quality, etc.)
- `timestamp` — Reading time

**Example:**
```json
{
  "id": 1000,
  "device_id": "lora-greenhouse-01",
  "value": 24.5,
  "unit": "°C",
  "metadata": {"quality": "good", "location": "zone-a"},
  "timestamp": "2024-01-15 14:30:00"
}
```

#### 4. `vpn_peers`

VPN client configurations (WireGuard/Lightway).

```sql
CREATE TABLE vpn_peers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_name TEXT UNIQUE NOT NULL,
  peer_type TEXT CHECK(peer_type IN ('wireguard', 'lightway')) DEFAULT 'wireguard',
  public_key TEXT NOT NULL,
  allocated_ip TEXT,
  endpoint TEXT,
  is_active BOOLEAN DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_connected DATETIME
);

CREATE INDEX idx_peer_name ON vpn_peers(peer_name);
```

**Columns:**
- `id` — Peer ID
- `peer_name` — Unique client name (e.g., 'iphone', 'ubuntu-gateway')
- `peer_type` — 'wireguard' or 'lightway'
- `public_key` — Client's public key
- `allocated_ip` — Assigned VPN IP (e.g., 10.1.0.10)
- `endpoint` — Client endpoint (optional)
- `is_active` — Active flag
- `created_at` — Registration time
- `last_connected` — Last connection time

**Example:**
```json
{
  "id": 1,
  "peer_name": "iphone-alice",
  "peer_type": "wireguard",
  "allocated_ip": "10.1.0.10",
  "is_active": 1,
  "created_at": "2024-01-10 12:00:00",
  "last_connected": "2024-01-15 08:30:00"
}
```

#### 5. `sessions`

User authentication sessions and JWT tokens.

```sql
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  token TEXT UNIQUE NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE INDEX idx_user_id ON sessions(user_id);
CREATE INDEX idx_token ON sessions(token);
CREATE INDEX idx_expires_at ON sessions(expires_at);
```

**Columns:**
- `id` — Session ID
- `user_id` — Associated user ID
- `token` — JWT token
- `ip_address` — Client IP address
- `user_agent` — Browser/client info
- `expires_at` — Session expiration time
- `created_at` — Session creation time

**Example:**
```json
{
  "id": 1,
  "user_id": 1,
  "token": "eyJhbGc...",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "expires_at": "2024-01-16 10:00:00",
  "created_at": "2024-01-15 10:00:00"
}
```

#### 6. `api_logs`

Audit trail of API requests.

```sql
CREATE TABLE api_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  method TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  status_code INTEGER,
  response_time_ms INTEGER,
  error_message TEXT,
  request_data JSON,
  ip_address TEXT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE INDEX idx_user_id ON api_logs(user_id);
CREATE INDEX idx_timestamp ON api_logs(timestamp DESC);
CREATE INDEX idx_endpoint ON api_logs(endpoint);
```

**Columns:**
- `id` — Log entry ID
- `user_id` — Requesting user (nullable for anonymous)
- `method` — HTTP method (GET, POST, etc.)
- `endpoint` — API endpoint path
- `status_code` — HTTP response code
- `response_time_ms` — Execution time in milliseconds
- `error_message` — Error details (if failed)
- `request_data` — JSON of request parameters
- `ip_address` — Client IP
- `timestamp` — Request timestamp

**Example:**
```json
{
  "id": 100,
  "user_id": 1,
  "method": "POST",
  "endpoint": "/api/telemetry",
  "status_code": 201,
  "response_time_ms": 45,
  "ip_address": "10.1.0.5",
  "timestamp": "2024-01-15 14:30:00"
}
```

---

## Database Operations

### Connection Management

#### Initialize Database

```javascript
const db = require('./database-init');

// Initialize (creates tables if needed)
await db.initDatabase();

// Get database connection
const database = db.getDatabase();

// Close connection
await db.closeDatabase();
```

### User Operations

#### Create User

```javascript
await db.createUser({
  username: 'alice',
  email: 'alice@rmada.local',
  password: 'SecurePass123',
  role: 'owner'
});

// Returns: { id, username, email, role, created_at }
```

#### Get User

```javascript
// By username
const user = await db.getUserByUsername('alice');

// By ID
const user = await db.getUserById(1);

// Returns: { id, username, email, role, created_at, last_login, is_active }
```

#### Update User

```javascript
await db.run(
  'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?',
  [user_id]
);
```

#### List All Users

```javascript
const users = await db.all(
  'SELECT id, username, email, role, created_at FROM users WHERE is_active = 1'
);

// Returns: [{ id, username, email, role, created_at }, ...]
```

### Device Operations

#### Register Device

```javascript
await db.registerDevice({
  owner_id: 1,
  device_id: 'lora-001',
  device_type: 'LoRa',
  description: 'Main gateway',
  public_key: 'key_content_here',
  wireguard_key: 'wg_key_here',
  dilithium_key: 'dilithium_key_here'
});

// Returns: { id, device_id, owner_id, created_at }
```

#### Get Device

```javascript
const device = await db.getDevice('lora-001');

// Returns: { id, device_id, owner_id, device_type, public_key, last_seen, is_active, created_at }
```

#### Get Devices by Owner

```javascript
const devices = await db.getDevicesByOwner(owner_id);

// Returns: [{ id, device_id, device_type, is_active, last_seen }, ...]
```

#### Update Device Status

```javascript
await db.run(
  'UPDATE devices SET last_seen = CURRENT_TIMESTAMP, is_active = 1 WHERE device_id = ?',
  ['lora-001']
);
```

#### List All Devices

```javascript
const devices = await db.all(
  'SELECT * FROM devices WHERE is_active = 1 ORDER BY created_at DESC'
);
```

### Telemetry Operations

#### Store Telemetry

```javascript
await db.storeTelemetry({
  device_id: 'lora-001',
  value: 24.5,
  unit: '°C',
  metadata: {
    location: 'greenhouse',
    quality: 'good',
    rssi: -95
  }
});

// Returns: { id, timestamp }
```

#### Get Telemetry (Latest)

```javascript
const readings = await db.getTelemetry('lora-001', {
  limit: 100,           // Last 100 readings
  offset: 0,            // Skip 0
  unit: '°C'            // Filter by unit (optional)
});

// Returns: [{ id, value, unit, timestamp, metadata }, ...]
```

#### Get Telemetry (Time Range)

```javascript
const start = '2024-01-15 00:00:00';
const end = '2024-01-15 23:59:59';

const readings = await db.all(
  `SELECT * FROM telemetry 
   WHERE device_id = ? AND timestamp BETWEEN ? AND ?
   ORDER BY timestamp DESC`,
  ['lora-001', start, end]
);
```

#### Get Statistics

```javascript
const stats = await db.getTelemetryStats('lora-001');

// Returns: {
//   count: 5230,
//   min: 15.2,
//   max: 28.9,
//   avg: 22.1,
//   latest: 24.5,
//   latestTime: '2024-01-15 14:30:00'
// }
```

#### Cleanup Old Telemetry (Archival)

```javascript
// Delete readings older than 90 days
await db.run(
  `DELETE FROM telemetry 
   WHERE timestamp < datetime('now', '-90 days')`
);

// Or archive to backup table
await db.run(
  `INSERT INTO telemetry_archive 
   SELECT * FROM telemetry 
   WHERE timestamp < datetime('now', '-90 days')`
);
```

### Session Operations

#### Create Session

```javascript
const session = await db.createSession({
  user_id: 1,
  ip_address: '192.168.1.100',
  user_agent: 'Mozilla/5.0...'
});

// Returns: {
//   id,
//   token: 'eyJhbGc...',
//   expires_at: '2024-01-16 10:00:00'
// }
```

#### Get Session

```javascript
const session = await db.getSession('eyJhbGc...');

// Returns: {
//   id,
//   user_id,
//   token,
//   ip_address,
//   expires_at,
//   created_at
// }
```

#### Cleanup Expired Sessions

```javascript
await db.cleanupSessions();

// Deletes all sessions where expires_at < now
// Returns: { deleted: 23 }
```

### VPN Peer Operations

#### Register VPN Peer

```javascript
await db.run(
  `INSERT INTO vpn_peers (peer_name, peer_type, public_key, allocated_ip)
   VALUES (?, ?, ?, ?)`,
  ['iphone-alice', 'wireguard', 'key_content', '10.1.0.10']
);
```

#### Get VPN Peers

```javascript
const peers = await db.all(
  `SELECT * FROM vpn_peers WHERE is_active = 1 ORDER BY last_connected DESC`
);

// Returns: [{ peer_name, peer_type, allocated_ip, last_connected }, ...]
```

#### Update Last Connected

```javascript
await db.run(
  `UPDATE vpn_peers SET last_connected = CURRENT_TIMESTAMP WHERE peer_name = ?`,
  ['iphone-alice']
);
```

### API Logging

#### Log API Request

```javascript
await db.logAPI({
  user_id: 1,
  method: 'POST',
  endpoint: '/api/telemetry',
  status_code: 201,
  response_time_ms: 45,
  ip_address: '10.1.0.5'
});
```

#### Query API Logs

```javascript
// Recent errors
const errors = await db.all(
  `SELECT * FROM api_logs 
   WHERE status_code >= 400 
   ORDER BY timestamp DESC 
   LIMIT 50`
);

// Slow requests
const slow = await db.all(
  `SELECT * FROM api_logs 
   WHERE response_time_ms > 1000 
   ORDER BY response_time_ms DESC`
);

// User activity
const activity = await db.all(
  `SELECT * FROM api_logs 
   WHERE user_id = ? 
   ORDER BY timestamp DESC`,
  [user_id]
);
```

### Backup & Restore

#### Backup Database

```javascript
const backupPath = await db.backupDatabase();
// Creates: ./backups/rmada-YYYY-MM-DD-HHmmss.db
// Returns: backupPath
```

#### Restore from Backup

```bash
# Manual restore
cp ./backups/rmada-2024-01-15-143000.db ./rmada.db
npm start
```

#### Export to CSV

```javascript
const { Parser } = require('json2csv');

// Export telemetry
const telemetry = await db.all(
  `SELECT * FROM telemetry WHERE device_id = ? ORDER BY timestamp DESC`,
  ['lora-001']
);

const csv = new Parser().parse(telemetry);
fs.writeFileSync('telemetry-export.csv', csv);
```

---

## Transactions

### Multi-Step Operations

```javascript
// Wrap multiple operations in transaction
await db.run('BEGIN TRANSACTION');

try {
  // Create user
  await db.createUser({ username: 'bob', ... });
  
  // Register device
  await db.registerDevice({ owner_id: 2, ... });
  
  // Store initial reading
  await db.storeTelemetry({ device_id: 'dev-1', value: 25 });
  
  // Commit if all succeed
  await db.run('COMMIT');
} catch (error) {
  // Rollback on error
  await db.run('ROLLBACK');
  throw error;
}
```

---

## Performance Optimization

### Query Optimization

```javascript
// ❌ Slow: N+1 queries
const users = await db.all('SELECT * FROM users');
for (const user of users) {
  const devices = await db.all('SELECT * FROM devices WHERE owner_id = ?', [user.id]);
}

// ✅ Fast: Single JOIN query
const results = await db.all(
  `SELECT u.*, COUNT(d.id) as device_count
   FROM users u
   LEFT JOIN devices d ON u.id = d.owner_id
   GROUP BY u.id`
);
```

### Caching

```javascript
// Simple in-memory cache
const cache = {};

async function getCachedDevice(deviceId) {
  if (cache[deviceId] && cache[deviceId].expires > Date.now()) {
    return cache[deviceId].data;
  }
  
  const device = await db.getDevice(deviceId);
  cache[deviceId] = {
    data: device,
    expires: Date.now() + 60000  // 1 minute
  };
  
  return device;
}
```

### Batch Operations

```javascript
// Insert multiple readings efficiently
const db_instance = db.getDatabase();

await db_instance.serialize(() => {
  const stmt = db_instance.prepare(
    'INSERT INTO telemetry (device_id, value, unit) VALUES (?, ?, ?)'
  );
  
  for (const reading of readings) {
    stmt.run(reading.device_id, reading.value, reading.unit);
  }
  
  stmt.finalize();
});
```

### Indexing Strategy

```sql
-- Most frequently queried
CREATE INDEX idx_device_timestamp ON telemetry(device_id, timestamp DESC);
CREATE INDEX idx_user_id ON sessions(user_id);

-- Filtering operations
CREATE INDEX idx_is_active_devices ON devices(owner_id, is_active);

-- Sorting operations
CREATE INDEX idx_timestamp_desc ON telemetry(timestamp DESC);

-- Foreign keys (auto-indexed in most cases)
-- But explicit can help
CREATE INDEX idx_owner_id ON devices(owner_id);
```

---

## Maintenance

### Database Integrity

```bash
# Check integrity
sqlite3 rmada.db "PRAGMA integrity_check;"

# Optimize (VACUUM)
sqlite3 rmada.db "VACUUM;"

# Analyze table statistics
sqlite3 rmada.db "ANALYZE;"
```

### Monitoring Queries

```javascript
// Get database stats
const stats = await Promise.all([
  db.get('SELECT COUNT(*) as count FROM users'),
  db.get('SELECT COUNT(*) as count FROM devices'),
  db.get('SELECT COUNT(*) as count FROM telemetry'),
  db.get('SELECT COUNT(*) as count FROM sessions WHERE expires_at > datetime("now")')
]);

console.log({
  users: stats[0].count,
  devices: stats[1].count,
  telemetry: stats[2].count,
  activeSessions: stats[3].count
});
```

### Regular Maintenance

```bash
# Daily: Cleanup expired sessions
node -e "require('./database-init').cleanupSessions();"

# Weekly: Vacuum and analyze
sqlite3 rmada.db "VACUUM; ANALYZE;"

# Monthly: Backup
node -e "require('./database-init').backupDatabase();"

# Quarterly: Archive old telemetry
sqlite3 rmada.db "DELETE FROM telemetry WHERE timestamp < datetime('now', '-90 days');"
```

---

## Encryption (SQLCipher)

### Enable Database Encryption

```bash
# Install SQLCipher
sudo apt-get install sqlcipher

# Encrypt existing database
sqlite3 rmada.db "PRAGMA cipher='aes-256-cbc'; PRAGMA key='MySecretPassphrase'; VACUUM;"

# Or create encrypted from start
sqlcipher rmada.db
sqlite> PRAGMA key = 'MySecretPassphrase';
sqlite> .dump | sqlite3 rmada-encrypted.db
```

### Use in Node.js

```javascript
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('rmada.db', (err) => {
  if (err) console.error(err);
  
  // For SQLCipher support, use sql.js or upgrade to better-sqlite3
  db.run("PRAGMA key = 'MySecretPassphrase'");
});
```

---

## Troubleshooting

### "Database is locked"

```javascript
// Increase timeout
db.configure('busyTimeout', 5000);

// Or retry logic
async function queryWithRetry(sql, params, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await db.get(sql, params);
    } catch (err) {
      if (err.message.includes('locked') && i < maxRetries - 1) {
        await new Promise(resolve => setTimeout(resolve, 100 * (i + 1)));
      } else {
        throw err;
      }
    }
  }
}
```

### "Corrupted database"

```bash
# Recovery
sqlite3 rmada.db ".recover" > recovery.sql
sqlite3 rmada_recovered.db < recovery.sql

# Or use backup
cp rmada.db.bak rmada.db
```

### Slow Queries

```javascript
// Enable query logging
db.configure('busyTimeout', 5000);

// Log slow queries
const start = Date.now();
const result = await db.get(sql, params);
const elapsed = Date.now() - start;

if (elapsed > 100) {
  console.warn(`Slow query (${elapsed}ms): ${sql}`);
}
```

---

## Reference

- **SQLite Docs**: https://www.sqlite.org/docs.html
- **SQLCipher**: https://www.zetetic.net/sqlcipher/
- **Better-SQLite3**: https://github.com/WiseLibs/better-sqlite3
- **Database Design**: https://en.wikipedia.org/wiki/Database_design

---

**Status**: Database schema complete, operations documented  
**Version**: SQLite 3.x  
**Size**: Expected < 500MB for 1 year of telemetry (1M readings/month)
