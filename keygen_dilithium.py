"""
Exemplo: gerar par de chaves Dilithium (NIST round2 parameter) usando pyoqs (Python wrapper for liboqs).
Requisitos:
  pip install pyoqs

Este script gera uma chave pública e privada e grava em arquivos PEM-like (raw base64) para uso no servidor e no dispositivo.

Observação: pyoqs usa algoritmos disponíveis na sua versão de liboqs instalada.
"""

import oqs
import base64
import json
import os

ALG = 'Dilithium2'
OUTDIR = 'keys_dilithium'

os.makedirs(OUTDIR, exist_ok=True)

with oqs.Signature(ALG) as signer:
    pk = signer.generate_keypair()
    sk = signer.export_secret_key()

# salvar em base64
with open(os.path.join(OUTDIR, 'dilithium_pub.b64'), 'wb') as f:
    f.write(base64.b64encode(pk))
with open(os.path.join(OUTDIR, 'dilithium_priv.b64'), 'wb') as f:
    f.write(base64.b64encode(sk))

print('Chaves geradas em', OUTDIR)
print('public (base64):', os.path.join(OUTDIR, 'dilithium_pub.b64'))
print('private (base64):', os.path.join(OUTDIR, 'dilithium_priv.b64'))

# Exemplo de uso: o dispositivo assina um payload e o servidor verifica
payload = b"device-registration:DEVICEID:timestamp"
with oqs.Signature(ALG) as signer:
    signer.load_secret_key(sk)
    signature = signer.sign(payload)

with oqs.Signature(ALG) as verifier:
    verifier.load_public_key(pk)
    ok = verifier.verify(payload, signature)

print('Verificação local OK?', ok)
