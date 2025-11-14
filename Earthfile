## Earthfile - Orquestração RMADA
## Requer Earthly (https://earthly.dev). Este Earthfile tem alvos para:
##  - +keys : gerar certificados e chaves (invoca generate_keys.sh)
##  - +server: build da imagem do servidor (Node + wireguard-tools)
##  - +all: roda +keys e +server

VERSION 0.6

args:
  BASE_IMAGE=node:18-bullseye

build +keys:
  FROM alpine:3.18
  RUN apk add --no-cache openssl bash coreutils
  WORKDIR /workspace
  COPY generate_keys.sh ./
  RUN chmod +x generate_keys.sh
  # gera keys no contexto /workspace/keys
  RUN ./generate_keys.sh --outdir ./keys --noninteractive
  # exporta keys como artifact
  EXPORT ./keys

build +server:
  FROM ${BASE_IMAGE}
  RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools iproute2 iputils-ping ca-certificates \
    && rm -rf /var/lib/apt/lists/*
  WORKDIR /workspace
  COPY package.json package-lock.json* ./
  RUN npm install --production || true
  COPY . .
  RUN chmod +x docker-entrypoint.sh
  ENTRYPOINT ["/workspace/docker-entrypoint.sh"]
  CMD ["node","server.js"]

build +dilithium-all:
  FROM rust:latest as builder
  WORKDIR /workspace
  COPY meu_projeto_dilithium ./
  RUN cargo build --release --bins
  SAVE ARTIFACT /workspace/target/release/dilithium_verify /dilithium_verify
  SAVE ARTIFACT /workspace/target/release/dilithium_keygen /dilithium_keygen
  SAVE ARTIFACT /workspace/target/release/sign /dilithium_sign

build +lightway-base:
  FROM rust:latest as builder
  RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
  WORKDIR /workspace
  COPY lightway-main ./
  RUN cd lightway-server && cargo build --release 2>&1 || echo "Lightway build info logged"
  SAVE ARTIFACT /workspace/lightway-server/target/release/lightway-server /lightway-server

build +complete-image:
  FROM ${BASE_IMAGE}
  RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools iproute2 iputils-ping ca-certificates openssl bash \
    && rm -rf /var/lib/apt/lists/*
  WORKDIR /workspace
  COPY package.json package-lock.json* ./
  RUN npm install --production || true
  COPY . .
  # Copiar binários Dilithium do build anterior
  COPY +dilithium-all/dilithium_verify /workspace/meu_projeto_dilithium/target/release/dilithium_verify
  COPY +dilithium-all/dilithium_keygen /workspace/meu_projeto_dilithium/target/release/dilithium_keygen
  COPY +dilithium-all/dilithium_sign /workspace/meu_projeto_dilithium/target/release/sign
  RUN chmod +x /workspace/meu_projeto_dilithium/target/release/dilithium_* /workspace/meu_projeto_dilithium/target/release/sign
  COPY +lightway-base/lightway-server /usr/local/bin/lightway-server || echo "Lightway optional"
  RUN chmod +x /docker-entrypoint.sh
  EXPOSE 8080 51820/udp
  ENTRYPOINT ["/docker-entrypoint.sh"]
  CMD ["npm", "start"]
  SAVE IMAGE rmada:stage2

build +all:
  BUILD +keys
  BUILD +server
  BUILD +dilithium-all
  BUILD +lightway-base
  BUILD +complete-image

# Use: earthly +keys                # gera chaves
#      earthly +server              # build Node server
#      earthly +dilithium-all       # build todos os binários Dilithium
#      earthly +lightway-base       # build Lightway server
#      earthly +complete-image      # build imagem completa (Stage 2)
#      earthly +all                 # build tudo junto
