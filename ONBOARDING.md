# Device Onboarding with Dilithium + WireGuard

Este documento explica o fluxo de onboarding de dispositivos com assinatura Dilithium e geração automática de configurações WireGuard.

## Fluxo (A) — Onboarding com Dilithium

### Endpoints implementados em `server.js`

#### 1. POST /api/device-onboard
Registra um novo dispositivo no servidor. O dispositivo envia:
- `deviceId` (string): ID único do dispositivo
- `wg_pubkey` (string): chave pública WireGuard do dispositivo
- `dilithium_pubkey` (base64, opcional): chave pública Dilithium para verificação futura
- `dilithium_signature` (base64, opcional): assinatura Dilithium do payload

**Requisitos**:
- Token com role `owner` ou `defense` (via header `Authorization: Bearer <token>`)

**Resposta**:
```json
{
  "status": "onboarded",
  "deviceId": "DEVICE-001",
  "wg_ip": "10.0.0.2/32",
  "server_address": "10.0.0.1",
  "server_port": 51820
}
```

**Uso**:
```bash
curl -X POST http://localhost:8080/api/device-onboard \
  -H "Authorization: Bearer <seu-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "DEVICE-001",
    "wg_pubkey": "<dispositivo-public-key>",
    "dilithium_pubkey": "<base64>",
    "dilithium_signature": "<base64>"
  }'
```

#### 2. GET /api/get-wg-config/:deviceId
Retorna a configuração WireGuard para um dispositivo já onboarded.

**Requisitos**:
- Token com role `owner` ou `defense`
- Dispositivo deve estar registrado (já ter feito POST /api/device-onboard)

**Resposta**:
```json
{
  "deviceId": "DEVICE-001",
  "config": "# WireGuard config...",
  "device_ip": "10.0.0.2/32",
  "server_address": "10.0.0.1"
}
```

## Fluxo (B) — Geração automática de WireGuard config

### Scripts criados

#### generate_wg_config.sh
Cria o arquivo `wg0.conf` inicial para o servidor WireGuard.

**Uso**:
```bash
./generate_wg_config.sh [--keys-dir ./keys] [--outdir ./wg-config]
```

**Resultado**:
- `wg-config/server_wg.key` — chave privada do servidor
- `wg-config/server_wg.pub` — chave pública do servidor
- `wg-config/wg0.conf` — configuração inicial do servidor

**Conteúdo de wg0.conf**:
```ini
[Interface]
PrivateKey = <server-private-key>
Address = 10.0.0.1/24
ListenPort = 51820
```

#### add_peer.sh
Adiciona um peer (dispositivo) ao arquivo `wg0.conf`.

**Uso**:
```bash
./add_peer.sh <peer-name> <peer-pubkey> [wg0.conf] [ip-base] [ip-index]
```

**Exemplo**:
```bash
./add_peer.sh device-001 "<public-key-do-dispositivo>" ./wg0.conf 10.0.0 2
```

**Resultado adicionado ao wg0.conf**:
```ini
# Peer: device-001
[Peer]
PublicKey = <public-key-do-dispositivo>
AllowedIPs = 10.0.0.2/32
```

## Fluxo completo de onboarding (exemplo prático)

### Passo 1: Gerar chaves do servidor WireGuard
```bash
./generate_wg_config.sh --outdir ./wg-config
```

### Passo 2: Dispositivo solicita onboarding
O dispositivo (ex: Raspberry Pi com LoRa) executa:
1. Gera suas próprias chaves WireGuard: `wg genkey | tee priv.key | wg pubkey > pub.key`
2. (Opcional) Gera/assina com Dilithium (se tiver instalado Dilithium 3)
3. Chama o endpoint:
```bash
curl -X POST http://<server-ip>:8080/api/device-onboard \
  -H "Authorization: Bearer <token-owner-ou-defense>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "DEVICE-001",
    "wg_pubkey": "<conteúdo-de-pub.key>",
    "dilithium_pubkey": "<optional-base64>",
    "dilithium_signature": "<optional-base64>"
  }'
```

### Passo 3: Servidor gera configuração WireGuard
Após receber onboarding, o servidor:
1. Adiciona o peer ao `wg0.conf`:
```bash
./add_peer.sh DEVICE-001 "<wg-pubkey-do-device>" ./wg0.conf
```
2. Opcionalmente recarrega WireGuard (se já está ativo):
```bash
sudo wg set wg0 peer <wg-pubkey> allowed-ips 10.0.0.2/32
```

### Passo 4: Dispositivo obtém config e conecta
O dispositivo chama:
```bash
curl http://<server-ip>:8080/api/get-wg-config/DEVICE-001 \
  -H "Authorization: Bearer <token>"
```

Recebe a configuração e tenta conectar via WireGuard (Linux/mobile):
```bash
# No dispositivo
wg-quick up wg0
# ou carregar a config manualmente
```

## Verificação Dilithium (TODO)

No endpoint `/api/device-onboard`, quando `dilithium_signature` é fornecido, o servidor deveria:
1. Validar que a assinatura foi feita com a chave privada correspondente a `dilithium_pubkey`.
2. Reconstruir o payload original (ex: deviceId + timestamp) e verificar se a assinatura é válida.
3. Usar a biblioteca `pyoqs` (Python) ou um binding Node que acesse liboqs para validar.

**Exemplo pseudocódigo** (em production):
```javascript
// Pseudocódigo: verificar assinatura Dilithium
const payload = Buffer.from(`device-onboard:${deviceId}:${Date.now()}`);
const isValid = verifyDilithiumSignature(dilithium_pubkey, payload, dilithium_signature);
if (!isValid) return res.status(403).json({ error: 'invalid signature' });
```

## Notas de segurança

- Atualmente, a verificação de assinatura Dilithium é um placeholder (TODO). Para produção, integre liboqs ou um binding equivalente.
- Tokens são emitidos por 24 horas. Para revogação imediata, implemente um blacklist.
- WireGuard keys devem ser mantidas seguras em ambos os lados (servidor e dispositivo). Não exponha chaves privadas em logs ou respostas HTTP.
- Considere usar HTTPS (TLS) para provisionar os endpoints em ambientes reais.

## Próximas melhorias

- Implementar verificação real de assinatura Dilithium (usar pyoqs ou binding Node).
- Persistir device registry em banco de dados (ex: SQLite, PostgreSQL) em vez de memória.
- Automatizar chamadas a `add_peer.sh` quando um dispositivo é onboarded (ex: via webhook ou worker).
- Implementar revogação de dispositivos (remover peer de wg0.conf e invalidar IP).
