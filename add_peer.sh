#!/usr/bin/env bash
# add_peer.sh
# Adiciona ou atualiza um peer WireGuard no arquivo wg0.conf

set -euo pipefail

PEER_NAME=${1:-device1}
PEER_PUBKEY=${2:-}
WG_CONFIG=${3:-./wg0.conf}
PEER_IP_BASE=${4:-10.0.0}
PEER_IP_INDEX=${5:-2}

if [ -z "$PEER_PUBKEY" ]; then
  echo "Usage: $0 <peer-name> <peer-pubkey> [wg0.conf] [ip-base] [ip-index]"
  echo "Example: $0 device1 <pubkey-from-device>"
  exit 1
fi

PEER_IP="$PEER_IP_BASE.$PEER_IP_INDEX/32"

echo "Adicionando peer: $PEER_NAME com IP $PEER_IP"

# Verifica se peer já existe
if grep -q "\[Peer.*$PEER_NAME" "$WG_CONFIG" 2>/dev/null; then
  echo "Peer $PEER_NAME já existe. Atualizando..."
  # Remover seção existente (simplificado)
  sed -i "/# Peer: $PEER_NAME/,/^$/d" "$WG_CONFIG"
fi

# Adiciona novo peer
cat >> "$WG_CONFIG" <<EOF

# Peer: $PEER_NAME
[Peer]
PublicKey = $PEER_PUBKEY
AllowedIPs = $PEER_IP
EOF

echo "Peer adicionado. Arquivo atualizado: $WG_CONFIG"
cat "$WG_CONFIG"
