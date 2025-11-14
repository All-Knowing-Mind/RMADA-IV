-- RMADA Stage 3 — SQLite Database Schema
-- Provides persistence for users, devices, telemetry

-- Users table (owner/defense roles)
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('owner', 'defense')),
    owner_code TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
);

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT UNIQUE NOT NULL,
    owner_id INTEGER NOT NULL,
    dilithium_pubkey TEXT NOT NULL,
    wg_pubkey TEXT,
    lightway_pubkey TEXT,
    wg_ip TEXT,
    lightway_ip TEXT,
    status TEXT CHECK(status IN ('active', 'inactive', 'error')) DEFAULT 'inactive',
    last_seen DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(owner_id) REFERENCES users(id)
);

-- Telemetry table (device sensor readings)
CREATE TABLE IF NOT EXISTS telemetry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    value REAL NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metadata TEXT, -- JSON for additional sensor data
    FOREIGN KEY(device_id) REFERENCES devices(device_id)
);

-- VPN Peers table (WireGuard or Lightway)
CREATE TABLE IF NOT EXISTS vpn_peers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    peer_type TEXT CHECK(peer_type IN ('wireguard', 'lightway')) DEFAULT 'wireguard',
    public_key TEXT NOT NULL,
    private_key_encrypted TEXT, -- Only for development
    assigned_ip TEXT,
    status TEXT CHECK(status IN ('active', 'inactive')) DEFAULT 'inactive',
    last_handshake DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(device_id) REFERENCES devices(device_id)
);

-- Sessions table (auth tokens)
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token TEXT UNIQUE NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

-- API Logs table (audit trail)
CREATE TABLE IF NOT EXISTS api_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    status_code INTEGER,
    error_message TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_devices_owner_id ON devices(owner_id);
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices(device_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_device_id ON telemetry(device_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_timestamp ON telemetry(timestamp);
CREATE INDEX IF NOT EXISTS idx_vpn_peers_device_id ON vpn_peers(device_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_api_logs_timestamp ON api_logs(timestamp);
