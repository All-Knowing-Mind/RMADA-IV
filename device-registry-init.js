/**
 * Device Registry Module - SQLite Persistence
 * 
 * Manages device registration with SQLite persistence
 * Devices survive server restarts
 * 
 * Usage:
 *   const deviceRegistry = require('./device-registry');
 *   await deviceRegistry.init();
 *   await deviceRegistry.registerDevice({device_id, owner_id, ...});
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// Database path
const DB_PATH = process.env.DEVICE_REGISTRY_DB || './rmada.db';

let db = null;

/**
 * Initialize device registry
 * Creates table if needed
 */
async function init() {
  return new Promise((resolve, reject) => {
    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) {
        console.error('Device Registry Error:', err);
        reject(err);
        return;
      }
      
      console.log('✓ Device Registry connected to', DB_PATH);
      
      // Create table if needed
      db.run(`
        CREATE TABLE IF NOT EXISTS devices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner_id INTEGER DEFAULT 1,
          device_id TEXT UNIQUE NOT NULL,
          device_type TEXT DEFAULT 'LoRa',
          description TEXT DEFAULT '',
          public_key TEXT NOT NULL,
          wireguard_key TEXT,
          lightway_key TEXT,
          dilithium_key TEXT,
          allocated_ip TEXT,
          is_active BOOLEAN DEFAULT 1,
          last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `, (err) => {
        if (err) {
          console.error('Create table error:', err);
          reject(err);
        } else {
          console.log('✓ Device registry table ready');
          resolve();
        }
      });
    });
  });
}

/**
 * Register a new device
 */
async function registerDevice(deviceData) {
  return new Promise((resolve, reject) => {
    const {
      owner_id = 1,
      device_id,
      device_type = 'LoRa',
      description = '',
      public_key,
      wireguard_key = null,
      lightway_key = null,
      dilithium_key = null,
      allocated_ip = null
    } = deviceData;

    db.run(`
      INSERT INTO devices (
        owner_id, device_id, device_type, description,
        public_key, wireguard_key, lightway_key, dilithium_key,
        allocated_ip, is_active
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    `, [
      owner_id, device_id, device_type, description,
      public_key, wireguard_key, lightway_key, dilithium_key,
      allocated_ip
    ], function(err) {
      if (err) {
        console.error('Register device error:', err.message);
        reject(err);
      } else {
        console.log(`✓ Device registered: ${device_id}`);
        resolve({
          id: this.lastID,
          device_id,
          allocated_ip,
          created_at: new Date().toISOString()
        });
      }
    });
  });
}

/**
 * Get device by ID
 */
async function getDevice(deviceId) {
  return new Promise((resolve, reject) => {
    db.get(
      'SELECT * FROM devices WHERE device_id = ? AND is_active = 1',
      [deviceId],
      (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(row || null);
        }
      }
    );
  });
}

/**
 * Get all active devices
 */
async function getAllDevices() {
  return new Promise((resolve, reject) => {
    db.all(
      'SELECT * FROM devices WHERE is_active = 1 ORDER BY created_at DESC',
      (err, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows || []);
        }
      }
    );
  });
}

/**
 * Get devices by owner
 */
async function getDevicesByOwner(ownerId) {
  return new Promise((resolve, reject) => {
    db.all(
      'SELECT * FROM devices WHERE owner_id = ? AND is_active = 1 ORDER BY created_at DESC',
      [ownerId],
      (err, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows || []);
        }
      }
    );
  });
}

/**
 * Update device
 */
async function updateDevice(deviceId, updates) {
  return new Promise((resolve, reject) => {
    const updateFields = [];
    const values = [];
    
    for (const [key, value] of Object.entries(updates)) {
      if (!['id', 'created_at'].includes(key)) {
        updateFields.push(`${key} = ?`);
        values.push(value);
      }
    }
    
    if (updateFields.length === 0) {
      resolve({ success: false, message: 'No fields to update' });
      return;
    }
    
    values.push(deviceId);
    const sql = `UPDATE devices SET ${updateFields.join(', ')} WHERE device_id = ?`;
    
    db.run(sql, values, (err) => {
      if (err) {
        reject(err);
      } else {
        console.log(`✓ Device updated: ${deviceId}`);
        resolve({ success: true, device_id: deviceId });
      }
    });
  });
}

/**
 * Update last_seen timestamp
 */
async function updateLastSeen(deviceId) {
  return updateDevice(deviceId, {
    last_seen: new Date().toISOString()
  });
}

/**
 * Deactivate device
 */
async function deactivateDevice(deviceId) {
  return updateDevice(deviceId, {
    is_active: false
  });
}

/**
 * Delete device
 */
async function deleteDevice(deviceId) {
  return new Promise((resolve, reject) => {
    db.run(
      'DELETE FROM devices WHERE device_id = ?',
      [deviceId],
      function(err) {
        if (err) {
          reject(err);
        } else {
          console.log(`✓ Device deleted: ${deviceId}`);
          resolve({ success: true, device_id: deviceId });
        }
      }
    );
  });
}

/**
 * Get device count
 */
async function getDeviceCount() {
  return new Promise((resolve, reject) => {
    db.get(
      'SELECT COUNT(*) as count FROM devices WHERE is_active = 1',
      (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(row ? row.count : 0);
        }
      }
    );
  });
}

/**
 * Load all devices from database (on startup)
 */
async function loadAllDevices() {
  const devices = await getAllDevices();
  console.log(`✓ Loaded ${devices.length} devices from registry`);
  return devices;
}

/**
 * Export registry to JSON (for backup)
 */
async function exportToJSON() {
  const devices = await getAllDevices();
  const timestamp = new Date().toISOString().replace(/:/g, '-');
  const filename = `device-registry-backup-${timestamp}.json`;
  const filepath = path.join(__dirname, filename);
  
  fs.writeFileSync(filepath, JSON.stringify(devices, null, 2));
  console.log(`✓ Registry exported to ${filename}`);
  return filename;
}

/**
 * Import registry from JSON
 */
async function importFromJSON(jsonPath) {
  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
  let imported = 0;
  
  for (const device of data) {
    try {
      await registerDevice(device);
      imported++;
    } catch (err) {
      // Device might already exist, skip
    }
  }
  
  console.log(`✓ Imported ${imported} devices from ${jsonPath}`);
  return imported;
}

/**
 * Health check
 */
async function healthCheck() {
  return new Promise((resolve, reject) => {
    db.get('SELECT 1', (err) => {
      if (err) {
        reject({ status: 'error', message: 'Registry unavailable' });
      } else {
        resolve({ status: 'ok', message: 'Registry healthy' });
      }
    });
  });
}

/**
 * Close database
 */
async function close() {
  return new Promise((resolve, reject) => {
    if (db) {
      db.close((err) => {
        if (err) {
          reject(err);
        } else {
          console.log('✓ Device registry closed');
          resolve();
        }
      });
    } else {
      resolve();
    }
  });
}

// Export functions
module.exports = {
  init,
  registerDevice,
  getDevice,
  getAllDevices,
  getDevicesByOwner,
  updateDevice,
  updateLastSeen,
  deactivateDevice,
  deleteDevice,
  getDeviceCount,
  loadAllDevices,
  exportToJSON,
  importFromJSON,
  healthCheck,
  close
};
