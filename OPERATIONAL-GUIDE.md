# 🔑 RMADA — Guia Operacional do Sistema Seguro

## ⚡ Início Rápido

### 1. Configurar Variáveis de Ambiente

```bash
# Criar arquivo .env na raiz do projeto
cat > .env << EOF
# Autenticação
OWNER_CODE=PROPRIETARIO_2024_SENHA_FORTE
DEFENSE_CODE=DEFESA_CIVIL_2024_CODIGO_SEGURO
PORT=8080
NODE_ENV=production
EOF

# IMPORTANTE: Adicionar .env ao .gitignore
echo ".env" >> .gitignore
```

### 2. Iniciar o Servidor

```bash
npm install
npm start

# Servidor rodando em: http://localhost:8080
# ✅ Sistema de segurança ativo
```

### 3. Acessar o Sistema

#### Para Proprietário
```
1. Abrir: http://localhost:8080/Operação.html
2. Modal "Autenticação RMADA" aparece (obrigatório)
3. Aba "Proprietário" está selecionada
4. Preencher:
   - Usuário: seu_username
   - Senha: sua_senha_forte
   - Código: PROPRIETARIO_2024_SENHA_FORTE (do .env)
5. Clicar "Autenticar Proprietário"
6. ✅ Dashboard carrega em tempo real
```

#### Para Defesa Civil
```
1. Abrir: http://localhost:8080/Operação.html
2. Modal "Autenticação RMADA" aparece
3. Clicar aba "Defesa Civil"
4. Preencher:
   - Código: DEFESA_CIVIL_2024_CODIGO_SEGURO (do .env)
5. Clicar "Entrar Defesa Civil"
6. ✅ Dashboard carrega (acesso restrito)
```

#### Para Público
```
1. Abrir: http://localhost:8080/
2. Página inicial carrega (sem autenticação)
3. Informações sobre sistema
4. Botão "Se Inscreva" se quiser acesso
```

---

## 📋 Matriz de Acesso Rápida

```
┌──────────────────────────────────────────────────┐
│          QUEM ACESSA O QUÊ?                     │
├──────────────────────────────────────────────────┤
│                                                  │
│ PROPRIETÁRIO (Owner)                           │
│ ├─ ✅ Dashboard com gráficos em tempo real    │
│ ├─ ✅ Enviar dados de sensores (telemetria)  │
│ ├─ ✅ Gerenciar dispositivos                │
│ ├─ ✅ Ver histórico completo               │
│ ├─ ✅ Editar configurações                │
│ └─ 🎟️ Token válido por 24 horas           │
│                                                  │
│ DEFESA CIVIL (Emergency)                        │
│ ├─ ✅ Dashboard com gráficos (read-only)      │
│ ├─ ✅ Ver alertas em tempo real              │
│ ├─ ✅ Receber notificações                   │
│ ├─ ❌ Não pode enviar dados                  │
│ ├─ ❌ Não pode editar                       │
│ └─ 🎟️ Token válido por 24 horas             │
│                                                  │
│ PÚBLICO                                         │
│ ├─ ✅ Página inicial (Início.html)           │
│ ├─ ✅ Informações sobre sistema             │
│ ├─ ❌ Não acessa dashboard                  │
│ ├─ ❌ Não vê dados de tempo real            │
│ └─ 🎟️ Sem token                             │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## 🔐 Fluxo de Autenticação Completo

### Proprietário Registrando (Primeira Vez)

```
1. Usuário clica "Se Inscreva"
   └─ Modal abre automaticamente

2. Preenche formulário:
   └─ Usuário: joao_silva_123
   └─ Senha: MinhaSenha@2024!
   └─ Código: PROPRIETARIO_2024_SENHA_FORTE

3. Clica "Autenticar Proprietário"
   └─ Frontend envia dados para servidor

4. Servidor verifica:
   └─ ✓ Código está correto?
   └─ ✓ Usuário já existe?
   └─ ✓ Senha tem tamanho mínimo?

5. Servidor cria usuário:
   └─ Hash da senha com bcryptjs
   └─ Salva em users.json
   └─ Gera UUID único

6. Servidor emite JWT token:
   └─ Payload: {userId, role: 'owner'}
   └─ Expira em: 24 horas

7. Frontend recebe token:
   └─ Salva em localStorage
   └─ localStorage.setItem('rmada_token', token)
   └─ localStorage.setItem('rmada_role', 'owner')

8. Frontend reconecta ao servidor:
   └─ WebSocket agora inclui token
   └─ ws://localhost:8080?token=JWT_TOKEN

9. Servidor valida WebSocket:
   └─ ✓ Token válido?
   └─ ✓ Token não expirou?
   └─ ✓ Role é 'owner' ou 'defense'?

10. ✅ Conexão estabelecida
    └─ Dashboard carrega
    └─ Dados em tempo real
    └─ Pronto para usar
```

### Proprietário Entrando (Próximas Vezes)

```
1. Usuário abre http://localhost:8080/Operação.html
2. Se token já existe em localStorage:
   └─ WebSocket tenta conectar com token antigo
   └─ Se válido → Dashboard carrega
   └─ Se expirado → Modal de autenticação
3. Se sem token:
   └─ Modal de autenticação aparece
   └─ Mesmo fluxo anterior

Opcionalmente: Usuário pode fazer logout
└─ localStorage.removeItem('rmada_token')
└─ localStorage.removeItem('rmada_role')
```

### Defesa Civil Acessando (Emergência)

```
1. Alerta de emergência detectado pelo sistema
2. SMS/WhatsApp com link: http://localhost:8080
3. Agente abre link no navegador
4. Modal de autenticação aparece
5. Clica aba "Defesa Civil"
6. Preenche apenas: Código
   └─ DEFESA_CIVIL_2024_CODIGO_SEGURO
7. Clica "Entrar Defesa Civil"
8. Servidor verifica código
9. Emite JWT token anônimo:
   └─ userId: "defense-" + UUID aleatório
   └─ role: 'defense'
   └─ ⚠️ NÃO persiste em BD
10. Token salvo em localStorage
11. WebSocket conecta com token
12. ✅ Dashboard carrega (acesso limitado)
13. Agente vê dados em tempo real
14. Pode ver alertas e notificações
15. Mas NÃO pode editar dados
```

---

## 🧪 Testes Manuais

### Teste 1: Acesso sem Token

```bash
# Terminal 1
npm start

# Terminal 2
# Deve retornar 403
curl http://localhost:8080/api/devices

# Resultado esperado:
# {"error":"authentication required"}
```

### Teste 2: Registrar Proprietário

```bash
curl -X POST http://localhost:8080/api/register-owner \
  -H "Content-Type: application/json" \
  -d '{
    "username":"alice_test",
    "password":"Test@1234",
    "ownerCode":"PROPRIETARIO_2024_SENHA_FORTE"
  }'

# Resultado esperado:
# {"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...","role":"owner"}
```

### Teste 3: Usar Token Proprietário

```bash
# Salvar token anterior como variável
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Acessar API protegida
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/devices

# Resultado esperado:
# [{"id":"D1","status":"offline",...}, {"id":"D2",...}, ...]
```

### Teste 4: Enviar Telemetria como Proprietário

```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/telemetry \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"D1","value":42.5}'

# Resultado esperado:
# {"status":"ok","received":{"deviceId":"D1","value":42.5,...}}
```

### Teste 5: Defesa Civil Não Pode Enviar Dados

```bash
# Login Defesa Civil
curl -X POST http://localhost:8080/api/login-defense \
  -H "Content-Type: application/json" \
  -d '{"code":"DEFESA_CIVIL_2024_CODIGO_SEGURO"}'

# Resultado: {"token":"eyJ...","role":"defense"}
DEFENSE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Tentar enviar telemetria
curl -X POST -H "Authorization: Bearer $DEFENSE_TOKEN" \
  http://localhost:8080/api/telemetry \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"D1","value":42.5}'

# Resultado esperado:
# {"error":"only owners can submit telemetry"}
```

---

## 🚨 Troubleshooting

### Problema 1: "authentication required" ao acessar dashboard

**Causa:** Token não enviado ou inválido

**Solução:**
```bash
1. Abrir DevTools (F12)
2. Console → localStorage
3. Verificar se rmada_token existe
4. Se não → Fazer login novamente
5. Se sim → Verificar se valor está completo
```

### Problema 2: "invalid owner code"

**Causa:** Código digitado incorretamente ou diferente do .env

**Solução:**
```bash
1. Verificar .env
2. Copiar OWNER_CODE exatamente
3. Certificar que não tem espaços extras
4. Comparar case-sensitive (maiúsculas/minúsculas)
5. Restart servidor após mudar .env
```

### Problema 3: Token expirou

**Causa:** Mais de 24 horas se passaram desde login

**Solução:**
```
1. Fazer login novamente
2. Novo token será gerado
3. localStorage será atualizado
4. Dashboard carregará
```

### Problema 4: WebSocket não conecta

**Causa:** Token não sendo enviado na URL

**Solução:**
```javascript
// Verificar no console
localStorage.getItem('rmada_token')
// Se vazio → Fazer login
// Se preenchido → Restart navegador
```

### Problema 5: "403 Forbidden" em /api/telemetry

**Causa:** Usuário não é proprietário

**Solução:**
```
1. Se for Defesa Civil: Isto é esperado (read-only)
2. Se for Proprietário: Token pode ter expirado
3. Fazer login novamente como Proprietário
```

---

## 📊 Monitoramento

### Ver Logs em Tempo Real

```bash
# Terminal onde servidor está rodando
npm start

# Verá logs assim:
# Server running on http://localhost:8080
# WebSocket client connected
# Telemetry received from D1: 42.5
# Device D2 registered: 10.0.0.2
```

### Verificar Usuários Registrados

```bash
# Arquivo users.json armazena proprietários
cat users.json

# Formato:
# [
#   {
#     "id": "550e8400-e29b-41d4-a716-446655440000",
#     "username": "alice_test",
#     "passwordHash": "$2b$10$xK9j5bF2mL3pQv7...",
#     "role": "owner"
#   }
# ]
```

### Tokens Ativos

```javascript
// server.js mantém tokens em memória:
// const tokens = new Map();
// Cada token tem: userId, role, expires

// Para ver tokens ativos (no código):
console.log(tokens.size);  // Número de tokens
```

---

## ⚙️ Configuração Avançada

### Customizar Expiração de Token

```bash
# No código server.js (linha ~46)
const expires = Date.now() + 24*60*60*1000; // 24 horas

# Para 1 hora:
const expires = Date.now() + 1*60*60*1000;

# Para 7 dias:
const expires = Date.now() + 7*24*60*60*1000;
```

### Customizar Bcrypt Rounds

```bash
# No código server.js (linha ~180)
const hash = bcrypt.hashSync(password, 10); // 10 rounds

# Para mais segurança (mais lento):
const hash = bcrypt.hashSync(password, 12); // 12 rounds

# Para menos overhead (menos seguro):
const hash = bcrypt.hashSync(password, 8);  // 8 rounds
```

### Habilitar CORS para Outros Domínios

```bash
# No código server.js (linha ~22)
app.use(cors());

# Para específico:
app.use(cors({ origin: 'https://seu-dominio.com' }));
```

---

## 🔄 Fluxo Típico de Operação

### Cenário 1: Dia Normal (Proprietário)

```
08:00 → Proprietário abre dashboard
        └─ Token enviado automaticamente
        └─ Dispositivos conectados
        └─ Gráficos carregam em tempo real

12:00 → Recebe alerta de valor crítico (D3)
        └─ Dashboard mostra aviso
        └─ Som de alerta toca
        └─ Notificação do navegador

14:00 → Envia novo ponto de telemetria
        └─ POST /api/telemetry (com token)
        └─ Gráfico atualiza

18:00 → Fecha navegador
        └─ Token permanece em localStorage
        └─ Válido até tomorrow 08:00
```

### Cenário 2: Emergência (Defesa Civil)

```
22:15 → Sistema detecta anomalia em D1
        └─ Risco de deslizamento iminente
        └─ Envia alerta SMS/WhatsApp

22:16 → Agente de Defesa Civil recebe SMS
        └─ Link: http://localhost:8080

22:17 → Agente abre link
        └─ Modal de autenticação
        └─ Insere código de acesso

22:18 → Token emitido
        └─ Dashboard carrega (2 segundos)
        └─ Vê mapa com risk zones
        └─ Comunica com equipes

22:30 → Evacua 50 pessoas
        └─ Usa dashboard para monitorar
        └─ Token ainda válido

00:00 → Situação estabilizada
        └─ Fecha navegador
        └─ Token expira (não importa)
```

---

## ✅ Checklist Inicial

- [ ] .env criado com OWNER_CODE e DEFENSE_CODE
- [ ] .env adicionado ao .gitignore
- [ ] npm install executado
- [ ] npm start funcionando
- [ ] Teste 1: Acesso sem token (403)
- [ ] Teste 2: Registrar proprietário (sucesso)
- [ ] Teste 3: Usar token proprietário (sucesso)
- [ ] Teste 4: Enviar telemetria como owner (sucesso)
- [ ] Teste 5: Defesa Civil não pode enviar (403)
- [ ] Dashboard carrega para proprietário
- [ ] Dashboard carrega para Defesa Civil (read-only)
- [ ] Alertas funcionam em tempo real

---

## 📞 Suporte

**Se algo não funcionar:**

1. Verificar console do navegador (F12)
2. Verificar logs do servidor (terminal)
3. Verificar que .env está correto
4. Restart servidor
5. Limpar localStorage: `localStorage.clear()`
6. Fazer login novamente

---

**Sistema Pronto para Produção! 🚀**

Versão: 2.0 — Sistema Seguro  
Data: 13 de Novembro de 2025  
Status: ✅ OPERACIONAL
