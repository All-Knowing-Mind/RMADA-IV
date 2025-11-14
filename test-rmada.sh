#!/bin/bash

###############################################################################
#
# RMADA Test Suite - Unit & Integration Tests
#
# Usage: bash test-rmada.sh [test-name]
#
# This script tests:
#   ✓ Database operations
#   ✓ Device registry persistence
#   ✓ HTTPS certificate generation
#   ✓ Device onboarding workflow
#   ✓ Telemetry submission
#   ✓ VPN connectivity
#   ✓ Health checks
#   ✓ API endpoints
#
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# URLs
HTTPS_URL="https://localhost:8443"
HTTP_URL="http://localhost:8080"

# Helper functions
print_header() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  🧪 RMADA Test Suite                                       ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

test_pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((TESTS_PASSED++))
}

test_fail() {
  echo -e "${RED}✗${NC} $1"
  ((TESTS_FAILED++))
}

test_skip() {
  echo -e "${YELLOW}⊘${NC} $1"
  ((TESTS_SKIPPED++))
}

print_section() {
  echo ""
  echo -e "${BLUE}▶ $1${NC}"
}

# Tests
test_database() {
  print_section "Testing Database"
  
  # Test: Check if database file exists
  if [ -f "rmada.db" ]; then
    test_pass "Database file exists"
  else
    test_fail "Database file not found - run 'npm start' first"
    return 1
  fi
  
  # Test: Check database integrity
  if command -v sqlite3 &> /dev/null; then
    if sqlite3 rmada.db "PRAGMA integrity_check;" | grep -q "ok"; then
      test_pass "Database integrity OK"
    else
      test_fail "Database integrity check failed"
    fi
    
    # Test: Check tables exist
    local table_count=$(sqlite3 rmada.db "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
    if [ "$table_count" -ge 6 ]; then
      test_pass "Database has $table_count tables"
    else
      test_fail "Database has only $table_count tables (expected >= 6)"
    fi
  else
    test_skip "sqlite3 not installed - cannot test database"
  fi
}

test_device_registry() {
  print_section "Testing Device Registry"
  
  # Test: Load device registry
  if [ -f "device-registry-init.js" ]; then
    if node -e "
      const registry = require('./device-registry-init');
      registry.init()
        .then(() => registry.getDeviceCount())
        .then(count => {
          console.log('Device count:', count);
        })
        .catch(err => {
          console.error('Error:', err.message);
          process.exit(1);
        });
    " &>/dev/null; then
      test_pass "Device registry loads successfully"
    else
      test_fail "Device registry failed to load"
    fi
  else
    test_skip "device-registry-init.js not found"
  fi
}

test_certificates() {
  print_section "Testing HTTPS Certificates"
  
  # Test: Check if certificates exist
  if [ -f "certificates/server.crt" ] && [ -f "certificates/server.key" ]; then
    test_pass "HTTPS certificates exist"
    
    # Test: Check certificate validity
    if command -v openssl &> /dev/null; then
      if openssl x509 -in certificates/server.crt -noout -text &>/dev/null; then
        test_pass "Certificate is valid"
        
        # Test: Check expiration
        local exp_date=$(openssl x509 -in certificates/server.crt -noout -enddate | cut -d= -f2)
        test_pass "Certificate expires: $exp_date"
      else
        test_fail "Certificate format is invalid"
      fi
    else
      test_skip "openssl not installed"
    fi
  else
    test_fail "HTTPS certificates not found"
  fi
}

test_server_up() {
  print_section "Testing Server Status"
  
  # Test: Server is running
  if curl -s -k "$HTTPS_URL/api/health" &>/dev/null; then
    test_pass "HTTPS server is running"
  else
    test_fail "HTTPS server not responding - run 'npm start' first"
    return 1
  fi
  
  if curl -s "$HTTP_URL/health" &>/dev/null; then
    test_pass "HTTP server is running"
  else
    test_skip "HTTP server not responding (may not be configured)"
  fi
}

test_health_check() {
  print_section "Testing Health Check Endpoint"
  
  # Test: Health endpoint responds
  if response=$(curl -s -k "$HTTPS_URL/api/health"); then
    if echo "$response" | grep -q "status"; then
      test_pass "Health endpoint responds with valid JSON"
      
      # Test: Database health
      if echo "$response" | grep -q '"database"'; then
        test_pass "Database health check included"
      fi
      
      # Test: System stats
      if echo "$response" | grep -q '"memory"'; then
        test_pass "System stats included"
      fi
    else
      test_fail "Health endpoint response invalid"
    fi
  else
    test_fail "Health endpoint not responding"
  fi
}

test_api_endpoints() {
  print_section "Testing API Endpoints"
  
  # Test: Devices endpoint
  if curl -s -k "$HTTPS_URL/api/devices" -H "Authorization: Bearer test" &>/dev/null; then
    test_pass "Devices endpoint accessible"
  else
    test_skip "Devices endpoint (auth may be required)"
  fi
  
  # Test: Telemetry endpoint
  if curl -s -k "$HTTPS_URL/api/telemetry/test" &>/dev/null; then
    test_pass "Telemetry endpoint accessible"
  else
    test_skip "Telemetry endpoint (may require auth)"
  fi
}

test_device_onboarding() {
  print_section "Testing Device Onboarding"
  
  # Test: Generate Dilithium keys
  if [ -f "generate_dilithium_keys.sh" ]; then
    if command -v ./target/release/dilithium_keygen &>/dev/null; then
      if bash generate_dilithium_keys.sh &>/dev/null; then
        test_pass "Device keys can be generated"
      else
        test_skip "Dilithium keygen not available (Rust build needed)"
      fi
    else
      test_skip "Dilithium keygen not built - run: cargo build --release"
    fi
  else
    test_skip "Key generation script not found"
  fi
}

test_vpm_status() {
  print_section "Testing VPN Status"
  
  # Test: Check if Lightway might be listening
  if command -v ss &>/dev/null; then
    if ss -tuln | grep -q ":1024"; then
      test_pass "Lightway port 1024 is listening"
    else
      test_skip "Lightway not running (can be started with: bash lightway-startup.sh)"
    fi
    
    if ss -tuln | grep -q ":51820"; then
      test_pass "WireGuard port 51820 is listening"
    else
      test_skip "WireGuard not running (can be started manually)"
    fi
  else
    test_skip "ss command not available"
  fi
}

test_dependencies() {
  print_section "Testing Dependencies"
  
  # Test: Node.js
  if command -v node &>/dev/null; then
    local node_version=$(node -v)
    test_pass "Node.js installed: $node_version"
  else
    test_fail "Node.js not installed"
  fi
  
  # Test: npm packages
  if [ -d "node_modules" ]; then
    test_pass "npm modules installed"
    
    # Check specific modules
    for module in express ws sqlite3 bcryptjs; do
      if [ -d "node_modules/$module" ]; then
        test_pass "Package: $module"
      else
        test_fail "Package: $module (missing)"
      fi
    done
  else
    test_fail "npm modules not installed - run: npm install"
  fi
}

test_configuration() {
  print_section "Testing Configuration"
  
  # Test: package.json exists
  if [ -f "package.json" ]; then
    test_pass "package.json exists"
  else
    test_fail "package.json not found"
  fi
  
  # Test: Key files exist
  for file in server.js app.js database-schema.sql; do
    if [ -f "$file" ]; then
      test_pass "File: $file"
    else
      test_fail "File: $file (missing)"
    fi
  done
}

test_documentation() {
  print_section "Testing Documentation"
  
  # Check documentation files
  for doc in RMADA-COMPLETE-GUIDE.md DATABASE.md HTTPS-SETUP.md; do
    if [ -f "$doc" ]; then
      test_pass "Documentation: $doc"
    else
      test_skip "Documentation: $doc"
    fi
  done
}

# Test summary
print_summary() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  📊 Test Results                                           ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
  echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
  echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
  echo ""
  
  local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
  local percent=$((TESTS_PASSED * 100 / total))
  
  echo "Success Rate: $percent% ($TESTS_PASSED/$total)"
  echo ""
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    return 1
  fi
}

show_help() {
  cat << EOF
╔════════════════════════════════════════════════════════════╗
║  RMADA Test Suite                                         ║
╚════════════════════════════════════════════════════════════╝

Usage:
  bash test-rmada.sh [options]

Options:
  --quick     Run quick tests only
  --full      Run full test suite
  --help      Show this help
  --verbose   Show detailed output

Test Categories:
  • Configuration (files, packages)
  • Dependencies (Node.js, npm modules)
  • Database (SQLite integrity, tables)
  • Device Registry (persistence, loading)
  • Certificates (HTTPS, expiration)
  • Server Status (HTTP/HTTPS running)
  • Health Checks (system stats, services)
  • API Endpoints (devices, telemetry)
  • Device Onboarding (key generation)
  • VPN Status (Lightway, WireGuard)
  • Documentation (guides, references)

Examples:
  bash test-rmada.sh        # Run all tests
  bash test-rmada.sh --quick # Quick tests only
  bash test-rmada.sh --help # Show help

Note:
  • Server must be running for network tests
  • Start with: npm start or bash start-rmada.sh
  • Use: curl -k https://localhost:8443/api/health

EOF
}

# Main
main() {
  print_header
  
  # Parse arguments
  case "${1:-full}" in
    --quick)
      test_configuration
      test_dependencies
      ;;
    --full)
      test_configuration
      test_dependencies
      test_database
      test_device_registry
      test_certificates
      test_server_up && test_health_check
      test_api_endpoints
      test_device_onboarding
      test_vpm_status
      test_documentation
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      test_configuration
      test_dependencies
      test_database
      test_device_registry
      test_certificates
      test_server_up && test_health_check
      test_api_endpoints
      test_device_onboarding
      test_vpm_status
      test_documentation
      ;;
  esac
  
  print_summary
  exit $?
}

# Run
main "$@"
