# RMADA Stage 3 — Lightway VPN Setup Guide

## Overview

Lightway is a modern, lightweight VPN protocol that replaces WireGuard as the primary VPN for RMADA Stage 3. This guide covers:
- Lightway server setup
- Client configuration (Linux, macOS, Windows)
- Key management with Dilithium
- Performance tuning
- Troubleshooting

---

## What is Lightway?

| Feature | Lightway | WireGuard |
|---------|----------|-----------|
| Protocol | Modern, elliptic-curve based | Kernel-space based |
| Performance | Ultra-lightweight (~4000 LOC) | Optimized for kernel |
| Setup Time | < 1 second | 1-2 seconds |
| Authentication | Dilithium + ChaCha20 | Pre-shared keys |
| Mobile | Good (via SDK) | Excellent (via app) |
| Linux Gateway | ✅ Excellent | ✅ Excellent |
| Power Usage | Minimal (mobile-optimized) | Low |

---

## Quick Start (Server)

### 1. Start Lightway Server

```bash
# Automatically starts when running RMADA
npm start

# Or explicitly start Lightway
bash lightway-startup.sh

# Check status
ps aux | grep lightway
```

### 2. Verify Server is Running

```bash
# Check if listening on port 1024
ss -tuln | grep 1024

# Expected output:
# LISTEN    tcp    0  0  0.0.0.0:1024  0.0.0.0:*
```

### 3. Get Server Public Key

```bash
# Keys generated in ./lightway/
cat ./lightway/server_key.pub

# Output (example):
# -----BEGIN LIGHTWAY PUBLIC KEY-----
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
# -----END LIGHTWAY PUBLIC KEY-----
```

---

## Server Configuration

### Environment Variables

```bash
# Listen address
export LIGHTWAY_LISTEN_ADDR=0.0.0.0

# Listen port
export LIGHTWAY_LISTEN_PORT=1024

# Server binary location
export LIGHTWAY_BINARY=/usr/local/bin/lightway-server

# Configuration file
export LIGHTWAY_CONFIG=/etc/lightway/config.toml

# Log file
export LIGHTWAY_LOG_FILE=/var/log/lightway.log

# Data directory
export LIGHTWAY_DATA_DIR=/var/lib/lightway

# Use Dilithium authentication
export LIGHTWAY_DILITHIUM_AUTH=true
```

### Configuration File

The server creates `lightway/config.toml` automatically:

```toml
[server]
listen_addr = "0.0.0.0"
listen_port = 1024
server_key_file = "./lightway/server_key"

[pool]
# IP address pool for clients
network = "10.1.0.0/24"
start_addr = "10.1.0.2"
end_addr = "10.1.0.254"

[auth]
# Enable Dilithium post-quantum authentication
enable_dilithium = true
dilithium_public_key = "./lightway/dilithium_pub.key"

[logging]
level = "info"
format = "json"
output = "./lightway/logs/server.log"

[performance]
# Maximum concurrent connections
max_connections = 1000

# Connection timeout (seconds)
connection_timeout = 300

# Keep-alive interval (seconds)
keepalive_interval = 30

# MTU size (bytes)
mtu = 1500
```

### Docker Compose

```yaml
version: '3.8'

services:
  rmada-server:
    image: rmada-lightway:latest
    ports:
      - "443:443"    # HTTPS
      - "1024:1024"  # Lightway
    environment:
      LIGHTWAY_LISTEN_PORT: 1024
      LIGHTWAY_LISTEN_ADDR: 0.0.0.0
      LIGHTWAY_DILITHIUM_AUTH: "true"
    volumes:
      - ./lightway:/etc/lightway
      - ./certificates:/app/certificates
      - ./database:/app/database
    networks:
      - rmada-network

networks:
  rmada-network:
    driver: bridge

volumes:
  rmada-data:
```

---

## Client Setup

### Linux Client

#### Install Lightway Client

```bash
# Debian/Ubuntu
sudo apt-get install lightway-client

# Or build from source
git clone https://github.com/WireGuard/wireguard-go.git
cd wireguard-go
make
sudo make install
```

#### Generate Client Keys

```bash
# Get server to generate client keypair
curl -k -X POST https://localhost:8443/api/lightway-client-key \
  -H "Content-Type: application/json" \
  -d '{"client_id":"linux-gateway"}' | jq

# Response:
# {
#   "client_name": "linux-gateway",
#   "private_key": "PrivKeyBase64...",
#   "public_key": "PubKeyBase64...",
#   "endpoint": "SERVER_PUBLIC_IP:1024"
# }
```

#### Create Lightway Config

```bash
# Save as ~/.config/lightway/rmada.conf
cat > /etc/lightway/rmada.conf << 'EOF'
[Interface]
PrivateKey = <paste_client_private_key_here>
Address = 10.1.0.10/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = <paste_server_public_key_here>
Endpoint = YOUR_SERVER_PUBLIC_IP:1024
AllowedIPs = 10.1.0.0/24
PersistentKeepalive = 25
EOF
```

#### Connect to VPN

```bash
# Bring up Lightway interface
sudo ip link add dev lwt0 type dummy
sudo ip addr add 10.1.0.10/32 dev lwt0
sudo ip link set lwt0 up

# Or using systemd
sudo systemctl start lightway-rmada
sudo systemctl enable lightway-rmada

# Check connection
ip addr show | grep 10.1.0

# Test connectivity
ping 10.1.0.1
```

### macOS Client

#### Install via Homebrew

```bash
brew install lightway-client

# Or from source
git clone https://github.com/ExpressVPN/lightway-core
cd lightway-core
./build.sh
sudo make install
```

#### Create Config

```bash
# Save to ~/Library/Application\ Support/Lightway/rmada.conf
sudo cat > /etc/lightway/rmada.conf << 'EOF'
[Interface]
PrivateKey = <client_private_key>
Address = 10.1.0.10/32

[Peer]
PublicKey = <server_public_key>
Endpoint = YOUR_SERVER_IP:1024
AllowedIPs = 10.1.0.0/24
PersistentKeepalive = 25
EOF
```

#### Connect

```bash
# Using wg-quick equivalent for Lightway
sudo lightway-client --config /etc/lightway/rmada.conf --up

# Verify
ifconfig | grep -A 3 lwt
```

### Windows Client

#### Install Lightway Client

```powershell
# Download from https://www.expressvpn.com/lightway
# Or via chocolatey
choco install lightway

# Or via direct download
$url = "https://downloads.expressvpn.com/lightway-windows.exe"
Invoke-WebRequest -Uri $url -OutFile .\lightway-installer.exe
.\lightway-installer.exe
```

#### Create Config

```powershell
# Save to C:\Users\<username>\AppData\Local\Lightway\rmada.conf
@"
[Interface]
PrivateKey = <client_private_key>
Address = 10.1.0.10/32

[Peer]
PublicKey = <server_public_key>
Endpoint = YOUR_SERVER_IP:1024
AllowedIPs = 10.1.0.0/24
PersistentKeepalive = 25
"@ | Out-File -Encoding utf8 "C:\Lightway\rmada.conf"
```

#### Connect

```powershell
# Via GUI or command line
& 'C:\Program Files\Lightway\lightway-client.exe' --config 'C:\Lightway\rmada.conf' --up

# Verify
ipconfig | findstr "10.1.0"
```

---

## Key Management with Dilithium

### Generate Dilithium Keys (Post-Quantum Safe)

```bash
# Automatically done by server, or manually:
./target/release/dilithium_keygen --output lightway/dilithium_keypair

# This creates:
# - lightway/dilithium_keypair.pub (public key)
# - lightway/dilithium_keypair.key (private key)
```

### Verify Client Connections

```bash
# Check client signatures with Dilithium
curl -k -X POST https://localhost:8443/api/verify-client \
  -H "Content-Type: application/json" \
  -d '{
    "client_public_key": "...",
    "signature": "...",
    "message": "..."
  }' | jq
```

### Rotate Keys (Security)

```bash
# Every 90 days, generate new Dilithium keys
bash generate_dilithium_keys.sh

# Old keys become invalid
# All clients must re-authenticate
```

---

## Troubleshooting

### Server Won't Start

```bash
# Check if Lightway binary exists
which lightway-server

# Or install from Earthly build
earthly +lightway-image

# Check port
lsof -i :1024
```

### Client Can't Connect

```bash
# Test connectivity to server
telnet YOUR_SERVER_IP 1024

# Check firewall
sudo ufw allow 1024/udp
sudo ufw allow 1024/tcp

# Verify keys are correct
cat ~/.config/lightway/rmada.conf | grep -A2 "PublicKey\|PrivateKey"

# Try debugging
lightway-client --debug --config ~/.config/lightway/rmada.conf
```

### Slow Connection

```bash
# Check MTU
ip link show | grep -i mtu

# Lower MTU if needed
sudo ip link set dev lwt0 mtu 1400

# Check latency
ping -c 5 10.1.0.1

# Monitor bandwidth
iftop -i lwt0
```

### Keys Not Working

```bash
# Regenerate client config
curl -k -X POST https://localhost:8443/api/lightway-client-key \
  -H "Content-Type: application/json" \
  -d '{"client_id":"my-client","force_regenerate":true}'

# Update config file with new keys
# Reconnect
```

---

## Performance Tuning

### Server Optimization

```bash
# Increase connection limit
ulimit -n 65536

# Adjust TCP parameters
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=2048
sudo sysctl -w net.core.somaxconn=2048

# Enable UDP buffer
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
```

### Client Optimization

```bash
# Reduce keepalive interval for faster reconnect
# Edit config:
PersistentKeepalive = 10  # was 25

# Or disable for always-on
# Don't set PersistentKeepalive (only server-to-client)
```

### Bandwidth Optimization

```bash
# Use compression
# Edit config with Lightway compression support
[Interface]
Compress = true

# Monitor bandwidth
nethogs -i lwt0
```

---

## Security

### Firewall Rules

```bash
# Allow only authorized clients
sudo ufw allow from 203.0.113.50 to any port 1024

# Or use IP allowlist in config
[auth]
allowed_ips = ["203.0.113.50", "198.51.100.10"]
```

### Certificate Pinning

```bash
# Pin server certificate for additional security
# In client config:
[Peer]
PublicKey = <PINNED_PUBLIC_KEY>
CheckCertificate = true
CertificatePinningEnabled = true
```

### Rate Limiting

```bash
# Configure in server config
[security]
rate_limit_enabled = true
rate_limit_requests_per_second = 100
rate_limit_burst = 1000
```

---

## Monitoring

### Check Active Connections

```bash
# Server side
curl -k https://localhost:8443/api/lightway-peers | jq '.[] | {client_id, ip, connected_since, last_packet}'

# Linux client
ss -u | grep :1024
```

### Logs

```bash
# Server logs
tail -f ./lightway/logs/server.log

# Docker logs
docker-compose logs -f rmada-server | grep lightway

# System logs (Linux)
journalctl -u lightway -f
```

### Metrics

```bash
# Check via Prometheus (if enabled)
curl http://localhost:9090/metrics | grep lightway

# Manual stats
curl -k https://localhost:8443/api/lightway-stats | jq
```

---

## Testing

### Test Server Connectivity

```bash
# From client machine
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/YOUR_SERVER_IP/1024'
echo $?  # 0 = success, 1 = failed

# More verbose
telnet YOUR_SERVER_IP 1024
```

### Test VPN Tunnel

```bash
# Check if connected
ping 10.1.0.1

# Check full route
traceroute 10.1.0.1

# Bandwidth test
iperf3 -c 10.1.0.1 -P 4 -R
```

### Test Dilithium Auth

```bash
# Verify signatures
curl -k https://localhost:8443/api/verify-dilithium \
  -H "Content-Type: application/json" \
  -d '{
    "public_key": "<client_pub_key>",
    "signature": "<signature>",
    "message": "<message>"
  }' | jq
```

---

## Migration from WireGuard to Lightway

### Step 1: Enable Lightway Server

```bash
# Lightway already runs alongside WireGuard
# Both can coexist
ps aux | grep -E "lightway|wg"
```

### Step 2: Migrate Clients

```bash
# Get Lightway config from server
curl -k https://localhost:8443/api/lightway-client-key \
  -d '{"client_id":"my-client"}' | jq '.config' > ~/rmada.conf

# Disconnect from WireGuard
sudo wg-quick down rmada

# Connect to Lightway
sudo lightway-client --config ~/rmada.conf --up
```

### Step 3: Verify

```bash
# Check Lightway connection
ping 10.1.0.1

# Check WireGuard is down
ip link show | grep wg
```

### Step 4: Disable WireGuard (Optional)

```bash
sudo systemctl stop wg-quick@rmada
sudo systemctl disable wg-quick@rmada
```

---

## Next Steps

- **Mobile**: See MOBILE-GUIDE.md for iOS/Android setup
- **HTTPS**: See HTTPS-SETUP.md for certificate management
- **Database**: See DATABASE.md for peer management

---

**Status**: Lightway VPN ready for deployment  
**Next**: Mobile client guidance in MOBILE-GUIDE.md
