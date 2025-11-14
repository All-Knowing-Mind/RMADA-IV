#!/usr/bin/env bash
# test-onboarding.sh — Test script para validar onboarding de dispositivo
# Uso: ./test-onboarding.sh [token] [deviceId]

set -e

TOKEN=${1:-}
DEVICE_ID=${2:-DEVICE-001}
SERVER=${SERVER:-http://localhost:8080}

if [ -z "$TOKEN" ]; then
  echo "Uso: $0 <token> [deviceId]"
  echo ""
  echo "Exemplo:"
  echo "  # 1. Registre um proprietário (ou use Defesa Civil)"
  echo "  curl -X POST $SERVER/api/register-owner \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"username\":\"admin\",\"password\":\"test\",\"ownerCode\":\"OWNER-SECRET-CHANGEME\"}'"
  echo ""
  echo "  # 2. Copie o token da resposta e execute:"
  echo "  ./test-onboarding.sh '<token>' DEVICE-001"
  exit 1
fi

echo "================================================"
echo "RMADA — Test Onboarding de Dispositivo"
echo "================================================"
echo ""
echo "Server: $SERVER"
echo "Device ID: $DEVICE_ID"
echo "Token: ${TOKEN:0:10}..."
echo ""

# Gerar chaves WireGuard de teste para o dispositivo
echo "1️⃣  Gerando chaves WireGuard de teste..."
WG_PRIV=$(wg genkey 2>/dev/null || echo "PrivateKeyPlaceholder123456789")
WG_PUB=$(echo "$WG_PRIV" | wg pubkey 2>/dev/null || echo "PublicKeyPlaceholder123456789/abcdef=")
echo "   ✓ Chaves geradas"
echo ""

# Simular chaves Dilithium (base64 fake para teste)
echo "2️⃣  Preparando dados Dilithium (simulado para teste)..."
DIL_PUB=$(echo -n "-----BEGIN PUBLIC KEY-----
test-dilithium-public-key-placeholder
-----END PUBLIC KEY-----" | base64)
DIL_SIG=$(echo -n "fake-signature-for-testing" | base64)
echo "   ✓ Dados Dilithium preparados"
echo ""

# Fazer requisição de onboarding
echo "3️⃣  Enviando requisição de onboarding..."
echo "   POST $SERVER/api/device-onboard"

RESPONSE=$(curl -s -X POST "$SERVER/api/device-onboard" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"deviceId\": \"$DEVICE_ID\",
    \"wg_pubkey\": \"$WG_PUB\",
    \"dilithium_pubkey\": \"$DIL_PUB\",
    \"dilithium_signature\": \"$DIL_SIG\"
  }")

echo ""
echo "   Resposta:"
echo "$RESPONSE" | jq . || echo "$RESPONSE"
echo ""

# Verificar se onboarding foi bem-sucedido
if echo "$RESPONSE" | jq . 2>/dev/null | grep -q '"status":"onboarded"'; then
  echo "✅ Onboarding bem-sucedido!"
  echo ""
  
  # Tentar recuperar configuração
  echo "4️⃣  Recuperando configuração WireGuard..."
  WG_CONFIG=$(curl -s -X GET "$SERVER/api/get-wg-config/$DEVICE_ID" \
    -H "Authorization: Bearer $TOKEN")
  
  echo "$WG_CONFIG" | jq . || echo "$WG_CONFIG"
  echo ""
  
  # Testar telemetria
  echo "5️⃣  Testando endpoint de telemetria..."
  TEL_RESPONSE=$(curl -s -X POST "$SERVER/api/telemetry" \
    -H "Content-Type: application/json" \
    -d "{
      \"deviceId\": \"$DEVICE_ID\",
      \"value\": 42.5,
      \"timestamp\": $(date +%s)000
    }")
  
  echo "$TEL_RESPONSE" | jq . || echo "$TEL_RESPONSE"
  echo ""
  echo "✨ Test completo!"
else
  echo "❌ Erro no onboarding. Verifique:"
  echo "   - Servidor está rodando em $SERVER?"
  echo "   - Token é válido? (Authorization: Bearer ...)"
  echo "   - Dilithium verification está habilitado? (DILITHIUM_VERIFY=1)"
  exit 1
fi
