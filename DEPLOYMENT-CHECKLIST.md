# ✅ Deployment Checklist — RMADA Stage 1

Use este checklist para validar que seu repositório está pronto para transferir e rodar em qualquer máquina.

---

## 📋 Pré-Deployment (Antes de enviar)

### Arquivos Essenciais
- [ ] `package.json` — Dependências Node.js presentes
- [ ] `Dispositivo.html` — Dashboard frontend (responsivo)
- [ ] `app.js` — Frontend logic (Chart.js, WebSocket, auth)
- [ ] `server.js` — Backend (Express, Dilithium, onboarding)
- [ ] `.env.example` — Template de environment vars
- [ ] `.gitignore` — Gitignore configurado (node_modules, .env, etc)
- [ ] `.dockerignore` — Dockerfile ignore configurado

### Arquivos Docker & Orquestração
- [ ] `docker-compose.yml` — Orquestração dos serviços
- [ ] `Dockerfile.server` — Build da imagem Node
- [ ] `docker-entrypoint.sh` — Script de inicialização (executável)
- [ ] `Earthfile` — Targets Earthly (+server, +dilithium-verifier, +complete-image)

### Arquivos de Configuração
- [ ] `generate_keys.sh` — Gera certificados OpenSSL (executável)
- [ ] `generate_wg_config.sh` — Gera wg0.conf (executável)
- [ ] `add_peer.sh` — Adiciona peers WireGuard (executável)
- [ ] `lightway-config/server.conf` — Config Lightway de exemplo
- [ ] `meu_projeto_dilithium/` — Verificador Dilithium (Cargo.toml + src/main.rs)

### Documentação
- [ ] `README-STAGE1.md` — Documentação completa
- [ ] `QUICK-START.md` — Guia rápido (3 passos)
- [ ] `ONBOARDING.md` — Fluxo de onboarding de dispositivos
- [ ] `DEPLOYMENT-CHECKLIST.md` — Este arquivo

### Scripts Auxiliares
- [ ] `start-server.sh` — Script de inicialização rápida (executável)
- [ ] `test-onboarding.sh` — Script de teste (executável)

### Dados Gerados (Ignorados no Git)
- [ ] `keys/` — Certificados OpenSSL (NÃO commitar!)
- [ ] `wg-config/` — Configuração WireGuard (pode ser regenerado)
- [ ] `users.json` — Usuários (pode ser regenerado vazio)
- [ ] `device-registry.json` — Registro de dispositivos (pode ser regenerado)
- [ ] `node_modules/` — Dependências npm (será instalado)
- [ ] `meu_projeto_dilithium/target/` — Binários compilados (será regenerado)

---

## 🔐 Segurança (Antes de fazer Deploy)

### Secrets & Senhas
- [ ] Mude `OWNER_CODE` em `.env` (não use "OWNER-SECRET-CHANGEME")
- [ ] Mude `DEFENSE_CODE` em `.env` (não use "DEFENSE-SECRET-CHANGEME")
- [ ] Não commite `.env` no Git (apenas `.env.example`)
- [ ] Gere novos certificados para cada environment (não reutilize keys/)

### Acesso & Permissões
- [ ] Scripts `.sh` têm permissão de execução: `chmod +x *.sh`
- [ ] Direitos de read-only no servidor (verificar ownership de arquivos)

### Variáveis de Ambiente
- [ ] Revise todas as env vars em `.env.example`
- [ ] Documente quais são obrigatórias vs opcionais
- [ ] Defina defaults sensatos em `server.js` para cada var

---

## 🏗️ Build & Runtime

### Build Local
- [ ] `npm install` funciona sem erros
- [ ] `npm run build:dilithium` compila com sucesso (requer Rust)
- [ ] `bash generate_keys.sh` gera certificados OK
- [ ] `bash generate_wg_config.sh` gera wg0.conf OK

### Docker Build
- [ ] `docker build -f Dockerfile.server -t rmada:local .` sucesso
- [ ] `docker-compose build` sucesso
- [ ] `earthly +server` sucesso (se Earthly disponível)
- [ ] `earthly +complete-image` sucesso

### Execução Local
- [ ] `npm start` inicia sem erros
- [ ] WebSocket conecta em `ws://localhost:8080`
- [ ] Dashboard carrega em `http://localhost:8080`
- [ ] Login/Registrar funciona
- [ ] Telemetria é recebida e aparece nos gráficos

### Docker Compose Execution
- [ ] `docker-compose up -d` inicia containers
- [ ] `docker-compose ps` mostra todos serviços rodando
- [ ] `curl http://localhost:8080/health` retorna 200 OK
- [ ] Dashboard acessível em `http://localhost:8080`
- [ ] Logs sem erros críticos: `docker-compose logs`

---

## 📱 Portabilidade

### Cross-Platform
- [ ] Scripts `.sh` usam `#!/usr/bin/env bash` (não bash hardcoded)
- [ ] Caminhos usam `/` (não `\` — aceita ambos em Node)
- [ ] Configurações não assumem `/home/user` ou caminhos fixos
- [ ] Docker Compose não usa volumes path-específicos (usar named volumes)

### Outro Computador
- [ ] Clonar repo em novo dir: `git clone <url> && cd RMADA`
- [ ] `docker-compose up -d` funciona imediatamente (sem pré-setup)
- [ ] Dashboard funciona em primeiro acesso
- [ ] Dispositivos podem fazer onboarding

### Outro Sistema Operacional
- [ ] Testado em Linux ✓ / Windows ✓ / macOS ✓ (ou documentar limitações)
- [ ] Docker available em Windows (WSL2 ou Docker Desktop)
- [ ] Comandos Earthly funcionam em Windows (WSL recomendado)

---

## 🔗 Conectividade

### Rede Local
- [ ] Servidor acessível por IP da máquina (ex: `http://192.168.1.100:8080`)
- [ ] Mobile na mesma WiFi pode conectar ao dashboard
- [ ] Dispositivos LoRa podem enviar HTTP POST a `/api/telemetry`

### VPN / Lightway (Optional Stage 1)
- [ ] Config Lightway está em `lightway-config/server.conf` ✓
- [ ] Lightway folder referenciado em docker-compose.yml ✓
- [ ] Testado manualmente (pode ser skipped se opcional em Stage 1)

---

## 📊 Dados & Persistência

### Primeiro Boot
- [ ] Arquivo `users.json` é criado vazio ou com usuários exemplo
- [ ] Arquivo `device-registry.json` criado ou configurado
- [ ] Diretórios `keys/`, `wg-config/` criados automaticamente

### Após Restart
- [ ] Usuários registrados persistem (users.json lido)
- [ ] Dispositivos persistem (device-registry lido — ou em memória Stage 1)
- [ ] Histórico de alertas pode ser recuperado (localStorage frontend)

### Backup
- [ ] Documentado como fazer backup: `users.json`, `device-registry.json`, `keys/`
- [ ] Restauração documentada

---

## 🧪 Testes Básicos

### Autenticação
```bash
# Registrar proprietário
curl -X POST http://localhost:8080/api/register-owner \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test","ownerCode":"OWNER-CODE"}'
# Resposta: { "token": "...", "role": "owner" }

# Defesa Civil
curl -X POST http://localhost:8080/api/login-defense \
  -H "Content-Type: application/json" \
  -d '{"code":"DEFENSE-CODE"}'
# Resposta: { "token": "...", "role": "defense" }
```
- [ ] Ambos retornam tokens válidos

### Telemetria
```bash
curl -X POST http://localhost:8080/api/telemetry \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"D1","value":42.5}'
# Resposta: { "status": "ok" }
```
- [ ] Dados aparecem no gráfico em tempo real

### Health Check
```bash
curl http://localhost:8080/health
# Resposta: { "status": "healthy", ... }
```
- [ ] Retorna 200 OK

---

## 📋 Documentação Final

### README & Guides
- [ ] README-STAGE1.md cobre: setup, endpoints, troubleshooting
- [ ] QUICK-START.md tem passos claros (Docker ou Node)
- [ ] ONBOARDING.md explica fluxo de dispositivos
- [ ] DEPLOYMENT-CHECKLIST.md (este arquivo) presente

### Inline Comments
- [ ] Código-chave tem comentários explicando lógica (Dilithium, WG)
- [ ] Variáveis de ambiente estão documentadas no `.env.example`

### Known Issues
- [ ] Documentadas limitações (ex: `device-registry` em memória, não persiste)
- [ ] Documentados workarounds (ex: WireGuard requer CAP_NET_ADMIN em Docker)

---

## 🚀 Go Live

Quando todos itens estão ✓:

1. **Git Push** → Enviar repo para GitHub/GitLab
   ```bash
   git add .
   git commit -m "Stage 1: Complete RMADA with Docker + Dilithium + Earthly"
   git push origin main
   ```

2. **Clone Nouvo Local** → Validar que outro clone funciona
   ```bash
   cd /tmp
   git clone <seu-repo> RMADA-test
   cd RMADA-test
   docker-compose up -d
   # Verificar http://localhost:8080
   ```

3. **Deploy Target** → Se usando servidor remoto
   ```bash
   ssh user@server
   git clone <seu-repo>
   cd RMADA
   docker-compose up -d
   ```

---

## ✨ Stage 1 Complete!

Se todos itens ✓, seu repositório RMADA está pronto para:
- ✅ Clone em qualquer machine
- ✅ Run com `docker-compose up` ou `npm start`
- ✅ Dashboard + WebSocket funcionando
- ✅ Dispositivos fazendo onboarding com Dilithium
- ✅ Telemetria em tempo real

---

**Next**: Stage 2 adicionará persistência DB, HTTPS, Lightway operacional.

**Data**: 2025-11-11
