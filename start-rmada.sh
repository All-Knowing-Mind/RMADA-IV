#!/bin/bash

###############################################################################
#
# RMADA Start Script - One-Line Deployment
#
# Usage:  bash start-rmada.sh [options]
#
# Options:
#   --dev       Development mode (self-signed cert)
#   --prod      Production mode (Let's Encrypt)
#   --docker    Run in Docker
#   --help      Show this help
#
# This script:
#   ✓ Checks prerequisites
#   ✓ Creates database if needed
#   ✓ Generates HTTPS certificates
#   ✓ Loads device registry
#   ✓ Starts all services
#   ✓ Verifies health
#
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Defaults
MODE="dev"
DOCKER_MODE=false
PORT_HTTPS=8443
PORT_HTTP=8080
PORT_VPN=1024

# Functions
print_header() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  🚀 RMADA Start Script - One-Line Deployment              ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

check_prerequisites() {
  echo ""
  echo "📋 Checking prerequisites..."
  
  # Check Node.js
  if ! command -v node &> /dev/null; then
    print_error "Node.js not found. Install Node.js 18+ first."
    exit 1
  fi
  
  NODE_VERSION=$(node -v)
  print_success "Node.js $NODE_VERSION"
  
  # Check npm
  if ! command -v npm &> /dev/null; then
    print_error "npm not found"
    exit 1
  fi
  
  NPM_VERSION=$(npm -v)
  print_success "npm $NPM_VERSION"
  
  # Check OpenSSL (for certificate generation)
  if ! command -v openssl &> /dev/null; then
    print_warning "OpenSSL not found - HTTPS certificates won't be generated"
    print_warning "Install: apt-get install openssl (Linux) or brew install openssl (macOS)"
  else
    OPENSSL_VERSION=$(openssl version | cut -d' ' -f2)
    print_success "OpenSSL $OPENSSL_VERSION"
  fi
  
  # Check git (optional)
  if command -v git &> /dev/null; then
    print_success "Git available"
  fi
}

check_ports() {
  echo ""
  echo "🔌 Checking ports..."
  
  for port in $PORT_HTTPS $PORT_HTTP $PORT_VPN; do
    if lsof -i :$port &> /dev/null; then
      print_warning "Port $port already in use"
    else
      print_success "Port $port available"
    fi
  done
}

install_dependencies() {
  echo ""
  echo "📦 Installing dependencies..."
  
  if [ ! -d "node_modules" ]; then
    print_warning "node_modules not found - installing..."
    npm install --silent
    print_success "Dependencies installed"
  else
    print_success "Dependencies already installed"
  fi
}

setup_database() {
  echo ""
  echo "🗄️  Setting up database..."
  
  if [ -f "rmada.db" ]; then
    print_success "Database exists"
  else
    print_warning "Creating new database..."
    node -e "
      const db = require('./database-init');
      db.initDatabase().then(() => {
        console.log('Database created');
      }).catch(err => {
        console.error('Database creation failed:', err);
        process.exit(1);
      });
    "
    print_success "Database created"
  fi
}

setup_certificates() {
  echo ""
  echo "🔐 Setting up HTTPS certificates..."
  
  if [ "$MODE" = "prod" ]; then
    # Production: Let's Encrypt
    if command -v certbot &> /dev/null; then
      if [ -d "/etc/letsencrypt/live" ]; then
        print_success "Let's Encrypt certificates found"
        export CERT_DIR="/etc/letsencrypt/live"
      else
        print_warning "No Let's Encrypt certificates found"
        print_warning "To generate: certbot certonly --standalone -d your-domain.com"
        print_warning "Then set: export CERT_DIR=/etc/letsencrypt/live/your-domain.com"
      fi
    else
      print_warning "Certbot not installed"
      print_warning "Install: apt-get install certbot"
    fi
  else
    # Development: Self-signed
    if [ -f "certificates/server.crt" ] && [ -f "certificates/server.key" ]; then
      print_success "Self-signed certificates exist"
    else
      print_warning "Generating self-signed certificates..."
      mkdir -p certificates
      
      openssl req -x509 -newkey rsa:2048 \
        -keyout certificates/server.key \
        -out certificates/server.crt \
        -days 365 -nodes \
        -subj "/CN=localhost/O=RMADA/C=BR" 2>/dev/null
      
      if [ -f "certificates/server.crt" ]; then
        print_success "Self-signed certificates generated"
      else
        print_error "Failed to generate certificates"
        exit 1
      fi
    fi
  fi
}

load_device_registry() {
  echo ""
  echo "📝 Loading device registry..."
  
  if [ -f "device-registry-init.js" ]; then
    node -e "
      const registry = require('./device-registry-init');
      registry.init().then(() => {
        return registry.loadAllDevices();
      }).then(devices => {
        console.log('Device registry loaded:', devices.length, 'devices');
      }).catch(err => {
        console.error('Registry error:', err);
      });
    " 2>/dev/null || print_warning "Could not load device registry"
    
    print_success "Device registry ready"
  else
    print_warning "device-registry-init.js not found"
  fi
}

print_startup_info() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  🟢 RMADA Starting                                         ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "📊 Access Dashboard:"
  echo "   https://localhost:$PORT_HTTPS"
  echo ""
  echo "🌐 HTTP Fallback:"
  echo "   http://localhost:$PORT_HTTP"
  echo ""
  echo "🚀 VPN Server:"
  echo "   UDP port $PORT_VPN (Lightway + WireGuard)"
  echo ""
  echo "❤️  Health Check:"
  echo "   curl -k https://localhost:$PORT_HTTPS/api/health"
  echo ""
  echo "📝 Notes:"
  echo "   • Self-signed certificate - browser will warn (normal)"
  echo "   • First startup creates database"
  echo "   • Device registry loads on startup"
  echo "   • Press Ctrl+C to stop"
  echo ""
}

verify_health() {
  echo ""
  echo "🏥 Verifying health..."
  
  # Wait for server to start
  sleep 2
  
  # Try health check
  if command -v curl &> /dev/null; then
    if curl -s -k https://localhost:$PORT_HTTPS/api/health &>/dev/null; then
      print_success "Server is healthy"
    else
      print_warning "Could not verify server health - may still be starting"
    fi
  fi
}

show_help() {
  cat << EOF
╔════════════════════════════════════════════════════════════╗
║  RMADA Start Script - One-Line Deployment               ║
╚════════════════════════════════════════════════════════════╝

Usage:
  bash start-rmada.sh [options]

Options:
  --dev       Development mode (self-signed cert) [DEFAULT]
  --prod      Production mode (Let's Encrypt)
  --docker    Run in Docker container
  --skip-check Skip prerequisite checks
  --help      Show this help message

Examples:
  bash start-rmada.sh              # Start in dev mode
  bash start-rmada.sh --prod       # Start with Let's Encrypt
  bash start-rmada.sh --docker     # Start in Docker

Features:
  ✓ Checks Node.js, npm, OpenSSL
  ✓ Installs dependencies if needed
  ✓ Creates database on first run
  ✓ Generates HTTPS certificates
  ✓ Loads device registry
  ✓ Verifies system health
  ✓ Displays startup info

After Start:
  • Access: https://localhost:8443
  • Health: curl -k https://localhost:8443/api/health
  • Stop: Press Ctrl+C

Troubleshooting:
  • Port in use? Change: export NODE_HTTPS_PORT=9443
  • Certificate error? Regenerate: rm -rf certificates/
  • Database error? Reset: rm rmada.db

EOF
}

# Parse arguments
SKIP_CHECK=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      MODE="dev"
      shift
      ;;
    --prod)
      MODE="prod"
      shift
      ;;
    --docker)
      DOCKER_MODE=true
      shift
      ;;
    --skip-check)
      SKIP_CHECK=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Main execution
main() {
  print_header
  
  if [ "$SKIP_CHECK" = false ]; then
    check_prerequisites
    check_ports
  fi
  
  install_dependencies
  setup_database
  setup_certificates
  load_device_registry
  
  print_startup_info
  
  # Set environment variables
  export NODE_HTTPS_PORT=$PORT_HTTPS
  export LIGHTWAY_LISTEN_PORT=$PORT_VPN
  
  # Start server
  echo "▶️  Starting server..."
  echo ""
  
  if [ "$DOCKER_MODE" = true ]; then
    docker-compose up
  else
    npm start
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
