#!/bin/bash

################################################################################
# RMADA — Stage 2 Quick Reference & Command Cheat Sheet
#
# All essential commands for working with RMADA Stage 2 project
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  RMADA Stage 2 — Quick Reference Guide                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

################################################################################
# SETUP & BUILDING
################################################################################

echo "🔧 SETUP & BUILDING"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Install dependencies:"
echo "   \$ npm install"
echo ""
echo "2. Build Dilithium verifier (Rust):"
echo "   \$ npm run build:dilithium-all"
echo "   OR"
echo "   \$ cd meu_projeto_dilithium && cargo build --release"
echo ""
echo "3. Verify Dilithium binaries exist:"
echo "   \$ ls -la meu_projeto_dilithium/target/release/dilithium_*"
echo "   \$ ls -la meu_projeto_dilithium/target/release/sign"
echo ""
echo ""

################################################################################
# RUNNING THE SERVER
################################################################################

echo "🚀 RUNNING THE SERVER"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Option A: Direct Node.js"
echo "   \$ npm start"
echo "   → Server: http://localhost:8080"
echo "   → WebSocket: http://localhost:9000"
echo ""
echo "Option B: Docker Compose (recommended)"
echo "   \$ docker-compose up -d"
echo "   \$ docker-compose logs -f"
echo "   \$ docker-compose down"
echo ""
echo "Option C: Manual script"
echo "   \$ bash start-server.sh"
echo ""
echo ""

################################################################################
# AUTHENTICATION
################################################################################

echo "🔐 AUTHENTICATION"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Register owner:"
echo "   \$ curl -X POST http://localhost:8080/api/register-owner \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"username\":\"admin\",\"password\":\"test123\",\"ownerCode\":\"OWNER-001\"}'"
echo ""
echo "2. Save token to variable:"
echo "   \$ TOKEN=\$(curl -s -X POST http://localhost:8080/api/register-owner \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{...}' | jq -r .token)"
echo "   \$ echo \$TOKEN"
echo ""
echo "3. Login (owner or defense):"
echo "   \$ curl -X POST http://localhost:8080/api/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"username\":\"admin\",\"password\":\"test123\"}'"
echo ""
echo ""

################################################################################
# KEY GENERATION
################################################################################

echo "🔑 KEY GENERATION"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Generate Dilithium keys (script wrapper):"
echo "   \$ bash generate_dilithium_keys.sh ./my-device-keys"
echo ""
echo "2. Or use Dilithium keygen binary directly:"
echo "   \$ ./meu_projeto_dilithium/target/release/dilithium_keygen ./keys"
echo ""
echo "3. Verify keys generated:"
echo "   \$ ls -la ./my-device-keys/"
echo "   → dilithium_public.key (1952 bytes)"
echo "   → dilithium_secret.key (2560 bytes)"
echo ""
echo ""

################################################################################
# SIGNING & VERIFICATION
################################################################################

echo "✍️  SIGNING & VERIFICATION"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Create message to sign:"
echo "   \$ echo -n 'DEVICE-001' > message.txt"
echo ""
echo "2. Sign with Dilithium:"
echo "   \$ ./meu_projeto_dilithium/target/release/sign \\"
echo "     ./my-device-keys/dilithium_secret.key \\"
echo "     ./message.txt > signature.bin"
echo ""
echo "3. Verify signature:"
echo "   \$ ./meu_projeto_dilithium/target/release/dilithium_verify \\"
echo "     ./my-device-keys/dilithium_public.key \\"
echo "     ./message.txt \\"
echo "     ./signature.bin"
echo "   → Exit code 0 = valid"
echo "   → Exit code 1 = invalid"
echo "   → Exit code 2 = error"
echo ""
echo "4. Check exit code:"
echo "   \$ echo \$?"
echo ""
echo ""

################################################################################
# DEVICE ONBOARDING
################################################################################

echo "📱 DEVICE ONBOARDING"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Run device client simulator (7-step process):"
echo ""
echo "   \$ bash device-client-example.sh <server_url> <device_id> <token>"
echo ""
echo "Example:"
echo "   \$ bash device-client-example.sh http://localhost:8080 DEVICE-001 \$TOKEN"
echo ""
echo "Steps automated by script:"
echo "   1. Generate WireGuard keys"
echo "   2. Generate Dilithium keys"
echo "   3. Sign device ID"
echo "   4. Send onboarding request"
echo "   5. Retrieve WireGuard config"
echo "   6. Send telemetry (5x)"
echo "   7. Display results"
echo ""
echo "Output directory:"
echo "   → ./device-keys-\$DEVICE_ID/"
echo ""
echo ""

################################################################################
# TESTING
################################################################################

echo "🧪 TESTING"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Run full end-to-end test (builds + tests + cleanup):"
echo "   \$ bash test-stage2-e2e.sh"
echo ""
echo "2. Manual test flow:"
echo "   Terminal 1:"
echo "   \$ npm start"
echo ""
echo "   Terminal 2:"
echo "   \$ TOKEN=\$(curl -s ... | jq -r .token)"
echo "   \$ bash device-client-example.sh http://localhost:8080 TEST-001 \$TOKEN"
echo ""
echo "3. Check API responses:"
echo "   \$ curl http://localhost:8080/health"
echo "   \$ curl http://localhost:8080/api/whoami -H \"Authorization: Bearer \$TOKEN\""
echo "   \$ curl http://localhost:8080/api/devices -H \"Authorization: Bearer \$TOKEN\""
echo ""
echo ""

################################################################################
# DASHBOARD ACCESS
################################################################################

echo "📊 DASHBOARD ACCESS"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Main Dashboard (with charts):"
echo "   http://localhost:8080/Operação.html"
echo ""
echo "2. Device Management Page:"
echo "   http://localhost:8080/Dispositivo.html"
echo ""
echo "3. Login when prompted:"
echo "   Role: owner or defense"
echo "   Token: (paste from registration)"
echo ""
echo "4. Or access directly:"
echo "   http://localhost:8080/Operação.html?token=<token>"
echo ""
echo ""

################################################################################
# TELEMETRY
################################################################################

echo "📈 TELEMETRY"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Send single telemetry reading:"
echo "   \$ curl -X POST http://localhost:8080/api/telemetry \\"
echo "     -H 'Authorization: Bearer \$TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"deviceId\":\"DEVICE-001\",\"value\":42,\"timestamp\":\"2025-11-11T15:30:45Z\"}'"
echo ""
echo "2. Send multiple readings (script):"
echo "   \$ for i in {1..5}; do"
echo "       VALUE=\$((RANDOM % 100))"
echo "       curl -X POST http://localhost:8080/api/telemetry \\"
echo "         -H 'Authorization: Bearer \$TOKEN' \\"
echo "         -H 'Content-Type: application/json' \\"
echo "         -d '{\"deviceId\":\"DEVICE-001\",\"value\":\$VALUE,\"timestamp\":\"'\"'\"'$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")'\"'\"'\"}'"
echo "       sleep 1"
echo "     done"
echo ""
echo ""

################################################################################
# WIREGUARD (OPTIONAL)
################################################################################

echo "🌐 WIREGUARD (Optional)"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Generate WireGuard keys:"
echo "   \$ wg genkey | tee wg-private.key | wg pubkey > wg-public.key"
echo ""
echo "2. Generate WireGuard config:"
echo "   \$ bash generate_wg_config.sh"
echo ""
echo "3. Add peer (device):"
echo "   \$ bash add_peer.sh DEVICE-NAME <public-key>"
echo ""
echo "4. Activate WireGuard (if installed):"
echo "   \$ sudo wg-quick up ./wg0.conf"
echo ""
echo ""

################################################################################
# DOCKER DEPLOYMENT
################################################################################

echo "🐳 DOCKER DEPLOYMENT"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "1. Build Docker image:"
echo "   \$ docker build -f Dockerfile.server -t rmada:server ."
echo ""
echo "2. Or use Earthly:"
echo "   \$ earthly +complete-image"
echo ""
echo "3. Run container:"
echo "   \$ docker run -p 8080:8080 -p 9000:9000 rmada:server"
echo ""
echo "4. Using Docker Compose:"
echo "   \$ docker-compose up -d"
echo "   \$ docker-compose logs -f"
echo "   \$ docker-compose ps"
echo "   \$ docker-compose down"
echo ""
echo ""

################################################################################
# TROUBLESHOOTING
################################################################################

echo "🔧 TROUBLESHOOTING"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Problem: 'dilithium_verify: command not found'"
echo "Solution:"
echo "  \$ npm run build:dilithium-all"
echo "  \$ export PATH=\$PWD/meu_projeto_dilithium/target/release:\$PATH"
echo ""
echo "Problem: 'Port 8080 already in use'"
echo "Solution:"
echo "  \$ lsof -i :8080  # Find process"
echo "  \$ kill -9 <PID>"
echo "  Or use different port: NODE_PORT=3000 npm start"
echo ""
echo "Problem: 'npm: command not found'"
echo "Solution:"
echo "  Install Node.js from https://nodejs.org"
echo ""
echo "Problem: 'cargo: command not found'"
echo "Solution:"
echo "  \$ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
echo "  \$ source \$HOME/.cargo/env"
echo ""
echo "Problem: 'Dilithium verification failed'"
echo "Solution:"
echo "  - Verify keys are from same pair (pub/secret)"
echo "  - Check device ID is correctly signed"
echo "  - See DEVICE-CLIENT-GUIDE.md 'Troubleshooting' section"
echo ""
echo ""

################################################################################
# USEFUL LINKS
################################################################################

echo "📚 USEFUL LINKS & DOCUMENTATION"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Documentation:"
echo "  - README.md                    (project overview)"
echo "  - README-STAGE1.md             (Stage 1 features)"
echo "  - README-STAGE2.md             (Stage 2 quick start)"
echo "  - DEVICE-CLIENT-GUIDE.md       (complete device guide)"
echo "  - STAGE2-SUMMARY.md            (implementation details)"
echo "  - PROJECT-STATUS.md            (current status)"
echo ""
echo "Configuration:"
echo "  - .env.example                 (environment template)"
echo "  - docker-compose.yml           (compose config)"
echo "  - Earthfile                    (build config)"
echo ""
echo "Testing:"
echo "  - test-stage2-e2e.sh           (end-to-end test)"
echo "  - test-onboarding.sh           (onboarding test)"
echo "  - device-client-example.sh     (device simulator)"
echo ""
echo ""

################################################################################
# FINAL
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Quick Start Summary                                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. npm install"
echo "2. npm run build:dilithium-all"
echo "3. npm start"
echo "4. In another terminal:"
echo "   TOKEN=\$(curl -s -X POST ... | jq -r .token)"
echo "5. bash device-client-example.sh http://localhost:8080 DEVICE-001 \$TOKEN"
echo "6. Open http://localhost:8080/Operação.html"
echo ""
echo "Or for Docker:"
echo "1. docker-compose up -d"
echo "2. Open http://localhost:8080"
echo ""
echo ""
