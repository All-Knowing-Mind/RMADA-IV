# RMADA — Real-time Monitoring IoT with Post-Quantum Security

Complete, portable IoT monitoring system for LoRa landslide detection devices with native post-quantum cryptography (Dilithium) and VPN integration.

**Status**: ✅ Stage 2 Complete (Native Dilithium + Device Client Ready)

## 🚀 Quick Start (Choose One)

### Option 1: Docker Compose (Easiest — 30 seconds)

```bash
git clone https://github.com/seu-usuario/rmada
cd rmada
docker-compose up -d
# Open: http://localhost:8080
```

### Option 2: Local Development (Node.js + Rust)

```bash
npm install
npm run build:dilithium-all
npm start
# Open: http://localhost:8080

# In another terminal, register owner:
TOKEN=$(curl -s -X POST http://localhost:8080/api/register-owner \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test123","ownerCode":"OWNER-001"}' | jq -r .token)

# Run device client:
bash device-client-example.sh http://localhost:8080 DEVICE-001 "$TOKEN"
```

## 📚 Documentation

- **[README-STAGE1.md](README-STAGE1.md)** — Stage 1 features (auth, WebSocket, WireGuard prep)
- **[README-STAGE2.md](README-STAGE2.md)** — Stage 2 features (native Dilithium, device client)  
- **[DEVICE-CLIENT-GUIDE.md](DEVICE-CLIENT-GUIDE.md)** — Complete device onboarding guide
- **[STAGE2-SUMMARY.md](STAGE2-SUMMARY.md)** — Implementation details

## 📂 Project Structure

```
RMADA/
├── 🖥️  Frontend: Dispositivo.html, Operação.html, app.js, styles.css
├── 🔧 Backend: server.js (Node.js + Express + WebSocket + Dilithium)
├── 🔐 Dilithium: meu_projeto_dilithium/ (Rust native verifier)
├── 🛠️  Scripts: generate_dilithium_keys.sh, device-client-example.sh, test-stage2-e2e.sh
├── 📦 Docker: docker-compose.yml, Dockerfile.server, Earthfile
└── 📝 Docs: README-STAGE1.md, README-STAGE2.md, DEVICE-CLIENT-GUIDE.md
```

## ✨ Features

✅ Real-time dashboard (6 charts, responsive, mobile-friendly)  
✅ Role-based authentication (owner/defense roles)  
✅ Dilithium3 post-quantum signatures (native Rust, no OpenSSL)  
✅ Device onboarding with security  
✅ WireGuard VPN integration (optional)  
✅ WebSocket real-time broadcasts  
✅ Docker Compose deployment  
✅ Portable to any device (PC, mobile host, cloud)  
✅ Complete end-to-end test suite  
✅ Comprehensive documentation  

## 🔐 Security

- **Device Auth**: Dilithium3 (post-quantum safe)
- **VPN**: WireGuard (optional for stage 1, Lightway in stage 3)
- **Server**: No external crypto dependencies (native pqc_dilithium)

## 🎯 Roadmap

| Stage | Status | Highlights |
|-------|--------|------------|
| **1** | ✅ Complete | Dashboard, Auth, WebSocket, WireGuard prep |
| **2** | ✅ Complete | Native Dilithium, Device client, Portability |
| **3** | 🟡 Planned | HTTPS, Lightway VPN, SQLite persistence |
| **4** | 🔵 Future | Mobile app, Cloud deployment |

## 📞 Quick Links

- **Issues & Features**: GitHub Issues
- **Full README**: See markdown files above
- **Test Script**: `bash test-stage2-e2e.sh`
- **Device Setup**: `bash device-client-example.sh http://localhost:8080 DEVICE-001 <token>`

---

**Last Updated**: 2025-11-11 | **Version**: Stage 2
cd "C:\Users\Usuario\Desktop\HTML - CSS - JAVA WEBSITE"
npm install
npm start
```

2. Open the browser at `http://localhost:8080/Dispositivo.html`.

3. Use the UI `Inscreva-se` modal to register an owner (use the `OWNER_CODE` you configured in the environment) or to login as Defesa Civil (with `DEFENSE_CODE`).

## Generating TLS keys and (optionally) Dilithium keys

This repo includes `generate_keys.sh` which will create a local CA, server and client certificates under `./keys` using OpenSSL. If your OpenSSL is configured with an OQS provider that exposes `dilithium3`, the script will try to generate `dilithium_priv.pem` and `dilithium_pub.pem` as well.

Usage (PowerShell / Bash):

```powershell
./generate_keys.sh --outdir ./keys --noninteractive
```

Notes:
- If `openssl list -public-key-algorithms` shows `dilithium3`, the script will run the OpenSSL commands to generate Dilithium keys.
- If OpenSSL does not support Dilithium directly, install or enable an OQS provider (liboqs/oqs-provider) or create Dilithium keys with your existing toolchain and place them in the `keys/` folder.

## Earthly / Docker

There is an `Earthfile` that provides these targets:
- `+keys` — runs `generate_keys.sh` inside a small Alpine image and outputs the `keys/` artifact.
- `+server` — builds a Node image with WireGuard tools installed.
- `+all` — runs `+keys` then `+server` and copies artifacts together.

Example Earthly usage:

```bash
earthly +keys
earthly +server
earthly +all
```

Or build and run with Docker directly (example):

```powershell
# build
docker build -f Dockerfile.server -t rmada-server:dev .
# run (WireGuard/config may require --cap-add=NET_ADMIN or --privileged)
docker run -it --rm --cap-add=NET_ADMIN -p 8080:8080 --name rmada-server rmada-server:dev
```

## Integrando Dilithium com OpenSSL

- If you have a custom OpenSSL build with the OQS provider (liboqs) enabled, OpenSSL may expose post-quantum algorithms such as `dilithium3`. In that case, `openssl genpkey -algorithm dilithium3` will work and the keys can be used for signatures.
- The `generate_keys.sh` script attempts to detect this and produce `dilithium_priv.pem` and `dilithium_pub.pem` under the specified `--outdir`.
- Use Dilithium keys for signing device registration tokens or firmware; continue to use TLS certs for network encryption (WireGuard/TLS). In other words: Dilithium is used for signature/authentication, while TLS/WireGuard provide encryption and tunneling.

## Notes and security

- This is scaffolding for development/testing. For production you must harden:
  - use strong secrets stored in a secret manager (don't use `OWNER-SECRET-CHANGEME`),
  - use TLS (HTTPS) for all provisioning endpoints,
  - manage token lifecycle and revocation with a persistent store,
  - run WireGuard on host or with appropriate capabilities.

## Removed files

- `keygen_dilithium.py` was removed: you requested OpenSSL-based flow and Earthly orchestration instead.

---

If you want, I can now:
- (A) Add endpoints to `server.js` for secure onboarding that verify Dilithium signatures before issuing WireGuard peer configs.
- (B) Create a DevContainer/VSCode task to run Earthly and the server reproducibly.

Tell me which one you prefer and I implement it next.

