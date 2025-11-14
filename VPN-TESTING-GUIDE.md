# 🧪 VPN Testing Guide — Verificar se tudo funciona

## ⚡ Quick Test (5 minutos)

### 1️⃣ Verificar Prerequisites

```bash
# OpenSSL
openssl version
# Expected: OpenSSL 1.1.x or 3.x

# WireGuard
wg --version
# Expected: wireguard-tools v1.x.x

# Node.js
node --version
# Expected: v18.x or higher

# npm
npm list

# Rust binaries
ls -la ./target/release/dilithium_*
ls -la ./target/release/sign
```

### 2️⃣ Gerar Chaves (1 min)

```bash
# WireGuard
./generate_wg_config.sh
# ✅ Creates: ./wg-config/wg0.conf

# Dilithium
./generate_dilithium_keys.sh
# ✅ Creates: ./dilithium_keys/public.key
```

### 3️⃣ Iniciar Servidor (1 min)

```bash
npm start

# ✅ Output esperado:
# [2024-01-15T10:30:00] Server listening on port 8080
# [2024-01-15T10:30:00] WebSocket ready
# [2024-01-15T10:30:01] Device registry loaded
```

### 4️⃣ Verificar Health (1 min)

```bash
# Em outro terminal
curl http://localhost:8080/api/health

# ✅ Esperado:
# {"status":"ok","timestamp":"2024-01-15T10:30:05Z"}
```

### 5️⃣ Login Owner (1 min)

```bash
curl -X POST http://localhost:8080/api/register-owner \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "test123",
    "ownerCode": "OWNER_CODE_HERE"
  }'

# ✅ Esperado:
# {"token":"eyJhbGc...","role":"owner"}

# Salvar token
export TOKEN="eyJhbGc..."
```

### 6️⃣ Test Device Onboarding (1 min)

```bash
# Gerar chaves do "dispositivo"
wg genkey | tee test-device.key | wg pubkey > test-device.pub
WG_PUB=$(cat test-device.pub)

# Assinar deviceId
./sign -m "test-lora-001" \
       -k ./dilithium_keys/private.key \
       > test-signature.sig

SIG=$(base64 test-signature.sig)
DILITHIUM_PUB=$(cat ./dilithium_keys/public.key | head -c 100)

# Enviar onboarding request
curl -X POST http://localhost:8080/api/device-onboard \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"deviceId\": \"test-lora-001\",
    \"wg_pubkey\": \"$WG_PUB\",
    \"dilithium_pubkey\": \"$DILITHIUM_PUB\",
    \"dilithium_signature\": \"$SIG\"
  }"

# ✅ Esperado:
# {
#   "status": "onboarded",
#   "deviceId": "test-lora-001",
#   "wg_ip": "10.0.0.2",
#   "server_address": "10.0.0.1",
#   "server_port": 51820
# }
```

---

## 📊 Full Test Suite

### Test 1: WireGuard CLI Test

```bash
#!/bin/bash
echo "=== Testing WireGuard CLI ==="

# Generate keys
wg genkey | tee test.key | wg pubkey > test.pub

# Display keys
echo "✅ Generated keys:"
echo "   Private: $(cat test.key | head -c 20)..."
echo "   Public:  $(cat test.pub)"

# Test with wg command
wg show 2>&1 | grep -q "interface" && \
  echo "✅ 'wg show' works" || \
  echo "❌ 'wg show' failed"

echo ""
```

### Test 2: OpenSSL Test

```bash
#!/bin/bash
echo "=== Testing OpenSSL ==="

# Generate RSA key
openssl genrsa -out test.key 2048 2>/dev/null && \
  echo "✅ RSA key generation works" || \
  echo "❌ Failed"

# Generate certificate
openssl req -new -x509 -key test.key -out test.crt -days 365 \
  -subj "/CN=test" 2>/dev/null && \
  echo "✅ Certificate generation works" || \
  echo "❌ Failed"

# View certificate
openssl x509 -in test.crt -noout -dates 2>/dev/null && \
  echo "✅ Certificate validation works" || \
  echo "❌ Failed"

echo ""
```

### Test 3: Dilithium Test

```bash
#!/bin/bash
echo "=== Testing Dilithium ==="

# Generate keypair
if [ ! -f ./dilithium_keys/public.key ]; then
  ./generate_dilithium_keys.sh
fi

# Sign message
./sign -m "test message" \
       -k ./dilithium_keys/private.key \
       > test.sig 2>/dev/null && \
  echo "✅ Dilithium signing works" || \
  echo "❌ Failed"

# Verify signature
./dilithium_verify -p ./dilithium_keys/public.key \
                   -m "test message" \
                   -s test.sig 2>/dev/null && \
  echo "✅ Dilithium verification works" || \
  echo "❌ Failed"

echo ""
```

### Test 4: Server API Test

```bash
#!/bin/bash
echo "=== Testing Server API ==="

BASE_URL="http://localhost:8080"

# Health check
curl -s "$BASE_URL/api/health" | grep -q "ok" && \
  echo "✅ Health check passes" || \
  echo "❌ Health check failed"

# Register owner
RESPONSE=$(curl -s -X POST "$BASE_URL/api/register-owner" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123",
    "ownerCode": "TEST_CODE"
  }')

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
if [ ! -z "$TOKEN" ]; then
  echo "✅ Owner registration works (token: ${TOKEN:0:20}...)"
else
  echo "❌ Owner registration failed"
fi

# Login test
curl -s -X POST "$BASE_URL/api/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}' | grep -q "token" && \
  echo "✅ Login works" || \
  echo "❌ Login failed"

echo ""
```

### Test 5: VPN Connection Test

```bash
#!/bin/bash
echo "=== Testing VPN Connection ==="

# Check if WireGuard interface exists
sudo ip link show | grep -q "wg0" && \
  echo "✅ WireGuard interface active" || \
  echo "⚠️  WireGuard interface not running"

# Check IP allocation
ip addr show | grep -q "10.0.0" && \
  echo "✅ VPN IP allocated" || \
  echo "⚠️  No VPN IP"

# Ping test
ping -c 1 10.0.0.1 2>/dev/null && \
  echo "✅ VPN ping works" || \
  echo "⚠️  VPN ping failed"

echo ""
```

### Test 6: Docker Build Test

```bash
#!/bin/bash
echo "=== Testing Docker Build ==="

# Build image
docker build -t rmada-test:latest . 2>&1 | tail -5 && \
  echo "✅ Docker build successful" || \
  echo "❌ Docker build failed"

# Check image
docker images | grep rmada-test && \
  echo "✅ Docker image exists" || \
  echo "❌ Docker image not found"

echo ""
```

---

## 🔍 Diagnostic Commands

### Check All Components

```bash
#!/bin/bash
echo "╔════════════════════════════════════════════════════════╗"
echo "║     RMADA VPN System Diagnostic Report                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# 1. OpenSSL
echo "[1] OpenSSL Status:"
openssl version && echo "    ✅ Installed" || echo "    ❌ Missing"

# 2. WireGuard
echo "[2] WireGuard Status:"
wg --version && echo "    ✅ Installed" || echo "    ❌ Missing"

# 3. Node.js
echo "[3] Node.js Status:"
node --version && echo "    ✅ Installed" || echo "    ❌ Missing"

# 4. Dilithium Binaries
echo "[4] Dilithium Binaries:"
for bin in dilithium_keygen dilithium_verify sign; do
  [ -f "./target/release/$bin" ] && echo "    ✅ $bin" || echo "    ❌ $bin missing"
done

# 5. Dependencies
echo "[5] npm Dependencies:"
npm list 2>/dev/null | head -10

# 6. Ports
echo "[6] Port Availability:"
echo "    Port 8080 (HTTP):"
netstat -tuln 2>/dev/null | grep 8080 && echo "      ✅ In use" || echo "      ⚠️  Available"
echo "    Port 51820 (WireGuard):"
netstat -tuln 2>/dev/null | grep 51820 && echo "      ✅ In use" || echo "      ⚠️  Available"

# 7. Files
echo "[7] Key Files:"
[ -f "./keys/server.key" ] && echo "    ✅ server.key" || echo "    ❌ server.key missing"
[ -f "./keys/server.crt" ] && echo "    ✅ server.crt" || echo "    ❌ server.crt missing"
[ -f "./wg-config/wg0.conf" ] && echo "    ✅ wg0.conf" || echo "    ❌ wg0.conf missing"
[ -f "./dilithium_keys/public.key" ] && echo "    ✅ dilithium_keys" || echo "    ❌ dilithium_keys missing"
[ -f "./rmada.db" ] && echo "    ✅ rmada.db" || echo "    ❌ rmada.db missing"

# 8. Permissions
echo "[8] Permissions:"
[ -x "./generate_wg_config.sh" ] && echo "    ✅ generate_wg_config.sh executable" || echo "    ❌ Not executable"
[ -x "./add_peer.sh" ] && echo "    ✅ add_peer.sh executable" || echo "    ❌ Not executable"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Diagnostic Complete                       ║"
echo "╚════════════════════════════════════════════════════════╝"
```

---

## 📋 Test Checklist

```
VPN System Tests:

[ ] OpenSSL installed
    Command: openssl version

[ ] WireGuard tools installed
    Command: wg --version

[ ] Node.js 18+ installed
    Command: node --version

[ ] Dilithium binaries compiled
    Command: ls -la ./target/release/dilithium_*

[ ] Server starts without errors
    Command: npm start

[ ] Health check responds
    Command: curl http://localhost:8080/api/health

[ ] Owner registration works
    Command: curl -X POST /api/register-owner

[ ] Device onboarding works
    Command: curl -X POST /api/device-onboard

[ ] WireGuard interface configurable
    Command: wg-quick up ./wg0.conf

[ ] Docker builds successfully
    Command: docker build .

[ ] Database persists devices
    Command: sqlite3 rmada.db "SELECT COUNT(*) FROM devices"

[ ] SQLite registry module works
    Command: node -e "require('./device-registry-init')"

[ ] Health checks respond
    Command: curl /api/health

[ ] All integration tests pass
    Command: npm test
```

---

## ✅ Expected Results

If all tests pass, you should see:

```
╔════════════════════════════════════════════════════════╗
║          VPN System Status: ALL GREEN                  ║
╠════════════════════════════════════════════════════════╣
║ ✅ OpenSSL       v3.x.x                                ║
║ ✅ WireGuard      v1.x.x                               ║
║ ✅ Node.js        v18.x                                ║
║ ✅ Dilithium      Ready                                ║
║ ✅ Server         Running on 8080                      ║
║ ✅ Health Check   OK                                   ║
║ ✅ Device Registry SQLite                             ║
║ ✅ Docker Build   Ready                               ║
║ ✅ VPN Interface  Configurable                        ║
║ ✅ All Tests      PASS                                ║
╚════════════════════════════════════════════════════════╝
```

---

**Document**: VPN Testing Guide  
**Updated**: November 13, 2025  
**Status**: Complete ✅
