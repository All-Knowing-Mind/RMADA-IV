#!/bin/bash
# test-new-security.sh
# Teste rápido do novo sistema de segurança implementado

set -e

BASE_URL="${1:-http://localhost:8080}"
OWNER_CODE="${2:-OWNER-SECRET-CHANGEME}"
DEFENSE_CODE="${3:-DEFENSE-SECRET-CHANGEME}"

echo "=========================================="
echo "RMADA — Teste do Sistema de Segurança"
echo "=========================================="
echo ""
echo "Base URL: $BASE_URL"
echo "Owner Code: $OWNER_CODE"
echo "Defense Code: $DEFENSE_CODE"
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_count=0
passed=0
failed=0

# Função para teste
run_test() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    
    test_count=$((test_count + 1))
    echo -n "[$test_count] $name... "
    
    result=$(eval "$cmd" 2>&1)
    
    if echo "$result" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASSOU${NC}"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗ FALHOU${NC}"
        echo "   Resultado: $result"
        failed=$((failed + 1))
    fi
}

echo "=== TESTES NEGATIVOS (deve falhar) ==="
echo ""

# Teste 1: Acessar /api/devices sem token
run_test "Acesso /api/devices sem token (403)" \
    "curl -s -o /dev/null -w '%{http_code}' $BASE_URL/api/devices" \
    "403"

# Teste 2: Acessar /api/chart sem token
run_test "Acesso /api/chart/D1 sem token (403)" \
    "curl -s -o /dev/null -w '%{http_code}' $BASE_URL/api/chart/D1" \
    "403"

# Teste 3: Enviar telemetria sem token
run_test "POST /api/telemetry sem token (403)" \
    "curl -s -X POST $BASE_URL/api/telemetry -H 'Content-Type: application/json' -d '{\"deviceId\":\"D1\",\"value\":42}' -o /dev/null -w '%{http_code}'" \
    "403"

# Teste 4: Registrar com código inválido
run_test "Registrar com Owner Code inválido (403)" \
    "curl -s -X POST $BASE_URL/api/register-owner -H 'Content-Type: application/json' -d '{\"username\":\"test\",\"password\":\"Test123!\",\"ownerCode\":\"WRONG_CODE\"}' | grep -o '\"error\"'"  \
    "\"error\""

echo ""
echo "=== TESTES POSITIVOS (deve funcionar) ==="
echo ""

# Teste 5: Registrar Proprietário
echo -n "[5] Registrar novo Proprietário... "
OWNER_RESPONSE=$(curl -s -X POST $BASE_URL/api/register-owner \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"testowner\",\"password\":\"TestPass123!\",\"ownerCode\":\"$OWNER_CODE\"}")

OWNER_TOKEN=$(echo "$OWNER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$OWNER_TOKEN" ]; then
    echo -e "${GREEN}✓ PASSOU${NC}"
    echo "   Token: ${OWNER_TOKEN:0:20}..."
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FALHOU${NC}"
    echo "   Resposta: $OWNER_RESPONSE"
    failed=$((failed + 1))
fi

# Teste 6: Acessar /api/devices com token proprietário
if [ -n "$OWNER_TOKEN" ]; then
    run_test "Acesso /api/devices com token proprietário (200)" \
        "curl -s -H \"Authorization: Bearer $OWNER_TOKEN\" $BASE_URL/api/devices -o /dev/null -w '%{http_code}'" \
        "200"
fi

# Teste 7: Acessar /api/chart com token proprietário
if [ -n "$OWNER_TOKEN" ]; then
    run_test "Acesso /api/chart/D1 com token proprietário (200)" \
        "curl -s -H \"Authorization: Bearer $OWNER_TOKEN\" $BASE_URL/api/chart/D1 -o /dev/null -w '%{http_code}'" \
        "200"
fi

# Teste 8: Enviar telemetria com token proprietário
if [ -n "$OWNER_TOKEN" ]; then
    run_test "POST /api/telemetry com token proprietário (200)" \
        "curl -s -X POST -H \"Authorization: Bearer $OWNER_TOKEN\" $BASE_URL/api/telemetry -H 'Content-Type: application/json' -d '{\"deviceId\":\"D1\",\"value\":42}' -o /dev/null -w '%{http_code}'" \
        "200"
fi

echo ""
echo "=== TESTE DEFESA CIVIL ==="
echo ""

# Teste 9: Login Defesa Civil
echo -n "[9] Login Defesa Civil... "
DEFENSE_RESPONSE=$(curl -s -X POST $BASE_URL/api/login-defense \
  -H 'Content-Type: application/json' \
  -d "{\"code\":\"$DEFENSE_CODE\"}")

DEFENSE_TOKEN=$(echo "$DEFENSE_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$DEFENSE_TOKEN" ]; then
    echo -e "${GREEN}✓ PASSOU${NC}"
    echo "   Token: ${DEFENSE_TOKEN:0:20}..."
    passed=$((passed + 1))
else
    echo -e "${RED}✗ FALHOU${NC}"
    echo "   Resposta: $DEFENSE_RESPONSE"
    failed=$((failed + 1))
fi

# Teste 10: Acesso leitura Defesa Civil
if [ -n "$DEFENSE_TOKEN" ]; then
    run_test "Acesso /api/chart com token Defesa Civil (200)" \
        "curl -s -H \"Authorization: Bearer $DEFENSE_TOKEN\" $BASE_URL/api/chart/D1 -o /dev/null -w '%{http_code}'" \
        "200"
fi

# Teste 11: Defesa Civil não pode enviar telemetria
if [ -n "$DEFENSE_TOKEN" ]; then
    run_test "POST /api/telemetry com token Defesa Civil (403)" \
        "curl -s -X POST -H \"Authorization: Bearer $DEFENSE_TOKEN\" $BASE_URL/api/telemetry -H 'Content-Type: application/json' -d '{\"deviceId\":\"D1\",\"value\":42}' -o /dev/null -w '%{http_code}'" \
        "403"
fi

echo ""
echo "=========================================="
echo "RESUMO DOS TESTES"
echo "=========================================="
echo -e "Total: $test_count | ${GREEN}Passou: $passed${NC} | ${RED}Falhou: $failed${NC}"

if [ $failed -eq 0 ]; then
    echo -e "\n${GREEN}✓ TODOS OS TESTES PASSARAM!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ ALGUNS TESTES FALHARAM${NC}"
    exit 1
fi
