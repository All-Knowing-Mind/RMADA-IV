#!/usr/bin/env bash
# generate_wg_config.sh
# Gera arquivo wg0.conf para o servidor WireGuard
# Uso: ./generate_wg_config.sh --keys-dir ./keys --outdir ./wg-config --private-key-file server.key

set -euo pipefail

KEYS_DIR=${1:-./keys}
OUTDIR=${2:-./wg-config}
WG_PRIV_KEY=${3:-server_wg.key}
WG_PUB_KEY=${4:-server_wg.pub}

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "=== Gerando chaves WireGuard servidor ==="

# Se não existem, gera par de chaves para o servidor WireGuard
if [ ! -f "$WG_PRIV_KEY" ]; then
  echo "Gerando chave privada WireGuard servidor..."
  wg genkey > "$WG_PRIV_KEY"
  chmod 600 "$WG_PRIV_KEY"
fi

if [ ! -f "$WG_PUB_KEY" ]; then
  echo "Gerando chave pública WireGuard servidor..."
  cat "$WG_PRIV_KEY" | wg pubkey > "$WG_PUB_KEY"
fi

PRIV=$(cat "$WG_PRIV_KEY")
PUB=$(cat "$WG_PUB_KEY")

echo "Chave privada servidor: (guardada em $WG_PRIV_KEY)"
echo "Chave pública servidor:  $PUB"

# Cria wg0.conf inicial com servidor
cat > wg0.conf <<EOF
[Interface]
PrivateKey = $PRIV
Address = 10.0.0.1/24
ListenPort = 51820
# Peers serão adicionados aqui via script de onboarding
EOF

echo "Arquivo wg0.conf criado em $(pwd)"
ls -la wg0.conf

echo ""
echo "Para ativar: sudo wg-quick up ./wg0.conf (no Linux/macOS) ou setup-wg.ps1 (Windows)"
echo "Para adicionar peer: ./add_peer.sh --peer-name device1 --peer-pubkey <chave-publica>"
