/**
 * Health Checks Module
 * 
 * Monitors system health and provides status endpoint
 * Checks: Database, VPN, HTTPS, Memory, CPU, Disk
 * 
 * Usage:
 *   const health = require('./health-checks');
 *   await health.init();
 *   app.get('/api/health', health.getStatus);
 */

const os = require('os');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Thresholds
const THRESHOLDS = {
  memoryPercent: 80,      // % of total memory
  cpuPercent: 75,         // % CPU usage
  diskPercent: 85,        // % disk usage
  responseTime: 5000,     // ms
  errorRate: 0.05         // 5% of requests
};

// Statistics
let stats = {
  startTime: Date.now(),
  totalRequests: 0,
  failedRequests: 0,
  lastRequestTime: 0,
  avgResponseTime: 0
};

/**
 * Initialize health checks
 */
async function init() {
  console.log('✓ Health checks initialized');
  return true;
}

/**
 * Get memory usage
 */
function getMemoryUsage() {
  const total = os.totalmem();
  const free = os.freemem();
  const used = total - free;
  const percent = (used / total) * 100;
  
  return {
    total: Math.round(total / 1024 / 1024) + ' MB',
    free: Math.round(free / 1024 / 1024) + ' MB',
    used: Math.round(used / 1024 / 1024) + ' MB',
    percent: Math.round(percent * 100) / 100,
    status: percent > THRESHOLDS.memoryPercent ? 'warning' : 'ok'
  };
}

/**
 * Get CPU usage
 */
function getCpuUsage() {
  const cpus = os.cpus();
  let totalIdle = 0;
  let totalTick = 0;
  
  cpus.forEach((cpu) => {
    for (const type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  });
  
  const idle = totalIdle / cpus.length;
  const total = totalTick / cpus.length;
  const usage = 100 - ~~(100 * idle / total);
  
  return {
    cores: cpus.length,
    percent: usage,
    status: usage > THRESHOLDS.cpuPercent ? 'warning' : 'ok',
    model: cpus[0].model
  };
}

/**
 * Get disk usage
 */
async function getDiskUsage() {
  try {
    const { stdout } = await execAsync('df -h / | tail -1');
    const parts = stdout.trim().split(/\s+/);
    
    if (parts.length < 5) {
      return { status: 'error', message: 'Cannot determine disk usage' };
    }
    
    const percent = parseInt(parts[4]);
    
    return {
      total: parts[1],
      used: parts[2],
      available: parts[3],
      percent: percent,
      status: percent > THRESHOLDS.diskPercent ? 'warning' : 'ok'
    };
  } catch (err) {
    // Fallback for Windows/other systems
    return {
      status: 'unknown',
      message: 'Disk usage detection not available on this platform'
    };
  }
}

/**
 * Check database health
 */
async function checkDatabase() {
  try {
    const db = require('./database-init');
    await db.initDatabase();
    
    // Quick query
    const result = await db.get('SELECT COUNT(*) as count FROM devices');
    
    return {
      status: 'ok',
      connected: true,
      device_count: result ? result.count : 0,
      response_time: 'healthy'
    };
  } catch (err) {
    return {
      status: 'error',
      connected: false,
      message: err.message
    };
  }
}

/**
 * Check device registry
 */
async function checkDeviceRegistry() {
  try {
    const registry = require('./device-registry-init');
    const count = await registry.getDeviceCount();
    
    return {
      status: 'ok',
      device_count: count,
      registry_available: true
    };
  } catch (err) {
    return {
      status: 'error',
      registry_available: false,
      message: err.message
    };
  }
}

/**
 * Check HTTPS certificate
 */
function checkCertificates() {
  const certPath = process.env.CERT_FILE || './certificates/server.crt';
  const keyPath = process.env.CERT_KEY || './certificates/server.key';
  
  const certExists = fs.existsSync(certPath);
  const keyExists = fs.existsSync(keyPath);
  
  if (!certExists || !keyExists) {
    return {
      status: 'error',
      message: 'Certificates not found'
    };
  }
  
  try {
    const https_cfg = require('./https-config');
    const certInfo = https_cfg.checkCertificateExpiration();
    
    return {
      status: certInfo.isValid ? 'ok' : 'warning',
      certificate: certPath,
      valid: certInfo.isValid,
      days_until_expiration: certInfo.daysLeft,
      expires_at: certInfo.message
    };
  } catch (err) {
    return {
      status: 'error',
      message: 'Cannot check certificate: ' + err.message
    };
  }
}

/**
 * Check VPN status
 */
async function checkVPN() {
  try {
    // Try to check if Lightway is listening
    const { stdout } = await execAsync('ss -tuln 2>/dev/null | grep 1024');
    
    return {
      status: 'ok',
      lightway_port: 1024,
      listening: stdout.length > 0,
      protocol: 'Lightway'
    };
  } catch (err) {
    // VPN might not be active on dev machine
    return {
      status: 'info',
      message: 'VPN check skipped (may not be running on this machine)',
      can_be_configured: true
    };
  }
}

/**
 * Calculate request statistics
 */
function updateStats(responseTime, success = true) {
  stats.totalRequests++;
  stats.lastRequestTime = responseTime;
  
  if (!success) {
    stats.failedRequests++;
  }
  
  // Calculate rolling average
  stats.avgResponseTime = 
    (stats.avgResponseTime * (stats.totalRequests - 1) + responseTime) /
    stats.totalRequests;
}

/**
 * Get uptime
 */
function getUptime() {
  const uptime = Date.now() - stats.startTime;
  const seconds = Math.floor(uptime / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  return {
    seconds,
    minutes,
    hours,
    days,
    formatted: `${days}d ${hours % 24}h ${minutes % 60}m ${seconds % 60}s`
  };
}

/**
 * Get comprehensive health status
 */
async function getStatus() {
  const [
    memory,
    cpu,
    disk,
    database,
    registry,
    certificates,
    vpn,
    uptime
  ] = await Promise.all([
    Promise.resolve(getMemoryUsage()),
    Promise.resolve(getCpuUsage()),
    getDiskUsage(),
    checkDatabase(),
    checkDeviceRegistry(),
    Promise.resolve(checkCertificates()),
    checkVPN(),
    Promise.resolve(getUptime())
  ]);
  
  // Determine overall status
  const allChecks = [memory, cpu, disk, database, registry, certificates];
  const hasError = allChecks.some(c => c.status === 'error');
  const hasWarning = allChecks.some(c => c.status === 'warning');
  
  const overallStatus = hasError ? 'error' : hasWarning ? 'warning' : 'ok';
  
  return {
    status: overallStatus,
    timestamp: new Date().toISOString(),
    uptime,
    requests: {
      total: stats.totalRequests,
      failed: stats.failedRequests,
      error_rate: stats.totalRequests > 0 
        ? (stats.failedRequests / stats.totalRequests).toFixed(4)
        : 0,
      avg_response_time_ms: Math.round(stats.avgResponseTime)
    },
    system: {
      memory,
      cpu,
      disk,
      hostname: os.hostname(),
      platform: os.platform(),
      nodeVersion: process.version
    },
    services: {
      database,
      registry,
      certificates,
      vpn
    }
  };
}

/**
 * Express middleware to track request stats
 */
function trackRequests(req, res, next) {
  const start = Date.now();
  
  const originalSend = res.send;
  res.send = function(data) {
    const time = Date.now() - start;
    const success = res.statusCode < 400;
    updateStats(time, success);
    
    return originalSend.call(this, data);
  };
  
  next();
}

/**
 * Express endpoint handler
 */
async function handler(req, res) {
  try {
    const status = await getStatus();
    res.json(status);
  } catch (err) {
    res.status(500).json({
      status: 'error',
      message: 'Health check failed',
      error: err.message
    });
  }
}

/**
 * Liveness probe (for Kubernetes)
 */
async function livenessProbe(req, res) {
  const db = await checkDatabase();
  
  if (db.status === 'error') {
    return res.status(503).json({ status: 'unhealthy' });
  }
  
  res.json({ status: 'alive' });
}

/**
 * Readiness probe (for Kubernetes)
 */
async function readinessProbe(req, res) {
  const [db, registry] = await Promise.all([
    checkDatabase(),
    checkDeviceRegistry()
  ]);
  
  if (db.status === 'error' || registry.status === 'error') {
    return res.status(503).json({ status: 'not_ready' });
  }
  
  res.json({ status: 'ready' });
}

// Export functions
module.exports = {
  init,
  getMemoryUsage,
  getCpuUsage,
  getDiskUsage,
  checkDatabase,
  checkDeviceRegistry,
  checkCertificates,
  checkVPN,
  getStatus,
  getUptime,
  trackRequests,
  handler,
  livenessProbe,
  readinessProbe,
  updateStats
};
