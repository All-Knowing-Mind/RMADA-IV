#!/usr/bin/env bash
# device-client-example.sh — Example device onboarding and telemetry client
# This simulates a LoRa device connecting to RMADA and sending telemetry
#
# Usage: ./device-client-example.sh <server_url> <device_id> <token>
# Example: ./device-client-example.sh http://localhost:8080 DEVICE-001 <your-token>

set -e

SERVER_URL=${1:-http://localhost:8080}
DEVICE_ID=${2:-DEVICE-001}
TOKEN=${3:-}
WORK_DIR=${4:-.}

if [ -z "$TOKEN" ]; then
  echo "❌ Usage: $0 <server_url> <device_id> <token>"
  echo ""
  echo "Example:"
  echo "  ./device-client-example.sh http://localhost:8080 DEVICE-001 <your-token>"
  echo ""
  echo "To get a token:"
  echo "  1. Register as owner:"
  echo "     curl -X POST http://localhost:8080/api/register-owner \\"
  echo "       -H 'Content-Type: application/json' \\"
  echo "       -d '{\"username\":\"admin\",\"password\":\"test\",\"ownerCode\":\"OWNER-SECRET-CHANGEME\"}'"
  echo "  2. Copy token from response"
  echo "  3. Run this script with the token"
  exit 1
fi

echo "================================================"
echo "RMADA Device Client Example"
echo "================================================"
echo ""
echo "Server:    $SERVER_URL"
echo "Device ID: $DEVICE_ID"
echo "Token:     ${TOKEN:0:10}..."
echo ""

# Create temp directory for device keys
DEVICE_KEYS="$WORK_DIR/device-keys-$DEVICE_ID"
mkdir -p "$DEVICE_KEYS"

# Step 1: Generate device WireGuard keys (if not already present)
echo "1️⃣  Setting up WireGuard keys..."
if [ ! -f "$DEVICE_KEYS/wg_private.key" ]; then
  echo "   Generating WireGuard keypair..."
  if ! command -v wg &> /dev/null; then
    echo "   ⚠️  wg command not found; using placeholder keys"
    echo "wg_private_placeholder_$(date +%s)" > "$DEVICE_KEYS/wg_private.key"
    echo "wg_public_placeholder_$(date +%s)" > "$DEVICE_KEYS/wg_public.key"
  else
    wg genkey > "$DEVICE_KEYS/wg_private.key"
    chmod 600 "$DEVICE_KEYS/wg_private.key"
    cat "$DEVICE_KEYS/wg_private.key" | wg pubkey > "$DEVICE_KEYS/wg_public.key"
  fi
else
  echo "   ✓ Using existing WireGuard keys"
fi

WG_PUB=$(cat "$DEVICE_KEYS/wg_public.key")
echo "   ✓ WireGuard public key: $(echo $WG_PUB | cut -c1-20)..."
echo ""

# Step 2: Generate Dilithium keys (if not already present)
echo "2️⃣  Setting up Dilithium keys..."
if [ ! -f "$DEVICE_KEYS/dilithium_public.key" ]; then
  echo "   Generating Dilithium keypair..."
  bash generate_dilithium_keys.sh "$DEVICE_KEYS" 2>&1 | sed 's/^/   /'
else
  echo "   ✓ Using existing Dilithium keys"
fi
echo ""

# Step 3: Read Dilithium keys
echo "3️⃣  Reading Dilithium keys..."
DIL_PUB_HEX=$(xxd -p -c 256 "$DEVICE_KEYS/dilithium_public.key" | tr -d '\n')
DIL_SEC_HEX=$(xxd -p -c 256 "$DEVICE_KEYS/dilithium_secret.key" | tr -d '\n')
echo "   ✓ Public key length:  ${#DIL_PUB_HEX} hex chars"
echo "   ✓ Secret key length:  ${#DIL_SEC_HEX} hex chars"
echo ""

# Step 4: Sign the device ID with Dilithium
echo "4️⃣  Signing device ID with Dilithium..."
MESSAGE_FILE="$DEVICE_KEYS/message.txt"
SIGNATURE_FILE="$DEVICE_KEYS/signature.bin"
echo -n "$DEVICE_ID" > "$MESSAGE_FILE"

# Try to use the Rust sign utility (if built)
SIGN_BIN=""
for path in \
  ./meu_projeto_dilithium/target/release/sign \
  ./meu_projeto_dilithium/target/release/sign.exe; do
  if [ -x "$path" ]; then
    SIGN_BIN="$path"
    break
  fi
done

if [ -z "$SIGN_BIN" ]; then
  echo "   ⚠️  Dilithium sign binary not found; generating fake signature"
  echo "fake_signature_for_testing" > "$SIGNATURE_FILE"
  SIGNATURE_BASE64="ZmFrZV9zaWduYXR1cmVfZm9yX3Rlc3Rpbmdcbgo="
else
  "$SIGN_BIN" "$DEVICE_KEYS/dilithium_secret.key" "$MESSAGE_FILE" > "$SIGNATURE_FILE" 2>/dev/null || \
    (echo "fake_signature_for_testing" > "$SIGNATURE_FILE")
  SIGNATURE_BASE64=$(cat "$SIGNATURE_FILE" | base64 -w0)
fi

echo "   ✓ Signature created (length: ${#SIGNATURE_BASE64} chars)"
echo ""

# Step 5: Onboard device
echo "5️⃣  Sending onboarding request..."
ONBOARD_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/device-onboard" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"deviceId\": \"$DEVICE_ID\",
    \"wg_pubkey\": \"$WG_PUB\",
    \"dilithium_pubkey\": \"$DIL_PUB_HEX\",
    \"dilithium_signature\": \"$SIGNATURE_BASE64\"
  }")

echo "   Response:"
echo "$ONBOARD_RESPONSE" | jq . 2>/dev/null || echo "$ONBOARD_RESPONSE"
echo ""

# Check if onboarding was successful
if echo "$ONBOARD_RESPONSE" | grep -q '"status":"onboarded"'; then
  echo "✅ Device onboarded successfully!"
  echo ""
  
  # Step 6: Get WireGuard config
  echo "6️⃣  Retrieving WireGuard configuration..."
  WG_CONFIG=$(curl -s -X GET "$SERVER_URL/api/get-wg-config/$DEVICE_ID" \
    -H "Authorization: Bearer $TOKEN")
  
  echo "$WG_CONFIG" | jq . 2>/dev/null | head -20 || echo "$WG_CONFIG"
  echo ""
  
  # Step 7: Send telemetry
  echo "7️⃣  Sending sample telemetry..."
  for i in {1..5}; do
    VALUE=$(( 30 + RANDOM % 40 ))
    TEL_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/telemetry" \
      -H "Content-Type: application/json" \
      -d "{
        \"deviceId\": \"$DEVICE_ID\",
        \"value\": $VALUE,
        \"timestamp\": $(date +%s)000
      }")
    
    if echo "$TEL_RESPONSE" | grep -q '"status":"ok"'; then
      echo "   ✓ Telemetry #$i sent: value=$VALUE"
    else
      echo "   ✗ Telemetry #$i failed: $TEL_RESPONSE"
    fi
    
    sleep 1
  done
  
  echo ""
  echo "✨ Device client example completed!"
  echo ""
  echo "Next steps:"
  echo "  - Check dashboard at http://localhost:8080"
  echo "  - Look for '$DEVICE_ID' in the device list"
  echo "  - Device keys stored in: $DEVICE_KEYS/"
  
else
  echo "❌ Onboarding failed!"
  exit 1
fi
