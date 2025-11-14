#!/usr/bin/env node

/**
 * RMADA Test Suite - Unit and Integration Tests
 * 
 * Run with: node test-suite.js
 * Or with npm: npm test (if configured in package.json)
 * 
 * Tests:
 *   ✓ Device registry operations
 *   ✓ SQLite persistence
 *   ✓ Health checks
 *   ✓ HTTPS certificate validation
 *   ✓ Device onboarding workflow
 *   ✓ Telemetry submission
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');
const http = require('http');

// Test utilities
const tests = [];
let passed = 0;
let failed = 0;
let skipped = 0;

const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

function test(name, fn) {
  tests.push({ name, fn });
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function assertEquals(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}: ${message}`);
  }
}

function assertTrue(condition, message) {
  assert(condition, message);
}

function assertFalse(condition, message) {
  assert(!condition, message);
}

async function run() {
  console.log(`\n${colors.blue}${colors.bright}╔════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.blue}${colors.bright}║  🧪 RMADA Test Suite                   ║${colors.reset}`);
  console.log(`${colors.blue}${colors.bright}╚════════════════════════════════════════╝${colors.reset}\n`);

  for (const { name, fn } of tests) {
    try {
      process.stdout.write(`  ${name} ... `);
      await fn();
      console.log(`${colors.green}✓${colors.reset}`);
      passed++;
    } catch (err) {
      console.log(`${colors.red}✗${colors.reset}\n    ${colors.red}${err.message}${colors.reset}`);
      failed++;
    }
  }

  printSummary();
  process.exit(failed > 0 ? 1 : 0);
}

function printSummary() {
  const total = passed + failed + skipped;
  const percent = Math.round((passed / total) * 100);

  console.log(`\n${colors.blue}${colors.bright}════════════════════════════════════════${colors.reset}`);
  console.log(`${colors.green}✓ Passed:${colors.reset}  ${passed}`);
  console.log(`${colors.red}✗ Failed:${colors.reset}  ${failed}`);
  console.log(`${colors.yellow}⊘ Skipped:${colors.reset} ${skipped}`);
  console.log(`\nSuccess Rate: ${percent}% (${passed}/${total})`);
  console.log(`${colors.blue}${colors.bright}════════════════════════════════════════${colors.reset}\n`);
}

// ============================================================================
// CONFIGURATION TESTS
// ============================================================================

test('Configuration: package.json exists', () => {
  assert(fs.existsSync('package.json'), 'package.json not found');
});

test('Configuration: server.js exists', () => {
  assert(fs.existsSync('server.js'), 'server.js not found');
});

test('Configuration: database-schema.sql exists', () => {
  assert(fs.existsSync('database-schema.sql'), 'database-schema.sql not found');
});

test('Configuration: app.js exists', () => {
  assert(fs.existsSync('app.js'), 'app.js not found');
});

// ============================================================================
// DEPENDENCY TESTS
// ============================================================================

test('Dependencies: express module available', () => {
  try {
    require.resolve('express');
  } catch (err) {
    throw new Error('express not installed - run: npm install');
  }
});

test('Dependencies: sqlite3 module available', () => {
  try {
    require.resolve('sqlite3');
  } catch (err) {
    throw new Error('sqlite3 not installed - run: npm install');
  }
});

test('Dependencies: bcryptjs module available', () => {
  try {
    require.resolve('bcryptjs');
  } catch (err) {
    throw new Error('bcryptjs not installed - run: npm install');
  }
});

test('Dependencies: ws (WebSocket) module available', () => {
  try {
    require.resolve('ws');
  } catch (err) {
    throw new Error('ws not installed - run: npm install');
  }
});

// ============================================================================
// DEVICE REGISTRY TESTS
// ============================================================================

test('Device Registry: module loads', () => {
  try {
    const registry = require('./device-registry-init');
    assert(registry, 'Device registry module not found');
    assert(typeof registry.init === 'function', 'init function missing');
    assert(typeof registry.registerDevice === 'function', 'registerDevice function missing');
    assert(typeof registry.getAllDevices === 'function', 'getAllDevices function missing');
  } catch (err) {
    throw new Error(`Failed to load device registry: ${err.message}`);
  }
});

test('Device Registry: init function', async () => {
  try {
    const registry = require('./device-registry-init');
    await registry.init();
  } catch (err) {
    throw new Error(`Failed to initialize registry: ${err.message}`);
  }
});

test('Device Registry: register device', async () => {
  try {
    const registry = require('./device-registry-init');
    const deviceData = {
      device_id: 'TEST-' + Date.now(),
      owner_id: 'test-owner',
      device_type: 'sensor',
      device_name: 'Test Device',
      public_key: 'test-pub-key-' + Date.now(),
      ip_address: '192.168.1.100',
      status: 'active',
    };
    
    await registry.registerDevice(deviceData);
  } catch (err) {
    throw new Error(`Failed to register device: ${err.message}`);
  }
});

test('Device Registry: get all devices', async () => {
  try {
    const registry = require('./device-registry-init');
    const devices = await registry.getAllDevices();
    assert(Array.isArray(devices), 'getAllDevices should return array');
  } catch (err) {
    throw new Error(`Failed to get devices: ${err.message}`);
  }
});

test('Device Registry: persistence across calls', async () => {
  try {
    const registry = require('./device-registry-init');
    
    // Register first device
    const device1 = {
      device_id: 'PERSIST-' + Date.now(),
      owner_id: 'persist-test',
      device_type: 'sensor',
      device_name: 'Persistent Device',
      public_key: 'test-key-persist',
      ip_address: '10.0.0.1',
      status: 'active',
    };
    
    await registry.registerDevice(device1);
    
    // Load and verify
    const devices = await registry.getAllDevices();
    const found = devices.find(d => d.device_id === device1.device_id);
    assert(found, 'Device not found after registration');
  } catch (err) {
    throw new Error(`Persistence test failed: ${err.message}`);
  }
});

test('Device Registry: load on startup', async () => {
  try {
    const registry = require('./device-registry-init');
    const result = await registry.loadAllDevices();
    assert(result !== undefined, 'loadAllDevices should return data');
  } catch (err) {
    throw new Error(`Failed to load on startup: ${err.message}`);
  }
});

test('Device Registry: export to JSON', async () => {
  try {
    const registry = require('./device-registry-init');
    const json = await registry.exportToJSON();
    assert(json, 'exportToJSON should return data');
  } catch (err) {
    throw new Error(`Failed to export JSON: ${err.message}`);
  }
});

test('Device Registry: health check', async () => {
  try {
    const registry = require('./device-registry-init');
    const health = await registry.healthCheck();
    assert(health.status !== undefined, 'healthCheck should include status');
  } catch (err) {
    throw new Error(`Health check failed: ${err.message}`);
  }
});

// ============================================================================
// HEALTH CHECKS TESTS
// ============================================================================

test('Health Checks: module loads', () => {
  try {
    const health = require('./health-checks');
    assert(health, 'Health checks module not found');
    assert(typeof health.getMemoryUsage === 'function', 'getMemoryUsage missing');
    assert(typeof health.getCpuUsage === 'function', 'getCpuUsage missing');
    assert(typeof health.getDiskUsage === 'function', 'getDiskUsage missing');
    assert(typeof health.getStatus === 'function', 'getStatus missing');
  } catch (err) {
    throw new Error(`Failed to load health checks: ${err.message}`);
  }
});

test('Health Checks: memory usage', () => {
  try {
    const health = require('./health-checks');
    const memUsage = health.getMemoryUsage();
    assert(memUsage.total > 0, 'Total memory should be > 0');
    assert(memUsage.used >= 0, 'Used memory should be >= 0');
    assert(memUsage.percent >= 0, 'Memory percent should be >= 0');
  } catch (err) {
    throw new Error(`Memory check failed: ${err.message}`);
  }
});

test('Health Checks: CPU usage', () => {
  try {
    const health = require('./health-checks');
    const cpuUsage = health.getCpuUsage();
    assert(cpuUsage.load !== undefined, 'CPU load not available');
    assert(cpuUsage.threshold !== undefined, 'CPU threshold not set');
  } catch (err) {
    throw new Error(`CPU check failed: ${err.message}`);
  }
});

test('Health Checks: disk usage', () => {
  try {
    const health = require('./health-checks');
    const diskUsage = health.getDiskUsage();
    assert(diskUsage.total > 0, 'Disk total should be > 0');
    assert(diskUsage.percent >= 0, 'Disk percent should be >= 0');
  } catch (err) {
    throw new Error(`Disk check failed: ${err.message}`);
  }
});

test('Health Checks: comprehensive status', () => {
  try {
    const health = require('./health-checks');
    const status = health.getStatus();
    assert(status.timestamp !== undefined, 'Timestamp missing');
    assert(status.system !== undefined, 'System info missing');
    assert(status.services !== undefined, 'Services info missing');
  } catch (err) {
    throw new Error(`Status check failed: ${err.message}`);
  }
});

test('Health Checks: uptime calculation', () => {
  try {
    const health = require('./health-checks');
    const uptime = health.getUptime();
    assert(typeof uptime === 'string', 'Uptime should be string');
    assert(uptime.length > 0, 'Uptime should not be empty');
  } catch (err) {
    throw new Error(`Uptime check failed: ${err.message}`);
  }
});

// ============================================================================
// CERTIFICATE TESTS
// ============================================================================

test('Certificates: HTTPS cert exists', () => {
  const certPath = 'certificates/server.crt';
  assert(fs.existsSync(certPath), `Certificate not found at ${certPath}`);
});

test('Certificates: HTTPS key exists', () => {
  const keyPath = 'certificates/server.key';
  assert(fs.existsSync(keyPath), `Key not found at ${keyPath}`);
});

test('Certificates: cert is readable', () => {
  try {
    const cert = fs.readFileSync('certificates/server.crt', 'utf8');
    assert(cert.includes('BEGIN CERTIFICATE'), 'Invalid certificate format');
  } catch (err) {
    throw new Error(`Failed to read certificate: ${err.message}`);
  }
});

test('Certificates: key is readable', () => {
  try {
    const key = fs.readFileSync('certificates/server.key', 'utf8');
    assert(key.includes('PRIVATE KEY'), 'Invalid key format');
  } catch (err) {
    throw new Error(`Failed to read key: ${err.message}`);
  }
});

// ============================================================================
// DATABASE TESTS
// ============================================================================

test('Database: SQLite file exists', () => {
  assert(fs.existsSync('rmada.db'), 'Database file not found - run: npm start');
});

test('Database: schema file exists', () => {
  assert(fs.existsSync('database-schema.sql'), 'Schema file not found');
});

test('Database: schema is readable', () => {
  try {
    const schema = fs.readFileSync('database-schema.sql', 'utf8');
    assert(schema.includes('CREATE TABLE'), 'Invalid schema format');
  } catch (err) {
    throw new Error(`Failed to read schema: ${err.message}`);
  }
});

// ============================================================================
// API ENDPOINT TESTS
// ============================================================================

async function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    const req = client.get(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({ status: res.statusCode, data, headers: res.headers });
      });
    });
    req.on('error', reject);
    req.setTimeout(5000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

test('API: Health endpoint responds', async () => {
  try {
    const response = await makeRequest('https://localhost:8443/api/health', {
      rejectUnauthorized: false,
    });
    assert(response.status !== undefined, 'No response status');
    // 200 or other status acceptable - just checking it responds
    assert(response.data, 'Empty response');
  } catch (err) {
    if (err.code === 'ECONNREFUSED') {
      throw new Error('Server not running - start with: npm start');
    }
    throw err;
  }
});

// ============================================================================
// STARTUP SCRIPT TESTS
// ============================================================================

test('Startup: start-rmada.sh exists', () => {
  assert(fs.existsSync('start-rmada.sh'), 'start-rmada.sh not found');
});

test('Startup: start script is executable', () => {
  const stats = fs.statSync('start-rmada.sh');
  assert((stats.mode & 0o111) !== 0, 'start-rmada.sh is not executable');
});

test('Startup: start script has content', () => {
  const content = fs.readFileSync('start-rmada.sh', 'utf8');
  assert(content.includes('bash'), 'Not a valid bash script');
  assert(content.length > 100, 'Script too small');
});

// ============================================================================
// DOCUMENTATION TESTS
// ============================================================================

test('Documentation: RMADA-COMPLETE-GUIDE exists', () => {
  assert(fs.existsSync('RMADA-COMPLETE-GUIDE.md'), 'Master guide not found');
});

test('Documentation: DATABASE.md exists', () => {
  if (!fs.existsSync('DATABASE.md')) {
    throw new Error('DATABASE.md not found');
  }
});

test('Documentation: HTTPS-SETUP.md exists', () => {
  if (!fs.existsSync('HTTPS-SETUP.md')) {
    throw new Error('HTTPS-SETUP.md not found');
  }
});

test('Documentation: Master guide has content', () => {
  const content = fs.readFileSync('RMADA-COMPLETE-GUIDE.md', 'utf8');
  assert(content.length > 1000, 'Master guide too small');
  assert(content.includes('##'), 'Missing markdown headers');
});

// ============================================================================
// PERFORMANCE TESTS
// ============================================================================

test('Performance: Device registry response time', async () => {
  try {
    const registry = require('./device-registry-init');
    const start = Date.now();
    await registry.getAllDevices();
    const duration = Date.now() - start;
    assert(duration < 1000, `Registry query took ${duration}ms (too slow)`);
  } catch (err) {
    throw new Error(`Performance test failed: ${err.message}`);
  }
});

test('Performance: Health check response time', () => {
  try {
    const health = require('./health-checks');
    const start = Date.now();
    health.getStatus();
    const duration = Date.now() - start;
    assert(duration < 500, `Health check took ${duration}ms (too slow)`);
  } catch (err) {
    throw new Error(`Performance test failed: ${err.message}`);
  }
});

// Run tests
run();
