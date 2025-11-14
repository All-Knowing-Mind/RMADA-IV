# 🚀 QUICK START — RMADA Stage 1

Comece a usar RMADA em **3 passos simples**:

---

## Passo 1: Clonar / Extrair repositório

```bash
git clone <seu-repositorio> RMADA
cd RMADA
```

Ou, se baixou como ZIP:
```bash
unzip RMADA.zip
cd RMADA
```

---

## Passo 2: Iniciar com Docker (recomendado)

```bash
# Se você tem Docker/Docker Compose instalado:
docker-compose up -d

# OU use o script de inicialização:
bash start-server.sh docker

# OU manualmente:
docker-compose up --build
```

**Pronto!** O servidor está rodando.

---

## Passo 3: Acessar o dashboard

Abra no navegador:
```
http://localhost:8080
```

Você verá:
- 📊 6 gráficos em tempo real (D1 a D6)
- 🔐 Modal de autenticação (Login, Registrar, Defesa Civil)
- 📢 Alertas e notificações

---

## 🔐 Login / Registrar

### Propriedário (Owner)
1. Clique em "Se Inscreva" ou na aba "Registrar (Owner)"
2. Preencha usuário/senha
3. Código proprietário: `OWNER-SECRET-CHANGEME` (mude em produção!)
4. Clique "Registrar Owner"
5. Você receberá um token (salvo automaticamente no localStorage)

### Defesa Civil
1. Clique na aba "Defesa Civil"
2. Digite o código: `DEFENSE-SECRET-CHANGEME` (mude em produção!)
3. Clique "Entrar Defesa Civil"

---

## 🌐 URLs Úteis

| Recurso | URL | Descrição |
|---------|-----|----------|
| Dashboard | http://localhost:8080 | Página principal (Dispositivo.html) |
| Operação | http://localhost:8080/Operação.html | Informações de funcionamento |
| API Whoami | http://localhost:8080/api/whoami | Verificar token (header: Authorization: Bearer ...) |
| Health | http://localhost:8080/health | Status do servidor |
| WebSocket | ws://localhost:8080?token=... | Conexão em tempo real |

---

## 📊 Testar Telemetria

Envie dados de um dispositivo simulado:

```bash
# 1. Registre um proprietário e obtenha seu token
# (veja acima na seção Login)

# 2. Envie telemetria via HTTP
curl -X POST http://localhost:8080/api/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "D1",
    "value": 85.5,
    "timestamp": '$(($(date +%s)*1000))'
  }'

# Os dados aparecerem no gráfico em tempo real!
```

Ou use o script de teste:
```bash
bash test-onboarding.sh <token> DEVICE-001
```

---

## ⚙️ Variáveis de Ambiente

Copie `.env.example` para `.env` e customize:

```bash
cp .env.example .env
nano .env  # ou use seu editor favorito
```

Variáveis importantes:
- `PORT=8080` — Porta do servidor
- `OWNER_CODE=...` — Código para registrar proprietários
- `DEFENSE_CODE=...` — Código para Defesa Civil
- `DILITHIUM_VERIFY=1` — Ativar verificação post-quantum

---

## 🛑 Parar o servidor

```bash
# Se rodando com docker-compose:
docker-compose down

# Se rodando com Node direto:
# Pressione Ctrl+C
```

---

## 📱 Acessar de outro dispositivo

Se servidor está em `192.168.1.100`:

```
http://192.168.1.100:8080
```

(Substitua com o IP do seu computador na rede local)

---

## 🐛 Problemas?

### "docker-compose: command not found"
```bash
# Use versão nova do Docker
docker compose up -d
```

### "Port 8080 already in use"
```bash
# Usar porta diferente
PORT=9090 npm start
# ou editar docker-compose.yml
```

### "Cannot GET /"
- Verifique se servidor iniciou: `docker-compose ps`
- Veja logs: `docker-compose logs rmada-server`
- Reinicie: `docker-compose restart rmada-server`

---

## 📚 Próximos Passos

1. **Onboarding de dispositivo real**: Veja [ONBOARDING.md](./ONBOARDING.md)
2. **Configurar Dilithium**: Veja [README-STAGE1.md](./README-STAGE1.md)
3. **Replicar para outro computador**: Faça push para um repositório Git e clone em outro lugar

---

## 🎓 Conceitos

- **WebSocket**: Conexão em tempo real (telemetria ao vivo)
- **Bearer Token**: Autenticação (copiado do localStorage automaticamente)
- **Dilithium3**: Assinatura post-quantum para dispositivos
- **WireGuard**: VPN para tunnel de dispositivos (opcional, configurável)

---

## 📞 Suporte

Dúvidas? Veja:
- [README-STAGE1.md](./README-STAGE1.md) — Documentação completa
- [ONBOARDING.md](./ONBOARDING.md) — Fluxo de dispositivos
- Logs: `docker-compose logs -f`

---

**Sucesso! 🎉 RMADA está pronto para monitorar seus dispositivos LoRa.**
