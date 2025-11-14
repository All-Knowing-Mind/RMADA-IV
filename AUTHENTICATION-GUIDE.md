# 🔐 RMADA Authentication & Registration Guide

## Overview: 3 Types of Users

O sistema RMADA suporta **3 tipos de usuários** com inscrição e autenticação diferentes:

```
┌─────────────────────────────────────────────────────────┐
│           TIPOS DE USUÁRIOS NO RMADA                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ 1️⃣  USUÁRIO COMUM (Visitante/Observador)              │
│     └─ Acessa dashboard apenas (sem edições)          │
│     └─ NÃO precisa se inscrever                       │
│     └─ Acesso anônimo ao /Operação.html               │
│                                                          │
│ 2️⃣  PROPRIETÁRIO (Owner) — Gerenciador               │
│     └─ Controla dispositivos LoRa/VPN                 │
│     └─ Cadastra novos dispositivos                     │
│     └─ Acessa dados históricos + relatórios           │
│     └─ Requer: Username + Senha + Código Proprietário │
│     └─ Token válido por 1 hora                        │
│                                                          │
│ 3️⃣  DEFESA CIVIL (Defense) — Resposta Emergencial    │
│     └─ Acesso prioritário durante desastres           │
│     └─ Visualiza alertas em tempo real                │
│     └─ Sem criação de conta persistente               │
│     └─ Requer apenas: Código Defesa Civil             │
│     └─ Token temporário por 1 hora                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 1️⃣ Usuário Comum (Visitante)

### Como Funciona?

**Usuários comuns NÃO precisam se inscrever.** Eles apenas acessam o website normalmente:

```
┌──────────────────────────────────────────────┐
│  USUÁRIO COMUM — FLUXO SEM AUTENTICAÇÃO      │
├──────────────────────────────────────────────┤
│                                               │
│  1. Abre navegador                          │
│  ↓                                            │
│  2. Acessa http://localhost:8080            │
│  ↓                                            │
│  3. Vê página Operação.html                 │
│  ↓                                            │
│  4. Dashboard com gráficos em tempo real    │
│  ↓                                            │
│  5. Notificações sonoras + visuais          │
│  ↓                                            │
│  RESULTADO: Acesso completo, sem token!    │
│                                               │
└──────────────────────────────────────────────┘
```

### Permissões

| Ação | Permitido |
|------|-----------|
| Ver dashboard | ✅ Sim |
| Ver gráficos | ✅ Sim |
| Receber notificações | ✅ Sim |
| Editar dispositivos | ❌ Não |
| Acessar /api/admin | ❌ Não |
| Cadastrar novos dispositivos | ❌ Não |
| Visualizar histórico completo | ⚠️ Últimas 60 pontos apenas |

### Vantagens

✅ **Acesso imediato** — Sem necessidade de criar conta  
✅ **Seguro** — Dados públicos apenas (alertas, gráficos)  
✅ **Rápido** — Sem overhead de autenticação  
✅ **Público** — Ideal para emergências onde informação deve ser acessível  

---

## 2️⃣ Proprietário (Owner) — Registro Completo

### Como Funciona?

O **Proprietário** é um **usuário gerenciador** que precisa se inscrever com credenciais e código especial.

```
┌──────────────────────────────────────────────────────────┐
│  PROPRIETÁRIO — FLUXO DE INSCRIÇÃO COMPLETO              │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  PASSO 1: Abrir Modal de Inscrição                       │
│  ─────────────────────────────────────────────────────   │
│  • Clica em "Inscreva-se" no navbar/hero                │
│  • Abre modal "Inscreva-se / Entrar"                    │
│  • Seleciona aba "Registrar (Owner)"                    │
│                                                            │
│  PASSO 2: Preencher Formulário                          │
│  ─────────────────────────────────────────────────────   │
│  • Campo: "Usuário (owner)"                            │
│    └─ Exemplo: "joao_silva_123"                        │
│                                                            │
│  • Campo: "Senha"                                       │
│    └─ Exemplo: "MinhaS3nh@F0rt3!"                      │
│    └─ Requisitos: Mín 8 caracteres recomendado         │
│                                                            │
│  • Campo: "Código do Proprietário"                      │
│    └─ Este é um código secreto fornecido               │
│    └─ Exemplo: "OWNER2024SECRET"                       │
│    └─ Armazenado em: env OWNER_CODE                    │
│                                                            │
│  PASSO 3: Enviar para Servidor                         │
│  ─────────────────────────────────────────────────────   │
│  • Clica botão "Registrar Owner"                       │
│  • Frontend envia POST para /api/register-owner:       │
│                                                            │
│    POST /api/register-owner                            │
│    Content-Type: application/json                       │
│                                                            │
│    {                                                      │
│      "username": "joao_silva_123",                     │
│      "password": "MinhaS3nh@F0rt3!",                   │
│      "ownerCode": "OWNER2024SECRET"                    │
│    }                                                      │
│                                                            │
│  PASSO 4: Servidor Valida                              │
│  ─────────────────────────────────────────────────────   │
│  ✓ Verifica se ownerCode === OWNER_CODE (env var)    │
│  ✓ Verifica se username já existe                      │
│  ✓ Valida comprimento de password                      │
│  ✓ Se falhar, retorna erro 403 (código inválido)     │
│                                                            │
│  PASSO 5: Criar Conta                                  │
│  ─────────────────────────────────────────────────────   │
│  • Gera hash da senha com bcryptjs (10 rounds)        │
│  • Cria ID único (UUID v4)                             │
│  • Armazena em memory (users array)                    │
│  • Salva em arquivo users.json para persistência       │
│                                                            │
│  PASSO 6: Emitir Token                                 │
│  ─────────────────────────────────────────────────────   │
│  • Cria JWT token assinado                             │
│  • Payload: { userId, role: 'owner' }                 │
│  • Expira em: 1 hora (3600 segundos)                  │
│  • Retorna ao frontend                                 │
│                                                            │
│  PASSO 7: Armazenar Token                              │
│  ─────────────────────────────────────────────────────   │
│  • Frontend salva em localStorage:                     │
│    localStorage.setItem('rmada_token', token)         │
│  • Próximos requests enviam: Authorization: Bearer X  │
│                                                            │
│  RESULTADO: ✅ Inscrição concluída, Token ativo!     │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

### Detalhes Técnicos

#### Código do Proprietário

O código `OWNER_CODE` é definido no servidor via variável de ambiente:

```bash
# .env ou variável de ambiente
OWNER_CODE=OWNER2024SECRET
```

**Por que usar código?** 
- ✅ Evita registro anônimo
- ✅ Só proprietários válidos podem criar conta
- ✅ Funciona como "chave mestre" inicial
- ✅ Muda em cada deployment (segurança)

#### Hashing de Senha

```javascript
// server.js linha 180
const hash = bcrypt.hashSync(password, 10);
// 10 = número de rounds (mais = mais seguro, mais lento)
// Exemplo: "MinhaS3nh@F0rt3!" → "$2b$10$xK9j5bF2mL3pQ..."
```

**Segurança:**
- ✅ Senha **nunca** armazenada em texto plano
- ✅ Hash é determinístico (mesmo password = diferente hash sempre)
- ✅ Impossível reverter hash para password original
- ✅ 10 rounds = ~100ms por verificação (bom balanço)

#### JWT Token

```javascript
// server.js linha 212
const token = issueToken(userId, 'owner');
// Retorna: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

// Payload decodificado:
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "role": "owner",
  "iat": 1699867200,
  "exp": 1699870800  // 1 hora depois
}
```

### Como Logar Depois (Proprietário Existente)

Após registrar, o proprietário pode fazer login:

```
1. Modal → Aba "Entrar"
2. Username: joao_silva_123
3. Senha: MinhaS3nh@F0rt3!
4. Clica "Entrar"
5. ✅ JWT token enviado, salvo em localStorage
```

### API Detalhada

#### POST /api/register-owner

```bash
curl -X POST http://localhost:8080/api/register-owner \
  -H "Content-Type: application/json" \
  -d '{
    "username": "joao_silva_123",
    "password": "MinhaS3nh@F0rt3!",
    "ownerCode": "OWNER2024SECRET"
  }'
```

**Respostas Possíveis:**

```javascript
// ✅ Sucesso (201)
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "owner"
}

// ❌ Código inválido (403)
{
  "error": "invalid owner code"
}

// ❌ Usuário já existe (409)
{
  "error": "user exists"
}

// ❌ Campos faltando (400)
{
  "error": "username,password,ownerCode required"
}
```

### Permissões do Proprietário

| Ação | Permitido |
|------|-----------|
| Ver dashboard | ✅ Sim |
| Editar dispositivos | ✅ Sim |
| Cadastrar novos | ✅ Sim |
| Excluir dispositivos | ✅ Sim |
| Acessar /api/admin | ✅ Sim |
| Visualizar histórico completo | ✅ Sim (sem limite) |
| Gerar relatórios | ✅ Sim |
| Visualizar alertas | ✅ Sim |

---

## 3️⃣ Defesa Civil (Defense) — Login Sem Conta

### Como Funciona?

A **Defesa Civil** é um acesso **emergencial sem persistência de conta**. Usa apenas código secreto:

```
┌──────────────────────────────────────────────────────────┐
│  DEFESA CIVIL — FLUXO RÁPIDO (SEM CADASTRO)              │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  PASSO 1: Abrir Modal                                    │
│  ─────────────────────────────────────────────────────   │
│  • Clica em "Inscreva-se" no navbar                     │
│  • Abre modal "Inscreva-se / Entrar"                    │
│  • Seleciona aba "Defesa Civil"                         │
│                                                            │
│  PASSO 2: Inserir Código                                │
│  ─────────────────────────────────────────────────────   │
│  • Campo: "Código Defesa Civil"                        │
│    └─ Exemplo: "DEFENSE2024EMERGENCY"                 │
│    └─ Este é um código secreto                         │
│    └─ Armazenado em: env DEFENSE_CODE                 │
│                                                            │
│  PASSO 3: Submeter                                      │
│  ─────────────────────────────────────────────────────   │
│  • Clica "Entrar Defesa Civil"                         │
│  • Frontend envia POST para /api/login-defense:        │
│                                                            │
│    POST /api/login-defense                             │
│    Content-Type: application/json                       │
│                                                            │
│    {                                                      │
│      "code": "DEFENSE2024EMERGENCY"                    │
│    }                                                      │
│                                                            │
│  PASSO 4: Servidor Valida Código                       │
│  ─────────────────────────────────────────────────────   │
│  • Compara com DEFENSE_CODE (env var)                 │
│  • Se inválido: retorna erro 403                      │
│  • Se válido: segue                                     │
│                                                            │
│  PASSO 5: Gerar Token Temporário                       │
│  ─────────────────────────────────────────────────────   │
│  • Cria JWT token anônimo                              │
│  • userId: "defense-" + UUID aleatório                │
│  • role: "defense"                                      │
│  • Expira em: 1 hora                                   │
│  • ⚠️ NÃO cria entrada no banco (temporário)          │
│                                                            │
│  PASSO 6: Retornar Token                               │
│  ─────────────────────────────────────────────────────   │
│  {                                                        │
│    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...", │
│    "role": "defense"                                     │
│  }                                                        │
│                                                            │
│  PASSO 7: Acesso Imediato                              │
│  ─────────────────────────────────────────────────────   │
│  • Token salvo em localStorage                         │
│  • Acesso total ao dashboard                          │
│  • Visualiza alertas em tempo real                     │
│  • Pode receber notificações                           │
│                                                            │
│  RESULTADO: ✅ Defesa Civil online em 5 segundos!    │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

### Por Que Não Ter Conta Persistente?

A Defesa Civil **não cria usuário persistente** porque:

✅ **Velocidade** — Acesso em segundos durante emergência  
✅ **Segurança** — Sem dados pessoais armazenados  
✅ **Temporário** — Token expira após 1 hora  
✅ **Multi-acesso** — Múltiplos agentes com mesmo código  
✅ **Auditoria** — Cada acesso é rastreável pelo logs  

### API Detalhada

#### POST /api/login-defense

```bash
curl -X POST http://localhost:8080/api/login-defense \
  -H "Content-Type: application/json" \
  -d '{
    "code": "DEFENSE2024EMERGENCY"
  }'
```

**Respostas Possíveis:**

```javascript
// ✅ Sucesso (200)
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "defense"
}

// ❌ Código inválido (403)
{
  "error": "invalid defense code"
}

// ❌ Código ausente (400)
{
  "error": "code required"
}
```

### Permissões da Defesa Civil

| Ação | Permitido |
|------|-----------|
| Ver dashboard | ✅ Sim |
| Ver alertas em tempo real | ✅ Sim |
| Receber notificações | ✅ Sim (prioritário) |
| Editar dispositivos | ❌ Não |
| Cadastrar novos | ❌ Não |
| Excluir dispositivos | ❌ Não |
| Acessar /api/admin | ❌ Não |
| Visualizar histórico | ✅ Sim (últimos 60 pontos) |
| Gerar relatórios | ❌ Não |

---

## 🔄 Comparação: Fluxo de Cada Tipo

### Tabela Comparativa

| Aspecto | Comum | Proprietário | Defesa Civil |
|--------|-------|--------------|---|
| **Necessita inscrição** | ❌ Não | ✅ Sim | ❌ Não |
| **Username/Senha** | ❌ Não | ✅ Sim | ❌ Não |
| **Código especial** | ❌ Não | ✅ OWNER_CODE | ✅ DEFENSE_CODE |
| **Token JWT** | ❌ Não | ✅ Sim (1h) | ✅ Sim (1h) |
| **Conta persistente** | ❌ Não | ✅ Sim | ❌ Não |
| **Tempo para acessar** | ⚡ Imediato | 🕐 30 segundos | ⚡ 5 segundos |
| **Ver dashboard** | ✅ Sim | ✅ Sim | ✅ Sim |
| **Editar dispositivos** | ❌ Não | ✅ Sim | ❌ Não |
| **Histórico completo** | ⚠️ 60 pontos | ✅ Todos | ⚠️ 60 pontos |
| **Caso de uso** | Observador público | Gerenciador | Resposta emergencial |

---

## 🔐 Segurança & Best Practices

### Proteção de Códigos Secretos

```bash
# ✅ CORRETO: Variáveis de ambiente
export OWNER_CODE="OWNER2024SECRET"
export DEFENSE_CODE="DEFENSE2024EMERGENCY"
npm start

# ❌ ERRADO: Hardcoded no código
const OWNER_CODE = "OWNER2024SECRET"; // Visível no git!
```

### Configuração Segura

```bash
# .env (NUNCA fazer commit disso!)
OWNER_CODE=OWNER2024SECRET_CHANGE_ME
DEFENSE_CODE=DEFENSE2024EMERGENCY_CHANGE_ME
PORT=8080
NODE_ENV=production

# .gitignore
.env
.env.local
users.json
*.db
```

### Senhas de Proprietário

✅ **Recomendações:**
- Mínimo 8 caracteres
- Misture maiúsculas, minúsculas, números, símbolos
- Não use informações pessoais
- Mude periodicamente
- Não compartilhe com Defesa Civil

Exemplo forte:
```
❌ joao123
❌ password
✅ MinhaS3nh@F0rt3!
✅ Rm@d@2024_SecureP@ss
```

### Expiração de Tokens

Todos os tokens expiram em **1 hora**:

```javascript
// Token expirado → precisa fazer login novamente
// Segurança: Se token for roubado, uso limitado
// Renovação: Fazer login novamente para novo token
```

---

## 🚀 Exemplos Práticos

### Exemplo 1: Novo Proprietário se Inscrevendo

```bash
# Pré-requisito: OWNER_CODE em .env
OWNER_CODE="MEU_CODIGO_SECRETO_2024"

# Frontend clica "Registrar Owner"
# Preenche:
#   Username: alice_manager
#   Senha: Alice@2024Secure!
#   Owner Code: MEU_CODIGO_SECRETO_2024

# Servidor processa:
curl -X POST http://localhost:8080/api/register-owner \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_manager",
    "password": "Alice@2024Secure!",
    "ownerCode": "MEU_CODIGO_SECRETO_2024"
  }'

# Resposta:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "owner"
}

# ✅ Alice agora pode gerenciar dispositivos!
```

### Exemplo 2: Visitante Casual

```
1. Abre navegador
2. Vai para http://localhost:8080/Operação.html
3. Vê dashboard com gráficos em tempo real
4. Recebe alertas sonoros
5. Pode compartilhar link com amigos (acesso público)
6. ❌ Não pode editar dispositivos
```

### Exemplo 3: Defesa Civil em Emergência

```
# Sistema detecta deslizamento iminente
# 10:30 — Servidor envia alerta via SMS/WhatsApp
# Mensagem: "ACESSE: localhost:8080 COM CÓDIGO"

# Agente de Defesa Civil:
1. Abre http://localhost:8080/Operação.html
2. Clica "Inscreva-se"
3. Aba "Defesa Civil"
4. Insere código: DEFENSE2024EMERGENCY
5. ⚡ 2 segundos depois: Dashboard completo visível
6. Vê mapa de risco em tempo real
7. Coordena evacuação baseado em dados
8. Salva vidas! 🚨

# Token expira em 1 hora
# Se ainda precisar, insere código novamente
```

---

## 🔑 Variáveis de Ambiente

### Obrigatórias

```bash
# .env (local testing)
OWNER_CODE=OWNER2024SECRET
DEFENSE_CODE=DEFENSE2024EMERGENCY
```

### Opcionais

```bash
# Customizar expiração (em segundos)
TOKEN_EXPIRY=3600  # 1 hora

# Customizar rounds de hashing (7-12 recomendado)
BCRYPT_ROUNDS=10

# Banco de dados
DATABASE_URL=./rmada.db
```

### Exemplo Completo .env

```bash
# Autenticação
OWNER_CODE=MINHA_SENHA_PROPRIETARIO_SEGURA
DEFENSE_CODE=MINHA_SENHA_DEFESA_CIVIL_SEGURA
TOKEN_EXPIRY=3600

# Servidor
PORT=8080
HOST=0.0.0.0
NODE_ENV=production

# Database
DATABASE_URL=./rmada.db
LOG_LEVEL=info

# VPN (se usando)
WIREGUARD_PRIVATE_KEY=wO+...
WIREGUARD_PORT=51820
```

---

## 📊 Fluxo Resumido (Diagrama)

```
┌─────────────┐
│  Visitante  │  → Acesso anônimo → Dashboard público
└─────────────┘

┌─────────────────────────────────────────┐
│      Novo Proprietário                  │
├─────────────────────────────────────────┤
│ Username + Senha + OWNER_CODE          │
│           ↓                              │
│ /api/register-owner                    │
│           ↓                              │
│ Validações (código correto, user único)│
│           ↓                              │
│ Hash senha + Cria JWT                 │
│           ↓                              │
│ ✅ Token retornado                     │
│           ↓                              │
│ Acesso completo: editar, cadastrar    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│    Proprietário Existente (Login)       │
├─────────────────────────────────────────┤
│ Username + Senha                       │
│           ↓                              │
│ /api/login                             │
│           ↓                              │
│ Encontra user + Valida senha           │
│           ↓                              │
│ Cria JWT                               │
│           ↓                              │
│ ✅ Token retornado                     │
│           ↓                              │
│ Acesso restaurado                      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Defesa Civil (Emergência)          │
├─────────────────────────────────────────┤
│ Apenas: DEFENSE_CODE                   │
│           ↓                              │
│ /api/login-defense                     │
│           ↓                              │
│ Valida código                          │
│           ↓                              │
│ Cria JWT anônimo (sem persistência)    │
│           ↓                              │
│ ✅ Token retornado (1 hora)            │
│           ↓                              │
│ Acesso emergencial ao dashboard        │
│           ↓                              │
│ Token expira (logout automático)       │
└─────────────────────────────────────────┘
```

---

## 🛠️ Troubleshooting

### Problema: "invalid owner code"

```
Causa: OWNER_CODE está errado no env
Solução:
  1. Verificar /api/register-owner no server.js
  2. Ver OWNER_CODE no .env
  3. Certificar que valor está exato (case-sensitive)
  4. Exemplo errado: "owner2024" vs "OWNER2024" ❌
  5. Restart servidor após mudar .env
```

### Problema: "user exists"

```
Causa: Username já foi registrado
Solução:
  1. Use outro username
  2. Ou delete em users.json (arquivo local)
  3. Ou resetar banco de dados
```

### Problema: Token expirou

```
Causa: 1 hora se passou desde login
Solução:
  1. Fazer login novamente
  2. Novo token é gerado
  3. Token armazenado em localStorage
  4. localStorage persiste no navegador
```

### Problema: "device not registered"

```
Causa: Tentou onboard sem ser proprietário
Solução:
  1. Fazer login como proprietário
  2. Registrar device com token válido
  3. Verificar que token está no Authorization header
```

---

## ✅ Checklist de Configuração

- [ ] OWNER_CODE definido em .env (seguro)
- [ ] DEFENSE_CODE definido em .env (seguro)
- [ ] .env está em .gitignore (não fazer commit!)
- [ ] Servidor iniciado com npm start
- [ ] Porta 8080 está acessível
- [ ] Modo de ambiente correto (development/production)
- [ ] Testes de inscrição executados:
  - [ ] Usuário comum acessou dashboard
  - [ ] Proprietário se inscreveu com sucesso
  - [ ] Defesa Civil fez login com código
  - [ ] Tokens expiraram após 1 hora
  - [ ] Tokens não foram expostos em logs

---

## 📚 Mais Informações

- **Segurança JWT**: Veja `https-config.js`
- **Database de Usuários**: Veja `database-init.js`
- **APIs Completas**: Veja `README-STAGE3.md`
- **Exemplos de Cliente**: Veja `device-client-example.sh`

---

**Versão**: 1.0  
**Última atualização**: 13 de Novembro de 2025  
**Status**: ✅ Completo e Documentado
