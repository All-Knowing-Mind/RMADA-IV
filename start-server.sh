#!/usr/bin/env bash
# start-server.sh — Script de inicialização rápida para RMADA
# Uso: ./start-server.sh [docker|node]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE=${1:-docker}

echo "================================================"
echo "RMADA — Monitoramento IoT com VPN Seguro"
echo "Stage 1 — Iniciando em modo: $MODE"
echo "================================================"
echo ""

# Carregar variáveis de ambiente se existirem
if [ -f .env ]; then
  echo "✓ Carregando .env"
  export $(cat .env | grep -v '^#' | xargs)
else
  echo "⚠ .env não encontrado. Usando defaults."
  echo "  (Copie .env.example para .env para customizar)"
fi

# Função para iniciar via Docker Compose
start_docker() {
  echo "🐳 Iniciando com Docker Compose..."
  
  if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo "❌ Docker ou Docker Compose não está instalado."
    echo "   Instale em: https://docs.docker.com/get-docker/"
    exit 1
  fi

  # Verificar se usa "docker compose" (v2) ou "docker-compose" (v1)
  if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    COMPOSE_CMD="docker compose"
  fi

  echo "  Executando: $COMPOSE_CMD up -d"
  $COMPOSE_CMD up -d

  echo ""
  echo "✓ Serviços iniciados!"
  echo "  📊 Dashboard: http://localhost:8080"
  echo "  🔍 Logs: $COMPOSE_CMD logs -f rmada-server"
  echo "  🛑 Parar: $COMPOSE_CMD down"
  echo ""
}

# Função para iniciar via Node direto
start_node() {
  echo "🚀 Iniciando com Node.js direto..."
  
  if ! command -v node &> /dev/null; then
    echo "❌ Node.js não está instalado."
    echo "   Instale em: https://nodejs.org"
    exit 1
  fi

  echo "  Versão Node: $(node --version)"
  echo ""

  # Verificar se dependências estão instaladas
  if [ ! -d node_modules ]; then
    echo "  📦 Instalando dependências npm..."
    npm install
  fi

  # Tentar build do Dilithium verifier se não existir
  if [ ! -f meu_projeto_dilithium/target/release/meu_projeto_dilithium ] && \
     [ ! -f meu_projeto_dilithium/target/release/meu_projeto_dilithium.exe ]; then
    echo "  🔨 Compilando verificador Dilithium (primeira vez, pode levar ~1 min)..."
    if command -v npm &> /dev/null; then
      npm run build:dilithium || echo "⚠ Build Dilithium falhou (OpenSSL/Rust necessário)"
    fi
  fi

  # Gerar chaves se não existirem
  if [ ! -f keys/server.crt ]; then
    echo "  🔑 Gerando certificados OpenSSL..."
    bash generate_keys.sh --outdir ./keys
  fi

  # Gerar config WireGuard se não existir
  if [ ! -f wg-config/wg0.conf ]; then
    echo "  🔧 Gerando configuração WireGuard..."
    bash generate_wg_config.sh --outdir ./wg-config
  fi

  echo ""
  echo "  Iniciando servidor Node..."
  echo "  📊 Dashboard: http://localhost:8080"
  echo "  🔍 Logs ao vivo (Ctrl+C para parar)"
  echo ""

  # Iniciar servidor
  node server.js
}

# Executar baseado no modo
case "$MODE" in
  docker)
    start_docker
    ;;
  node)
    start_node
    ;;
  *)
    echo "Uso: $0 [docker|node]"
    echo ""
    echo "  docker — Usar Docker Compose (recomendado)"
    echo "  node   — Usar Node.js direto (requer Node.js + Rust instalados)"
    exit 1
    ;;
esac

echo "✨ RMADA Stage 1 — Operacional!"
