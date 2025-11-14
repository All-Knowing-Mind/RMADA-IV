# RMADA Stage 3 — HTTPS/TLS Setup Guide

## Overview

Stage 3 adds HTTPS support to make RMADA production-ready and secure. This guide covers:
- Self-signed certificates (development)
- Let's Encrypt (production)
- Certificate renewal
- Security best practices

---

## Quick Start (Development)

### Auto-Generate Self-Signed Certificate

```bash
# Already done automatically when server starts!
# Or manually:
npm start

# Certificates created in ./certificates/
ls -la certificates/
# → server.crt (certificate)
# → server.key (private key)
```

### Access Dashboard

```bash
# HTTPS (with self-signed cert warning)
https://localhost:8443

# Or use curl with -k flag (skip cert verification)
curl -k https://localhost:8443/health
```

### Browser Warning

When you see the SSL warning:
- **Development**: Click "Advanced" → "Proceed anyway"
- **Production**: Use valid certificate from Let's Encrypt

---

## Production Setup

### Option 1: Let's Encrypt (Free, Automatic)

#### Prerequisites
- Domain name pointing to your server
- Ports 80 + 443 accessible from internet

#### Install Certbot

```bash
# Debian/Ubuntu
sudo apt-get install certbot python3-certbot-nginx

# Or standalone
sudo apt-get install certbot
```

#### Get Certificate

```bash
# Standalone (no web server needed)
sudo certbot certonly --standalone -d your-domain.com

# Or with nginx (if using reverse proxy)
sudo certbot certonly --nginx -d your-domain.com

# Certificates saved to:
# /etc/letsencrypt/live/your-domain.com/
```

#### Update RMADA Config

```bash
# Set certificate paths
export CERT_DIR=/etc/letsencrypt/live/your-domain.com
export NODE_PORT=443

# Or edit docker-compose.yml:
# environment:
#   CERT_DIR: /etc/letsencrypt/live/your-domain.com
#   NODE_PORT: 443
```

#### Auto-Renewal

```bash
# Certbot handles renewal automatically via cron
# Check renewal status:
sudo certbot renew --dry-run

# Or manually:
sudo certbot renew
```

### Option 2: Commercial Certificate

1. Purchase from CA (Comodo, DigiCert, etc)
2. Place in `./certificates/server.crt` and `./certificates/server.key`
3. Restart server

### Option 3: Self-Signed (Development Only)

```bash
# Already done! But if you need to regenerate:
openssl req -x509 -newkey rsa:2048 \
  -keyout certificates/server.key \
  -out certificates/server.crt \
  -days 365 -nodes \
  -subj "/CN=localhost/O=RMADA/C=BR"
```

---

## Configuration

### Environment Variables

```bash
# Custom certificate directory
export CERT_DIR=/path/to/certs

# Custom HTTPS port
export NODE_HTTPS_PORT=8443

# Disable HTTPS (dev only)
export DISABLE_HTTPS=true
```

### Docker Compose

```yaml
services:
  rmada-server:
    environment:
      CERT_DIR: /etc/letsencrypt/live/your-domain.com
      NODE_HTTPS_PORT: 443
    volumes:
      # Mount Let's Encrypt certificates
      - /etc/letsencrypt:/etc/letsencrypt:ro
    ports:
      - "443:443"   # HTTPS
      - "80:80"     # HTTP (for cert renewal)
      - "8080:8080" # HTTP (fallback)
```

---

## Security Headers

RMADA automatically adds these security headers:

| Header | Purpose |
|--------|---------|
| Strict-Transport-Security (HSTS) | Force HTTPS for 1 year |
| X-Frame-Options | Prevent clickjacking |
| X-Content-Type-Options | Disable MIME sniffing |
| X-XSS-Protection | Enable XSS protection |
| Content-Security-Policy | Restrict resource loading |

---

## Certificate Management

### Check Certificate Info

```bash
# View certificate details
openssl x509 -in certificates/server.crt -noout -text

# Check expiration
openssl x509 -in certificates/server.crt -noout -dates

# Check key strength
openssl rsa -in certificates/server.key -noout -text | head -5
```

### Check Expiration

```bash
# RMADA automatically checks on startup
npm start

# Manual check via API
curl https://localhost:8443/api/certificate-info -k

# Response:
# {
#   "isValid": true,
#   "daysLeft": 365,
#   "expiresAt": "2026-11-11T00:00:00Z"
# }
```

### Backup Certificates

```bash
# Important! Backup your private key securely
tar czf rmada-certs-backup.tar.gz certificates/
chmod 600 rmada-certs-backup.tar.gz

# Or use database backup:
cp rmada.db rmada-db-backup.sql
```

---

## Debugging HTTPS

### Server Won't Start on HTTPS Port

```bash
# Port already in use?
lsof -i :443
kill -9 <PID>

# Or use different port:
export NODE_HTTPS_PORT=8443
npm start

# Then access: https://localhost:8443
```

### Certificate Not Found

```bash
# Regenerate self-signed cert:
rm -f certificates/server.* 
npm start

# Or specify custom location:
export CERT_DIR=/my/custom/path
npm start
```

### HTTPS Connection Refused

```bash
# Check if server is listening on HTTPS
netstat -tuln | grep 443  # or 8443
curl -v -k https://localhost:8443

# Check server logs
docker-compose logs -f rmada-server | grep -i https
```

### Certificate Chain Issues

```bash
# Verify full certificate chain
openssl verify -CAfile /etc/ssl/certs/ca-bundle.crt certificates/server.crt

# Or for Let's Encrypt:
curl https://your-domain.com --cacert /etc/ssl/certs/ca-bundle.crt
```

---

## Testing

### Test HTTPS Connection

```bash
# With curl (skip cert verification)
curl -k https://localhost:8443/health

# With openssl
openssl s_client -connect localhost:8443 -showcerts

# With curl (show cert info)
curl -vI -k https://localhost:8443
```

### Test Security Headers

```bash
curl -I https://localhost:8443 -k

# Should show:
# Strict-Transport-Security: max-age=31536000
# X-Frame-Options: DENY
# X-Content-Type-Options: nosniff
# Content-Security-Policy: default-src 'self'...
```

### Performance Test

```bash
# HTTP benchmark (baseline)
ab -n 1000 -c 10 http://localhost:8080/health

# HTTPS benchmark
ab -n 1000 -c 10 https://localhost:8443/health -k
```

---

## Migration from HTTP to HTTPS

### Step 1: Generate Certificate

```bash
npm start  # Auto-generates self-signed cert
# Or install Let's Encrypt certificate
```

### Step 2: Update Configuration

```bash
# Update frontend to use HTTPS URLs
# Update any external APIs to use HTTPS
# Update firewall to allow HTTPS (443 or 8443)
```

### Step 3: Test

```bash
# Verify HTTPS is working
curl -k https://localhost:8443/health

# Verify HTTP redirect works
curl -L http://localhost:8080/health
```

### Step 4: Deploy

```bash
# Update docker-compose.yml
# Update DNS records
# Update firewall rules
docker-compose up -d
```

---

## Troubleshooting

### Issue: Self-signed cert not trusted

**Solution**: This is normal for development. In production:
1. Use Let's Encrypt or commercial cert
2. Or pre-install cert on client devices
3. Or use --insecure flag in curl/tools

### Issue: "CERTIFICATE_VERIFY_FAILED"

**Solution**:
```bash
# Check if cert matches hostname
openssl x509 -in certificates/server.crt -noout -subject

# If hostname mismatch, regenerate:
# rm certificates/server.* && npm start
```

### Issue: Certificate expired

**Solution**:
```bash
# Renew with Let's Encrypt
sudo certbot renew

# Or regenerate self-signed
rm certificates/server.*
npm start
```

### Issue: HTTPS port not accessible from outside

**Solution**:
1. Check firewall: `sudo ufw allow 443`
2. Check port forwarding on router
3. Verify server is listening: `netstat -tuln | grep 443`

---

## Best Practices

### Development
✅ Use self-signed certificates  
✅ Test on localhost only  
✅ Skip verification in curl: `-k` flag  

### Production
✅ Use Let's Encrypt (free, automatic renewal)  
✅ Use valid domain name  
✅ Set up auto-renewal (cron)  
✅ Backup private keys securely  
✅ Monitor certificate expiration  
✅ Use strong ciphers (TLS 1.2+)  
✅ Enable HSTS  
✅ Regular security audits  

---

## Resources

- **OpenSSL Docs**: https://www.openssl.org/
- **Let's Encrypt**: https://letsencrypt.org/
- **OWASP HTTPS**: https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html
- **Mozilla SSL Labs**: https://www.ssllabs.com/

---

**Status**: HTTPS support ready (self-signed + Let's Encrypt)  
**Next**: Set up Lightway VPN in LIGHTWAY-SETUP.md
