/**
 * RMADA Stage 3 — HTTPS/TLS Configuration
 * Supports self-signed certificates and Let's Encrypt
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// Certificate paths
const CERT_DIR = process.env.CERT_DIR || path.join(__dirname, 'certificates');
const CERT_FILE = path.join(CERT_DIR, 'server.crt');
const KEY_FILE = path.join(CERT_DIR, 'server.key');
const SELF_SIGNED_DAYS = 365;

/**
 * Ensure certificate directory exists
 */
function ensureCertDir() {
  if (!fs.existsSync(CERT_DIR)) {
    fs.mkdirSync(CERT_DIR, { recursive: true });
    console.log(`✅ Certificate directory created: ${CERT_DIR}`);
  }
}

/**
 * Check if certificates exist
 */
function certificatesExist() {
  return fs.existsSync(CERT_FILE) && fs.existsSync(KEY_FILE);
}

/**
 * Generate self-signed certificate using OpenSSL
 */
function generateSelfSignedCertificate(hostname = 'localhost') {
  ensureCertDir();
  
  if (certificatesExist()) {
    console.log('✅ Certificates already exist');
    return { cert: CERT_FILE, key: KEY_FILE };
  }
  
  console.log(`🔐 Generating self-signed certificate for ${hostname}...`);
  
  const cmd = [
    'req',
    '-x509',
    '-newkey', 'rsa:2048',
    '-keyout', KEY_FILE,
    '-out', CERT_FILE,
    '-days', SELF_SIGNED_DAYS,
    '-nodes',
    '-subj', `/CN=${hostname}/O=RMADA/C=BR`,
  ];
  
  try {
    const result = spawnSync('openssl', cmd, { encoding: 'utf8' });
    
    if (result.error) {
      throw result.error;
    }
    
    if (result.status === 0) {
      console.log(`✅ Self-signed certificate generated (valid for ${SELF_SIGNED_DAYS} days)`);
      console.log(`   Cert: ${CERT_FILE}`);
      console.log(`   Key:  ${KEY_FILE}`);
      console.log('   ⚠️  WARNING: Self-signed certificates should only be used in development!');
      return { cert: CERT_FILE, key: KEY_FILE };
    } else {
      throw new Error(result.stderr || 'OpenSSL failed');
    }
  } catch (err) {
    console.error('❌ Failed to generate certificate:', err.message);
    console.error('   Make sure OpenSSL is installed: apt-get install openssl (Debian/Ubuntu)');
    throw err;
  }
}

/**
 * Load existing certificates
 */
function loadCertificates() {
  try {
    if (!certificatesExist()) {
      console.warn('⚠️  Certificates not found, generating self-signed...');
      return generateSelfSignedCertificate();
    }
    
    const cert = fs.readFileSync(CERT_FILE, 'utf8');
    const key = fs.readFileSync(KEY_FILE, 'utf8');
    
    console.log('✅ Certificates loaded from disk');
    return { cert, key };
  } catch (err) {
    console.error('❌ Failed to load certificates:', err.message);
    throw err;
  }
}

/**
 * Check certificate expiration
 */
function checkCertificateExpiration() {
  if (!certificatesExist()) {
    return { isValid: false, daysLeft: 0, message: 'Certificates not found' };
  }
  
  try {
    const result = spawnSync('openssl', [
      'x509',
      '-in', CERT_FILE,
      '-noout',
      '-dates',
    ], { encoding: 'utf8' });
    
    if (result.status === 0) {
      const output = result.stdout;
      const notAfterMatch = output.match(/notAfter=(.+)/);
      
      if (notAfterMatch) {
        const expireDate = new Date(notAfterMatch[1]);
        const now = new Date();
        const daysLeft = Math.floor((expireDate - now) / (1000 * 60 * 60 * 24));
        
        return {
          isValid: daysLeft > 0,
          daysLeft,
          expiresAt: expireDate,
          message: daysLeft > 30
            ? `✅ Certificate valid for ${daysLeft} more days`
            : `⚠️  Certificate expires in ${daysLeft} days!`,
        };
      }
    }
    
    return { isValid: false, daysLeft: 0, message: 'Could not parse certificate' };
  } catch (err) {
    console.error('❌ Failed to check certificate expiration:', err.message);
    return { isValid: false, daysLeft: 0, message: err.message };
  }
}

/**
 * Get security headers middleware
 */
function getSecurityHeaders() {
  return (req, res, next) => {
    // HSTS: Force HTTPS for 1 year
    res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    
    // Prevent clickjacking
    res.set('X-Frame-Options', 'DENY');
    
    // Disable MIME type sniffing
    res.set('X-Content-Type-Options', 'nosniff');
    
    // Enable XSS protection
    res.set('X-XSS-Protection', '1; mode=block');
    
    // Referrer policy
    res.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    
    // Content Security Policy (permissive for WebSocket)
    res.set('Content-Security-Policy', 
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' ws: wss:");
    
    next();
  };
}

/**
 * Log certificate info
 */
function logCertificateInfo() {
  try {
    if (certificatesExist()) {
      const result = spawnSync('openssl', [
        'x509',
        '-in', CERT_FILE,
        '-noout',
        '-text',
      ], { encoding: 'utf8' });
      
      if (result.status === 0) {
        const output = result.stdout;
        const subjectMatch = output.match(/Subject: (.+)/);
        const issuerMatch = output.match(/Issuer: (.+)/);
        const dateMatch = output.match(/Not After : (.+)/);
        
        console.log('\n🔐 Certificate Information:');
        if (subjectMatch) console.log(`   Subject: ${subjectMatch[1].trim()}`);
        if (issuerMatch) console.log(`   Issuer:  ${issuerMatch[1].trim()}`);
        if (dateMatch) console.log(`   Expires: ${dateMatch[1].trim()}`);
        console.log();
      }
    }
  } catch (err) {
    // Silent fail
  }
}

module.exports = {
  ensureCertDir,
  certificatesExist,
  generateSelfSignedCertificate,
  loadCertificates,
  checkCertificateExpiration,
  getSecurityHeaders,
  logCertificateInfo,
  CERT_DIR,
  CERT_FILE,
  KEY_FILE,
};
