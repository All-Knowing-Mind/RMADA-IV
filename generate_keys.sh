#!/usr/bin/env bash
# generate_keys.sh
# Gera CA, server e client certs via OpenSSL e tenta gerar chaves Dilithium3 se o OpenSSL suportar.
# Usage: ./generate_keys.sh --outdir ./keys --noninteractive

set -euo pipefail
OUTDIR=./keys
NONINTERACTIVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2;;
    --noninteractive) NONINTERACTIVE=1; shift;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "Generating CA (RSA 4096)..."
if [ ! -f ca.key ]; then
  openssl genpkey -algorithm RSA -out ca.key -pkeyopt rsa_keygen_bits:4096
fi
if [ ! -f ca.crt ]; then
  if [ "$NONINTERACTIVE" -eq 1 ]; then
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -subj "/CN=RMADA CA" -out ca.crt
  else
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt
  fi
fi

# Server key & cert
echo "Generating server key and CSR..."
if [ ! -f server.key ]; then
  openssl genpkey -algorithm RSA -out server.key -pkeyopt rsa_keygen_bits:2048
fi
if [ ! -f server.csr ]; then
  if [ "$NONINTERACTIVE" -eq 1 ]; then
    openssl req -new -key server.key -subj "/CN=rmada-server" -out server.csr
  else
    openssl req -new -key server.key -out server.csr
  fi
fi

if [ ! -f server.crt ]; then
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
fi

# Client key & cert (example device)
echo "Generating client key and CSR..."
if [ ! -f client.key ]; then
  openssl genpkey -algorithm RSA -out client.key -pkeyopt rsa_keygen_bits:2048
fi
if [ ! -f client.csr ]; then
  if [ "$NONINTERACTIVE" -eq 1 ]; then
    openssl req -new -key client.key -subj "/CN=rmada-client" -out client.csr
  else
    openssl req -new -key client.key -out client.csr
  fi
fi
if [ ! -f client.crt ]; then
  openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256
fi

# Try to generate Dilithium3 keys using OpenSSL if supported
# Newer OpenSSL with OQS provider may provide algorithm names like dilithium3
DILITH_ALG=dilithium3
DIL_PRIV=dilithium_priv.pem
DIL_PUB=dilithium_pub.pem

if openssl list -public-key-algorithms | grep -qi "$DILITH_ALG"; then
  echo "OpenSSL supports $DILITH_ALG via provider. Generating keys..."
  if [ ! -f "$DIL_PRIV" ]; then
    openssl genpkey -algorithm $DILITH_ALG -out "$DIL_PRIV"
  fi
  if [ ! -f "$DIL_PUB" ]; then
    openssl pkey -in "$DIL_PRIV" -pubout -out "$DIL_PUB"
  fi
else
  echo "OpenSSL does not advertise algorithm $DILITH_ALG."
  echo "If you have liboqs/oqs-provider, install and enable it, or provide Dilithium keys separately." 
  echo "You can still use the generated RSA certificates for TLS and use Dilithium keys for signature verification in your app."
fi

# Summarize
echo "Keys and certs generated in: $(pwd)"
ls -la

echo "Done."
