#!/usr/bin/env bash
# generate_dilithium_keys.sh — Generate Dilithium3 keypair for device
# Usage: ./generate_dilithium_keys.sh [output_dir]

set -e

OUTPUT_DIR=${1:-.}
KEYGEN_BIN=${2:-}

mkdir -p "$OUTPUT_DIR"

echo "================================================"
echo "Dilithium3 Key Generation"
echo "================================================"
echo ""

# Try to find dilithium_keygen binary
if [ -z "$KEYGEN_BIN" ]; then
  # Look for pre-built binary in common locations
  for path in \
    ./meu_projeto_dilithium/target/release/dilithium_keygen \
    ./meu_projeto_dilithium/target/release/dilithium_keygen.exe \
    /usr/local/bin/dilithium_keygen \
    /usr/bin/dilithium_keygen; do
    if [ -x "$path" ]; then
      KEYGEN_BIN="$path"
      break
    fi
  done
fi

# If still not found, try to build it
if [ -z "$KEYGEN_BIN" ] || [ ! -x "$KEYGEN_BIN" ]; then
  echo "⚙️  Building dilithium_keygen (Rust)..."
  if ! command -v cargo &> /dev/null; then
    echo "❌ Cargo not found. Install Rust from https://rustup.rs"
    exit 1
  fi
  
  cd meu_projeto_dilithium
  cargo build --release --bin dilithium_keygen
  cd ..
  
  KEYGEN_BIN="./meu_projeto_dilithium/target/release/dilithium_keygen"
  if [ ! -x "$KEYGEN_BIN" ]; then
    KEYGEN_BIN="./meu_projeto_dilithium/target/release/dilithium_keygen.exe"
  fi
fi

echo "Using keygen binary: $KEYGEN_BIN"
echo ""

# Generate keys
echo "🔑 Generating keys..."
"$KEYGEN_BIN" "$OUTPUT_DIR"

echo ""
echo "✅ Keys generated in $OUTPUT_DIR"
echo ""
echo "Files:"
ls -lah "$OUTPUT_DIR"/dilithium*.key

echo ""
echo "⚠️  Keep the secret key secure!"
echo "   Do not commit dilithium_secret.key to version control."
