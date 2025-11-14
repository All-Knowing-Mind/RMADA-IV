# RMADA — Monitoramento IoT com VPN Seguro (Stage 1)

Repositório portátil e funcional para monitoramento em tempo real de dispositivos LoRa com detecção de deslizamentos de terra. Inclui:
- **Frontend**: Dashboard em HTML5 + Chart.js (responsivo, mobile-first)
- **Backend**: Node.js + Express + WebSocket com autenticação por roles
- **Criptografia**: Dilithium3 para assinatura de dispositivos (post-quantum ready)
- **VPN**: Preparação para Lightway + configuração WireGuard (opcional)
- **Orquestração**: Docker Compose + Earthly para builds reprodutíveis

---

## 🚀 Quick Start (5 minutos)

### Pré-requisitos
- **Docker** (e opcionalmente Docker Compose)
- **Git** para clonar o repositório

### Executar localmente (Docker Compose)

```bash
# 1. Clone ou extraia o repositório
cd RMADA

# 2. Defina variáveis de ambiente (opcionais)
export OWNER_CODE="seu-codigo-proprietario"
export DEFENSE_CODE="seu-codigo-defesa-civil"

# 3. Inicie os serviços
docker-compose up -d

# 4. Acesse o dashboard
# Abra no navegador: http://localhost:8080
# (ou http://<seu-host-ip>:8080 para acessar de outro dispositivo)

# 5. Monitore os logs
docker-compose logs -f rmada-server

# 6. Pare os serviços
docker-compose down
```

### Usar sem Docker (Node.js direto)

```bash
# Pré-requisitos: Node.js 18+, npm, Rust (para Dilithium verifier)

# 1. Instale dependências
npm install

# 2. Build do verificador Dilithium
npm run build:dilithium

# 3. Inicie o servidor
node server.js

# 4. Acesse em http://localhost:8080
```

---

## 📦 Estrutura do Repositório

```
RMADA/
├── Dispositivo.html          # Dashboard principal (6 gráficos em tempo real)
├── Operação.html             # Página de operação/instruções
├── Início.html               # Página inicial
├── styles.css                # Estilos (dark mode, responsive)
├── app.js                    # Frontend logic (Chart.js, WebSocket, auth)
├── server.js                 # Backend (Express, WS, Dilithium, onboarding)
├── package.json              # Dependências Node
│
├── Earthfile                 # Orquestração Earthly (builds multi-stage)
├── docker-compose.yml        # Orquestração Docker Compose
├── Dockerfile.server         # Imagem Docker para o servidor
├── docker-entrypoint.sh      # Script de inicialização (WireGuard, entrypoint)
│
├── meu_projeto_dilithium/    # Verificador Dilithium (Rust)
│   ├── Cargo.toml
│   └── src/main.rs
│
├── lightway-main/            # Código Lightway VPN (submodule/folder)
├── lightway-config/          # Configuração Lightway de exemplo
│
├── keys/                     # Certificados OpenSSL (gerados)
├── wg-config/                # Configuração WireGuard (gerada)
│   └── wg0.conf
│
├── generate_keys.sh          # Gera certificados OpenSSL + Dilithium
├── generate_wg_config.sh     # Gera chaves WireGuard
├── add_peer.sh               # Adiciona peers ao wg0.conf
│
├── users.json                # Usuários registrados (gerado)
├── device-registry.json      # Registro de dispositivos (gerado, opcional)
│
└── README.md                 # Este arquivo
```

---

## 🔐 Segurança & Autenticação

### Roles e Permissões

**Proprietário (Owner)**:
- Registra-se com código de proprietário (`OWNER_CODE`)
- Pode onboard dispositivos (via `/api/device-onboard`)
- Pode monitorar todos os dispositivos
- Pode retirar dispositivos

**Defesa Civil**:
- Faz login apenas com código (`DEFENSE_CODE`)
- Pode visualizar monitoramento em tempo real
- Acesso somente-leitura

### Autenticação
- **Método**: Token UUID (Bearer token, 24h expiry)
- **Transporte**: Authorization header (`Authorization: Bearer <token>`)
- **Proteção**: Tokens armazenados em memória; implementar DB para produção

### Assinatura de Dispositivos (Dilithium3)
- Dispositivos assinam seu ID com chave privada Dilithium
- Servidor verifica assinatura com `meu_projeto_dilithium` (Rust)
- Se inválido, onboarding é rejeitado (403 Forbidden)

---

## 🌐 Endpoints da API

### Autenticação

```bash
# Registrar novo proprietário
POST /api/register-owner
{
  "username": "seu-usuario",
  "password": "sua-senha",
  "ownerCode": "seu-codigo-owner"
}
# Resposta: { "token": "...", "role": "owner" }

# Login (proprietário ou usuário)
POST /api/login
{
  "username": "seu-usuario",
  "password": "sua-senha"
}
# Resposta: { "token": "...", "role": "..." }

# Login Defesa Civil
POST /api/login-defense
{
  "code": "seu-codigo-defesa-civil"
}
# Resposta: { "token": "...", "role": "defense" }

# Informações do usuário autenticado
GET /api/whoami
# Header: Authorization: Bearer <token>
# Resposta: { "role": "...", "userId": "..." }
```

### Dispositivos

```bash
# Onboarding de dispositivo (com Dilithium)
POST /api/device-onboard
{
  "deviceId": "DEVICE-001",
  "wg_pubkey": "<chave-publica-wireguard>",
  "dilithium_pubkey": "<chave-publica-dilithium>",
  "dilithium_signature": "<assinatura-base64>"
}
# Header: Authorization: Bearer <token>
# Resposta: {
#   "status": "onboarded",
#   "deviceId": "DEVICE-001",
#   "wg_ip": "10.0.0.2/32",
#   "wireguard": { "ok": true, ... }
# }

# Obter configuração WireGuard para dispositivo
GET /api/get-wg-config/:deviceId
# Header: Authorization: Bearer <token>
# Resposta: {
#   "deviceId": "DEVICE-001",
#   "config": "# WireGuard config...",
#   "device_ip": "10.0.0.2/32"
# }

# Enviar telemetria via HTTP
POST /api/telemetry
{
  "deviceId": "DEVICE-001",
  "value": 42.5,
  "timestamp": 1699700000000
}
# Resposta: { "status": "ok", "received": { ... } }
```

### Monitoramento

```bash
# WebSocket para telemetria em tempo real
ws://localhost:8080?token=<seu-token>

# Health check
GET /health
# Resposta: { "status": "healthy", "uptime": ..., "timestamp": ... }
```

---

## 🛠️ Configuração de Variáveis de Ambiente

```bash
# Porta do servidor (padrão: 8080)
export PORT=8080

# Código de proprietário (altere em produção!)
export OWNER_CODE="OWNER-SECRET-CHANGEME"

# Código de Defesa Civil (altere em produção!)
export DEFENSE_CODE="DEFENSE-SECRET-CHANGEME"

# Habilitar verificação Dilithium (1 = sim, 0 = não)
export DILITHIUM_VERIFY=1

# Caminho customizado para wg0.conf
export WG_CONFIG_PATH=/meu/caminho/wg0.conf

# Caminho customizado para binário Dilithium verifier
export DILITHIUM_VERIFIER_BIN=/meu/caminho/meu_projeto_dilithium
```

---

## 🔨 Build & Deploy

### Build via Docker Compose

```bash
# Build automaticamente e inicia
docker-compose up --build -d

# Apenas build sem iniciar
docker-compose build
```

### Build via Earthly

```bash
# Pré-requisito: Earthly instalado (https://earthly.dev)

# Build apenas o servidor Node
earthly +server

# Build o verificador Dilithium
earthly +dilithium-verifier

# Build Lightway VPN (opcional)
earthly +lightway-base

# Build tudo junto
earthly +all

# Build imagem Docker completa (Stage 1)
earthly +complete-image
```

### Build manual (Rust + Node)

```bash
# Compilar Dilithium verifier
cd meu_projeto_dilithium
cargo build --release
cd ..

# Instalar dependências Node
npm install

# Gerar certificados (OpenSSL)
./generate_keys.sh --outdir ./keys

# Gerar configuração WireGuard
./generate_wg_config.sh --outdir ./wg-config

# Iniciar servidor
node server.js
```

---

## 📱 Acesso Mobile

### Do mesmo WiFi/rede

```
http://<seu-host-ip>:8080
```

Exemplo: Se o servidor está em `192.168.1.100`, acesse de mobile:
```
http://192.168.1.100:8080
```

### Via VPN Lightway (futuro)

Quando Lightway estiver operacional, dispositivos remotos podem conectar:
```bash
# No dispositivo remoto
./lightway-client --config lightway-client.conf
```

### Via LoRa

Dispositivos com rádio LoRa conectam ao servidor via HTTP `/api/telemetry`:
```bash
# Dispositivo LoRa
curl -X POST http://server-ip:8080/api/telemetry \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"DEVICE-001","value":42.5}'
```

---

## 🔄 Fluxo de Onboarding de Dispositivo

1. **Device inicia conexão LoRa ao servidor**
   - Device gera par de chaves Dilithium (privada/pública)
   - Device gera par de chaves WireGuard

2. **Device autentica-se como "Owner"**
   - POST `/api/login` → obtém `token`

3. **Device faz onboarding com assinatura**
   ```bash
   POST /api/device-onboard
   {
     "deviceId": "DEVICE-001",
     "wg_pubkey": "...",
     "dilithium_pubkey": "...",
     "dilithium_signature": "<hash(deviceId) assinado com private key>"
   }
   ```

4. **Servidor valida assinatura Dilithium**
   - Se válida → registra device com IP 10.0.0.x
   - Se inválida → rejeita (403)

5. **Servidor retorna configuração WireGuard/Lightway**
   ```json
   {
     "status": "onboarded",
     "wg_ip": "10.0.0.2/32",
     "wireguard": { "ok": true }
   }
   ```

6. **Device conecta ao VPN e começa enviar telemetria**
   - POST `/api/telemetry` a cada leitura de sensor
   - Dados aparecem no dashboard em tempo real

---

## 🐛 Troubleshooting

### "docker-compose command not found"
```bash
# Usar docker compose (versão nova)
docker compose up -d
# ou instalar docker-compose standalone
```

### "Dilithium verifier not found"
```bash
# Build o verificador
npm run build:dilithium
# ou
cd meu_projeto_dilithium && cargo build --release
```

### "Port 8080 already in use"
```bash
# Usar porta diferente
docker-compose -e PORT=9090 up -d
# ou editar docker-compose.yml e trocar a porta
```

### "WireGuard command not found"
```bash
# Instalar WireGuard tools
# Ubuntu/Debian
sudo apt-get install wireguard-tools

# macOS
brew install wireguard-tools

# Windows: Use WSL2 ou máquina virtual Linux
```

### "Connection refused on http://localhost:8080"
```bash
# Verificar se container está rodando
docker-compose ps

# Ver logs
docker-compose logs rmada-server

# Reiniciar
docker-compose restart rmada-server
```

---

## 📋 Próximas Etapas (Stage 2+)

- ✅ **Stage 1 (Atual)**: Repositório portátil, Docker + Node + Dilithium
- 🔜 **Stage 2**: Persistência (SQLite device registry), HTTPS, Lightway operacional
- 🔜 **Stage 3**: Clientes Lightway mobile, builds para ARM (Raspberry Pi)
- 🔜 **Stage 4**: Autoscaling, monitoring (Prometheus), CI/CD

---

## 📞 Suporte & Contribuições

Para problemas, sugestões ou contribuições, abra uma issue ou PR no repositório.

---

## 📄 Licença

MIT License — veja LICENSE.txt para detalhes.

---

**Status**: ✅ Fully functional end-to-end (Stage 1)  
**Last Updated**: 2025-11-11  
**Maintained by**: RMADA Team
