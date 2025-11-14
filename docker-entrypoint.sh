#!/bin/bash
set -e

# docker-entrypoint.sh - prepara ambiente se necessário e inicia o servidor Node
# Nota: para usar WireGuard no container, execute o container com --cap-add=NET_ADMIN --cap-add=SYS_MODULE
# ou em modo privilegiado: --privileged

# exemplo: se houver arquivos de configuração wg0.conf em /workspace/wg-config, podemos levantar a interface
if [ -f /workspace/wg-config/wg0.conf ]; then
  echo "Carregando configuração WireGuard..."
  # copiar para /etc/wireguard
  mkdir -p /etc/wireguard
  cp /workspace/wg-config/wg0.conf /etc/wireguard/wg0.conf
  chmod 600 /etc/wireguard/wg0.conf
  # tentar levantar a interface (requer privilégios)
  if command -v wg-quick >/dev/null 2>&1; then
    echo "Ativando wg-quick@wg0 (se capacidades permitirem)..."
    wg-quick up /etc/wireguard/wg0.conf || echo "wg-quick up falhou (verifique capacidades do container)"
  fi
fi

# finalmente start do node server
exec "$@"