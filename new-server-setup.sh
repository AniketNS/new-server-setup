#!/bin/bash

# =============================================================
# Server Setup Script — Docker Nginx Reverse Proxy
# Usage: bash setup-server.sh [project-name]
# =============================================================

set -e

PROJECT_NAME="${1:-project-name}"
BASE_DIR="$HOME/docker"
PROXY_DIR="$BASE_DIR/proxy"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
info()   { echo -e "${CYAN}[→]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✘]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Server Setup — Nginx Reverse Proxy   ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# -------------------------------------------------------------
# 1. Create directory structure
# -------------------------------------------------------------
info "Creating directory structure..."

mkdir -p "$BASE_DIR/$PROJECT_NAME/app/code"
mkdir -p "$PROXY_DIR/default"
mkdir -p "$PROXY_DIR/nginx-config"
mkdir -p "$PROXY_DIR/certs/letsencrypt"

log "Directories created"

# -------------------------------------------------------------
# 2. nginx.conf
# -------------------------------------------------------------
info "Writing nginx.conf..."

cat > "$PROXY_DIR/default/nginx.conf" << 'EOF'
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {

    include    /etc/nginx/proxy.conf;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    server_names_hash_bucket_size 128;
    server_names_hash_max_size 512;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;

    client_max_body_size 100M;

    ssl_prefer_server_ciphers on;
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;
}
EOF

log "nginx.conf written"

# -------------------------------------------------------------
# 3. proxy.conf
# -------------------------------------------------------------
info "Writing proxy.conf..."

cat > "$PROXY_DIR/default/proxy.conf" << 'EOF'
proxy_headers_hash_max_size 512;
proxy_headers_hash_bucket_size 128;
proxy_max_temp_file_size 0;
EOF

log "proxy.conf written"

# -------------------------------------------------------------
# 4. docker-compose.yml
# -------------------------------------------------------------
info "Writing docker-compose.yml..."

cat > "$PROXY_DIR/docker-compose.yml" << 'EOF'
version: '3'

services:
  proxy_server:
    build: .
    container_name: proxy_server
    ports:
      - '80:80'
      - '443:443'
    restart: always
    networks:
      - shared
    volumes:
      - ./default/nginx.conf:/etc/nginx/nginx.conf:rw
      - ./default/proxy.conf:/etc/nginx/proxy.conf:rw
      - ./nginx-config:/etc/nginx/conf.d:rw
      - ./certs:/etc/ssl/certs
      - ./certs/letsencrypt:/etc/letsencrypt

networks:
  shared:
    external:
      name: shared
EOF

log "docker-compose.yml written"

# -------------------------------------------------------------
# 5. Dockerfile
# -------------------------------------------------------------
info "Writing Dockerfile..."

cat > "$PROXY_DIR/Dockerfile" << 'EOF'
FROM nginx:1.21

RUN apt update && apt install python3-certbot-nginx -y
EOF

log "Dockerfile written"

# -------------------------------------------------------------
# 6. Add aliases to ~/.bashrc
# -------------------------------------------------------------
info "Adding aliases to ~/.bashrc..."

ALIASES=(
    "alias dc='docker compose'"
    "alias pr='docker exec proxy_server nginx -s reload'"
)

for alias_line in "${ALIASES[@]}"; do
    if grep -qF "$alias_line" "$HOME/.bashrc"; then
        warn "Already exists, skipping: $alias_line"
    else
        echo "$alias_line" >> "$HOME/.bashrc"
        log "Added: $alias_line"
    fi
done

info "Sourcing ~/.bashrc..."
# shellcheck disable=SC1090
source "$HOME/.bashrc"
log "~/.bashrc sourced"

# -------------------------------------------------------------
# 7. Create Docker shared network (if not exists)
# -------------------------------------------------------------
# -------------------------------------------------------------
info "Ensuring Docker shared network exists..."

if docker network ls --format '{{.Name}}' | grep -q '^shared$'; then
    warn "Docker network 'shared' already exists — skipping"
else
    docker network create shared
    log "Docker network 'shared' created"
fi

# -------------------------------------------------------------
# 8. Summary
# -------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Setup Complete!                      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Project dir : ${CYAN}$BASE_DIR/$PROJECT_NAME/app/code${NC}"
echo -e "  Proxy dir   : ${CYAN}$PROXY_DIR${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. cd $PROXY_DIR"
echo -e "  2. dc up -d --build        ${CYAN}(uses 'dc' alias)${NC}"
echo -e "  3. Add your site configs to: $PROXY_DIR/nginx-config/"
echo -e "  4. Place SSL certs in:        $PROXY_DIR/certs/"
echo -e "  5. pr                      ${CYAN}(reload nginx via 'pr' alias)${NC}"
echo ""
