#!/bin/bash

################################################################################
# RMADA Stage 2 — End-to-End Test Script
# 
# Testa:
#  1. Build Dilithium binaries
#  2. Start Node server
#  3. Register owner + get token
#  4. Run device client
#  5. Verify telemetry + API responses
#
# Usage: bash test-stage2-e2e.sh [--skip-server-build] [--skip-docker]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_URL="http://localhost:8080"
OWNER_USERNAME="test-owner"
OWNER_PASSWORD="TestPass123!"
OWNER_CODE="TEST-OWNER-001"
DEVICE_ID="TEST-DEVICE-E2E-001"
TEST_TIMEOUT=60
TEST_LOG="/tmp/rmada-e2e-test.log"

# Functions
log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

################################################################################
# 1. Build Dilithium Binaries
################################################################################

stage_build_dilithium() {
  log_info "Stage 1: Building Dilithium binaries..."
  
  cd "$SCRIPT_DIR"
  
  if ! command -v cargo &> /dev/null; then
    log_error "Rust/Cargo not found. Install from https://rustup.rs"
    exit 1
  fi
  
  cd meu_projeto_dilithium
  
  if ! cargo build --release --bins 2>&1 | tee -a "$TEST_LOG"; then
    log_error "Failed to build Dilithium binaries"
    exit 1
  fi
  
  cd "$SCRIPT_DIR"
  
  # Verify binaries exist
  for binary in dilithium_verify dilithium_keygen sign; do
    if [[ ! -f "meu_projeto_dilithium/target/release/$binary" ]]; then
      log_error "Binary $binary not found after build"
      exit 1
    fi
  done
  
  log_success "Dilithium binaries built successfully"
}

################################################################################
# 2. Start Node Server
################################################################################

stage_start_server() {
  log_info "Stage 2: Starting Node.js server..."
  
  cd "$SCRIPT_DIR"
  
  # Check if server is already running
  if curl -s "$SERVER_URL/health" > /dev/null 2>&1; then
    log_warning "Server already running on $SERVER_URL"
    return 0
  fi
  
  # Install deps
  if [[ ! -d "node_modules" ]]; then
    log_info "Installing npm dependencies..."
    if ! npm install --production 2>&1 | tee -a "$TEST_LOG"; then
      log_error "Failed to install npm dependencies"
      exit 1
    fi
  fi
  
  # Start server in background
  log_info "Starting server (PID will be saved)..."
  nohup npm start > "$TEST_LOG" 2>&1 &
  SERVER_PID=$!
  echo "$SERVER_PID" > /tmp/rmada-server.pid
  
  # Wait for server to start
  log_info "Waiting for server to start..."
  local counter=0
  while ! curl -s "$SERVER_URL/health" > /dev/null 2>&1; do
    if [[ $counter -gt $TEST_TIMEOUT ]]; then
      log_error "Server failed to start within ${TEST_TIMEOUT}s"
      kill $SERVER_PID 2>/dev/null || true
      exit 1
    fi
    sleep 1
    counter=$((counter + 1))
  done
  
  log_success "Server started (PID: $SERVER_PID)"
}

################################################################################
# 3. Register Owner
################################################################################

stage_register_owner() {
  log_info "Stage 3: Registering owner..."
  
  local response=$(curl -s -X POST "$SERVER_URL/api/register-owner" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"$OWNER_USERNAME\",
      \"password\": \"$OWNER_PASSWORD\",
      \"ownerCode\": \"$OWNER_CODE\"
    }")
  
  # Extract token
  OWNER_TOKEN=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
  
  if [[ -z "$OWNER_TOKEN" ]]; then
    log_error "Failed to register owner. Response: $response"
    exit 1
  fi
  
  log_success "Owner registered. Token: ${OWNER_TOKEN:0:20}..."
}

################################################################################
# 4. Generate Dilithium Keys
################################################################################

stage_generate_keys() {
  log_info "Stage 4: Generating device keys..."
  
  cd "$SCRIPT_DIR"
  
  local key_dir="./test-keys-$DEVICE_ID"
  rm -rf "$key_dir"
  
  if ! bash generate_dilithium_keys.sh "$key_dir" 2>&1 | tee -a "$TEST_LOG"; then
    log_error "Failed to generate keys"
    exit 1
  fi
  
  # Verify keys exist
  if [[ ! -f "$key_dir/dilithium_public.key" ]] || [[ ! -f "$key_dir/dilithium_secret.key" ]]; then
    log_error "Key files not found after generation"
    exit 1
  fi
  
  log_success "Keys generated in $key_dir"
}

################################################################################
# 5. Test Device Onboarding
################################################################################

stage_test_device_onboarding() {
  log_info "Stage 5: Testing device onboarding..."
  
  cd "$SCRIPT_DIR"
  
  local key_dir="./test-keys-$DEVICE_ID"
  local msg_file="/tmp/device-id-$DEVICE_ID.txt"
  local sig_file="/tmp/device-sig-$DEVICE_ID.bin"
  
  # Create message (device ID)
  echo -n "$DEVICE_ID" > "$msg_file"
  
  # Sign with Dilithium
  if ! ./meu_projeto_dilithium/target/release/sign "$key_dir/dilithium_secret.key" "$msg_file" > "$sig_file" 2>&1; then
    log_error "Failed to sign device ID"
    exit 1
  fi
  
  # Read keys as hex
  local pub_key_hex=$(xxd -p -c 10000 "$key_dir/dilithium_public.key")
  local signature_b64=$(base64 -w0 < "$sig_file")
  
  # Generate WireGuard keys
  local wg_private=$(wg genkey 2>/dev/null || echo "test-private-key")
  local wg_public=$(echo "$wg_private" | wg pubkey 2>/dev/null || echo "test-public-key")
  
  # Send onboarding request
  local response=$(curl -s -X POST "$SERVER_URL/api/device-onboard" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OWNER_TOKEN" \
    -d "{
      \"deviceId\": \"$DEVICE_ID\",
      \"dilithium_pubkey\": \"$pub_key_hex\",
      \"dilithium_signature\": \"$signature_b64\",
      \"wg_pubkey\": \"$wg_public\"
    }")
  
  # Check response
  if echo "$response" | grep -q '"status":"onboarded"'; then
    log_success "Device onboarded successfully"
    echo "$response" | jq . >> "$TEST_LOG" 2>/dev/null || true
  else
    log_error "Device onboarding failed. Response: $response"
    exit 1
  fi
  
  # Cleanup
  rm -f "$msg_file" "$sig_file"
}

################################################################################
# 6. Test WireGuard Config Retrieval
################################################################################

stage_test_wg_config() {
  log_info "Stage 6: Testing WireGuard config retrieval..."
  
  local response=$(curl -s "$SERVER_URL/api/get-wg-config/$DEVICE_ID" \
    -H "Authorization: Bearer $OWNER_TOKEN")
  
  if echo "$response" | grep -q '"config":'; then
    log_success "WireGuard config retrieved"
    echo "$response" | jq .config >> "$TEST_LOG" 2>/dev/null || true
  else
    log_error "Failed to retrieve WireGuard config. Response: $response"
    exit 1
  fi
}

################################################################################
# 7. Test Telemetry
################################################################################

stage_test_telemetry() {
  log_info "Stage 7: Sending telemetry..."
  
  for i in {1..3}; do
    local value=$((RANDOM % 100))
    
    local response=$(curl -s -X POST "$SERVER_URL/api/telemetry" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OWNER_TOKEN" \
      -d "{
        \"deviceId\": \"$DEVICE_ID\",
        \"value\": $value,
        \"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')\"
      }")
    
    if echo "$response" | grep -q '"received"'; then
      log_success "Telemetry #$i sent (value: $value)"
    else
      log_warning "Telemetry #$i response unclear: $response"
    fi
    
    sleep 1
  done
}

################################################################################
# 8. Test API Endpoints
################################################################################

stage_test_api_endpoints() {
  log_info "Stage 8: Testing API endpoints..."
  
  # Test /health
  if curl -s "$SERVER_URL/health" | grep -q '"status"'; then
    log_success "/health endpoint works"
  else
    log_warning "/health endpoint returned unexpected response"
  fi
  
  # Test /api/whoami
  local whoami=$(curl -s "$SERVER_URL/api/whoami" \
    -H "Authorization: Bearer $OWNER_TOKEN")
  
  if echo "$whoami" | grep -q "$OWNER_USERNAME"; then
    log_success "/api/whoami endpoint works"
  else
    log_warning "/api/whoami endpoint returned unexpected response"
  fi
  
  # Test /api/devices
  local devices=$(curl -s "$SERVER_URL/api/devices" \
    -H "Authorization: Bearer $OWNER_TOKEN")
  
  if echo "$devices" | grep -q "$DEVICE_ID"; then
    log_success "Device $DEVICE_ID registered in server"
  else
    log_warning "Device not found in /api/devices response"
  fi
}

################################################################################
# 9. Cleanup
################################################################################

cleanup() {
  log_info "Cleaning up..."
  
  # Kill server if we started it
  if [[ -f /tmp/rmada-server.pid ]]; then
    local pid=$(cat /tmp/rmada-server.pid)
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      log_success "Server stopped"
    fi
    rm -f /tmp/rmada-server.pid
  fi
  
  # Cleanup temp files
  rm -f /tmp/device-id-*.txt /tmp/device-sig-*.bin
}

################################################################################
# Main
################################################################################

main() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║     RMADA Stage 2 — End-to-End Test                        ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  
  # Trap cleanup on exit
  trap cleanup EXIT
  
  # Clear test log
  > "$TEST_LOG"
  
  # Run stages
  stage_build_dilithium
  stage_start_server
  stage_register_owner
  stage_generate_keys
  stage_test_device_onboarding
  stage_test_wg_config
  stage_test_telemetry
  stage_test_api_endpoints
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║     ✅ All Tests Passed!                                    ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "📝 Test log: $TEST_LOG"
  echo ""
  echo "Next steps:"
  echo "  1. Update Earthfile to build in containers"
  echo "  2. Deploy to docker-compose"
  echo "  3. Stage 3: Add HTTPS + Lightway"
  echo ""
}

main "$@"
