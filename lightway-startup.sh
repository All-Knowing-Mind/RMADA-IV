#!/bin/bash

################################################################################
# RMADA Stage 3 — Lightway VPN Server Startup Script
# 
# Starts Lightway VPN server with Dilithium authentication
# Supports configuration via environment variables
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LIGHTWAY_LISTEN_PORT="${LIGHTWAY_LISTEN_PORT:-1024}"
LIGHTWAY_LISTEN_ADDR="${LIGHTWAY_LISTEN_ADDR:-0.0.0.0}"
LIGHTWAY_BINARY="${LIGHTWAY_BINARY:-/usr/local/bin/lightway-server}"
LIGHTWAY_CONFIG_DIR="${LIGHTWAY_CONFIG_DIR:-/etc/lightway}"
LIGHTWAY_LOG_FILE="${LIGHTWAY_LOG_FILE:-/var/log/lightway.log}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  RMADA Stage 3 — Lightway VPN Server                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# Check Prerequisites
################################################################################

echo -e "${BLUE}ℹ️  Checking prerequisites...${NC}"

# Check if Lightway binary exists
if [[ ! -f "$LIGHTWAY_BINARY" ]]; then
  echo -e "${RED}❌ Lightway binary not found: $LIGHTWAY_BINARY${NC}"
  echo "   To install Lightway, run: docker build -t rmada:lightway ."
  exit 1
fi

echo -e "${GREEN}✅ Lightway binary found${NC}"

# Check if we have permission to use specified port
if [[ $LIGHTWAY_LISTEN_PORT -lt 1024 ]] && [[ $EUID -ne 0 ]]; then
  echo -e "${RED}❌ Port $LIGHTWAY_LISTEN_PORT requires root privileges${NC}"
  exit 1
fi

# Create config directory
mkdir -p "$LIGHTWAY_CONFIG_DIR" 2>/dev/null || true
mkdir -p "$(dirname "$LIGHTWAY_LOG_FILE")" 2>/dev/null || true

echo -e "${GREEN}✅ Prerequisites verified${NC}"
echo ""

################################################################################
# Generate Lightway Server Keys (if not existing)
################################################################################

echo -e "${BLUE}ℹ️  Checking Lightway server keys...${NC}"

LIGHTWAY_PRIV_KEY="$LIGHTWAY_CONFIG_DIR/server_private.key"
LIGHTWAY_PUB_KEY="$LIGHTWAY_CONFIG_DIR/server_public.key"

if [[ ! -f "$LIGHTWAY_PRIV_KEY" ]] || [[ ! -f "$LIGHTWAY_PUB_KEY" ]]; then
  echo -e "${BLUE}🔐 Generating Lightway server keypair...${NC}"
  
  # Lightway key generation (using standard Rust Lightway crypto)
  # This would typically use the Lightway library
  # For now, generate placeholder keys
  if command -v wg &> /dev/null; then
    wg genkey | tee "$LIGHTWAY_PRIV_KEY" | wg pubkey > "$LIGHTWAY_PUB_KEY"
    chmod 600 "$LIGHTWAY_PRIV_KEY"
    echo -e "${GREEN}✅ Lightway keys generated${NC}"
  else
    echo -e "${RED}⚠️  wg-tools not found for key generation${NC}"
    echo "   Lightway keys should be pre-generated in Docker build"
  fi
else
  echo -e "${GREEN}✅ Lightway keys exist${NC}"
fi

echo ""

################################################################################
# Configure Lightway Server
################################################################################

echo -e "${BLUE}ℹ️  Configuring Lightway server...${NC}"

# Create Lightway configuration
cat > "$LIGHTWAY_CONFIG_DIR/lightway.conf" << EOF
# RMADA Stage 3 — Lightway VPN Configuration

[server]
listen_addr = $LIGHTWAY_LISTEN_ADDR
listen_port = $LIGHTWAY_LISTEN_PORT
server_private_key = $LIGHTWAY_PRIV_KEY
server_public_key = $LIGHTWAY_PUB_KEY

[auth]
# Enable Dilithium authentication
dilithium_auth = true
auth_server_url = http://localhost:8080/api/device-auth

[vpn]
# IP range for VPN clients
ip_pool_start = 10.1.0.1
ip_pool_end = 10.1.0.254
ip_subnet_mask = 255.255.255.0

[logging]
log_file = $LIGHTWAY_LOG_FILE
log_level = info
EOF

echo -e "${GREEN}✅ Configuration created: $LIGHTWAY_CONFIG_DIR/lightway.conf${NC}"
echo ""

################################################################################
# Start Lightway Server
################################################################################

echo -e "${BLUE}ℹ️  Starting Lightway VPN server...${NC}"
echo -e "${BLUE}   Listen: $LIGHTWAY_LISTEN_ADDR:$LIGHTWAY_LISTEN_PORT${NC}"
echo -e "${BLUE}   Config: $LIGHTWAY_CONFIG_DIR/lightway.conf${NC}"
echo -e "${BLUE}   Log: $LIGHTWAY_LOG_FILE${NC}"
echo ""

# Start Lightway in background with output to log
"$LIGHTWAY_BINARY" \
  --config "$LIGHTWAY_CONFIG_DIR/lightway.conf" \
  --listen "$LIGHTWAY_LISTEN_ADDR:$LIGHTWAY_LISTEN_PORT" \
  --log-file "$LIGHTWAY_LOG_FILE" \
  2>&1 | tee -a "$LIGHTWAY_LOG_FILE" &

LIGHTWAY_PID=$!
echo -e "${GREEN}✅ Lightway started (PID: $LIGHTWAY_PID)${NC}"

# Save PID for later management
echo "$LIGHTWAY_PID" > "$LIGHTWAY_CONFIG_DIR/lightway.pid"

echo ""

################################################################################
# Health Check
################################################################################

echo -e "${BLUE}ℹ️  Waiting for Lightway to be ready...${NC}"

sleep 2

# Check if process is still running
if ! kill -0 $LIGHTWAY_PID 2>/dev/null; then
  echo -e "${RED}❌ Lightway failed to start${NC}"
  tail -20 "$LIGHTWAY_LOG_FILE"
  exit 1
fi

echo -e "${GREEN}✅ Lightway is running${NC}"
echo ""

################################################################################
# Display Status
################################################################################

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Lightway VPN Server Started Successfully              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Listen Address: $LIGHTWAY_LISTEN_ADDR"
echo "  Listen Port: $LIGHTWAY_LISTEN_PORT"
echo "  Private Key: $LIGHTWAY_PRIV_KEY"
echo "  Public Key: $LIGHTWAY_PUB_KEY"
echo "  Config File: $LIGHTWAY_CONFIG_DIR/lightway.conf"
echo "  Log File: $LIGHTWAY_LOG_FILE"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Configure clients to connect to $LIGHTWAY_LISTEN_ADDR:$LIGHTWAY_LISTEN_PORT"
echo "  2. Monitor logs: tail -f $LIGHTWAY_LOG_FILE"
echo "  3. Stop server: kill $LIGHTWAY_PID"
echo ""

# Keep process running if started interactively
if [[ "${KEEP_RUNNING:-false}" == "true" ]]; then
  wait $LIGHTWAY_PID
fi
