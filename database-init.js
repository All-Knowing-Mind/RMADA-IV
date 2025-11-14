/**
 * RMADA Stage 3 — Database Initialization Module
 * Handles SQLite setup, migrations, and persistence layer
 */

const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'rmada.db');
const SCHEMA_PATH = path.join(__dirname, 'database-schema.sql');

let db = null;

/**
 * Initialize database connection
 */
function initDatabase() {
  return new Promise((resolve, reject) => {
    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) {
        console.error('❌ Failed to open database:', err.message);
        reject(err);
      } else {
        console.log(`✅ Database opened: ${DB_PATH}`);
        
        // Enable foreign keys
        db.run('PRAGMA foreign_keys = ON', (err) => {
          if (err) reject(err);
          else {
            // Load schema
            loadSchema()
              .then(resolve)
              .catch(reject);
          }
        });
      }
    });
  });
}

/**
 * Load database schema from SQL file
 */
function loadSchema() {
  return new Promise((resolve, reject) => {
    const schema = fs.readFileSync(SCHEMA_PATH, 'utf8');
    
    db.exec(schema, (err) => {
      if (err) {
        console.error('❌ Failed to load schema:', err.message);
        reject(err);
      } else {
        console.log('✅ Database schema loaded');
        resolve();
      }
    });
  });
}

/**
 * Get database connection
 */
function getDatabase() {
  return db;
}

/**
 * Run query (prepared statement)
 */
function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    if (!db) {
      reject(new Error('Database not initialized'));
      return;
    }
    
    db.run(sql, params, function(err) {
      if (err) {
        console.error('❌ Query error:', sql, err);
        reject(err);
      } else {
        resolve({ id: this.lastID, changes: this.changes });
      }
    });
  });
}

/**
 * Get single row
 */
function get(sql, params = []) {
  return new Promise((resolve, reject) => {
    if (!db) {
      reject(new Error('Database not initialized'));
      return;
    }
    
    db.get(sql, params, (err, row) => {
      if (err) {
        console.error('❌ Query error:', sql, err);
        reject(err);
      } else {
        resolve(row);
      }
    });
  });
}

/**
 * Get all rows
 */
function all(sql, params = []) {
  return new Promise((resolve, reject) => {
    if (!db) {
      reject(new Error('Database not initialized'));
      return;
    }
    
    db.all(sql, params, (err, rows) => {
      if (err) {
        console.error('❌ Query error:', sql, err);
        reject(err);
      } else {
        resolve(rows || []);
      }
    });
  });
}

/**
 * Create user (hashed password)
 */
async function createUser(username, passwordHash, role, ownerCode) {
  return run(
    `INSERT INTO users (username, password_hash, role, owner_code)
     VALUES (?, ?, ?, ?)`,
    [username, passwordHash, role, ownerCode]
  );
}

/**
 * Get user by username
 */
async function getUserByUsername(username) {
  return get(
    `SELECT id, username, password_hash, role, created_at FROM users
     WHERE username = ?`,
    [username]
  );
}

/**
 * Get user by ID
 */
async function getUserById(userId) {
  return get(
    `SELECT id, username, role, created_at FROM users WHERE id = ?`,
    [userId]
  );
}

/**
 * Create or update device
 */
async function registerDevice(deviceId, ownerId, dilithiumPubkey, wgPubkey) {
  const existing = await get(
    `SELECT id FROM devices WHERE device_id = ?`,
    [deviceId]
  );
  
  if (existing) {
    // Update
    return run(
      `UPDATE devices 
       SET dilithium_pubkey = ?, wg_pubkey = ?, status = 'active', last_seen = CURRENT_TIMESTAMP
       WHERE device_id = ?`,
      [dilithiumPubkey, wgPubkey, deviceId]
    );
  } else {
    // Create
    return run(
      `INSERT INTO devices (device_id, owner_id, dilithium_pubkey, wg_pubkey, status)
       VALUES (?, ?, ?, ?, 'active')`,
      [deviceId, ownerId, dilithiumPubkey, wgPubkey]
    );
  }
}

/**
 * Get device by ID
 */
async function getDevice(deviceId) {
  return get(
    `SELECT id, device_id, owner_id, dilithium_pubkey, wg_pubkey, status
     FROM devices WHERE device_id = ?`,
    [deviceId]
  );
}

/**
 * Get all devices for owner
 */
async function getDevicesByOwner(ownerId) {
  return all(
    `SELECT id, device_id, status, last_seen, created_at
     FROM devices WHERE owner_id = ? ORDER BY created_at DESC`,
    [ownerId]
  );
}

/**
 * Store telemetry reading
 */
async function storeTelemetry(deviceId, value, metadata = null) {
  return run(
    `INSERT INTO telemetry (device_id, value, metadata)
     VALUES (?, ?, ?)`,
    [deviceId, value, metadata ? JSON.stringify(metadata) : null]
  );
}

/**
 * Get recent telemetry for device
 */
async function getTelemetry(deviceId, limit = 100) {
  return all(
    `SELECT id, device_id, value, timestamp, metadata
     FROM telemetry WHERE device_id = ?
     ORDER BY timestamp DESC LIMIT ?`,
    [deviceId, limit]
  );
}

/**
 * Get telemetry stats (average, min, max, count)
 */
async function getTelemetryStats(deviceId, hours = 24) {
  return get(
    `SELECT 
       COUNT(*) as count,
       AVG(value) as average,
       MIN(value) as minimum,
       MAX(value) as maximum
     FROM telemetry
     WHERE device_id = ? AND timestamp > datetime('now', '-' || ? || ' hours')`,
    [deviceId, hours]
  );
}

/**
 * Create session (auth token)
 */
async function createSession(userId, token, expiresAt) {
  return run(
    `INSERT INTO sessions (user_id, token, expires_at)
     VALUES (?, ?, ?)`,
    [userId, token, expiresAt]
  );
}

/**
 * Get session by token
 */
async function getSession(token) {
  return get(
    `SELECT id, user_id, expires_at FROM sessions
     WHERE token = ? AND expires_at > CURRENT_TIMESTAMP`,
    [token]
  );
}

/**
 * Delete expired sessions
 */
async function cleanupSessions() {
  return run(
    `DELETE FROM sessions WHERE expires_at < CURRENT_TIMESTAMP`
  );
}

/**
 * Log API call
 */
async function logAPI(userId, endpoint, method, statusCode, errorMessage = null) {
  return run(
    `INSERT INTO api_logs (user_id, endpoint, method, status_code, error_message)
     VALUES (?, ?, ?, ?, ?)`,
    [userId || null, endpoint, method, statusCode, errorMessage]
  );
}

/**
 * Close database connection
 */
function closeDatabase() {
  return new Promise((resolve, reject) => {
    if (db) {
      db.close((err) => {
        if (err) reject(err);
        else {
          console.log('✅ Database closed');
          resolve();
        }
      });
    } else {
      resolve();
    }
  });
}

/**
 * Backup database
 */
function backupDatabase() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = `${DB_PATH}.backup.${timestamp}`;
  
  try {
    fs.copyFileSync(DB_PATH, backupPath);
    console.log(`✅ Database backup created: ${backupPath}`);
    return backupPath;
  } catch (err) {
    console.error('❌ Failed to backup database:', err.message);
    throw err;
  }
}

module.exports = {
  initDatabase,
  getDatabase,
  run,
  get,
  all,
  createUser,
  getUserByUsername,
  getUserById,
  registerDevice,
  getDevice,
  getDevicesByOwner,
  storeTelemetry,
  getTelemetry,
  getTelemetryStats,
  createSession,
  getSession,
  cleanupSessions,
  logAPI,
  closeDatabase,
  backupDatabase,
};
