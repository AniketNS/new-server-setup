# 🐳 Docker Nginx Reverse Proxy — Server Setup Script

A single bash script to bootstrap a fresh Linux server with a Dockerized Nginx reverse proxy, SSL support via Certbot, a shared Docker network, and handy shell aliases — all in one command.

---

## What It Does

- Creates the full directory structure for your project and proxy
- Writes all config files (`nginx.conf`, `proxy.conf`, `docker-compose.yml`, `Dockerfile`)
- Sets up a Docker `shared` network (skips safely if it already exists)
- Adds shell aliases to `~/.bashrc` (duplicate-safe)
- Sources `~/.bashrc` automatically

---

## Directory Structure Created

```
~/docker/
├── <project-name>/
│   └── app/
│       └── code/
└── proxy/
    ├── default/
    │   ├── nginx.conf
    │   └── proxy.conf
    ├── nginx-config/        ← drop your site .conf files here
    ├── certs/
    │   └── letsencrypt/
    ├── Dockerfile
    └── docker-compose.yml
```

---

## Requirements

- Ubuntu/Debian Linux
- Docker installed and running
- Bash

---

## Usage

```bash
bash setup-server.sh <project-name>
```

**Example:**

```bash
bash setup-server.sh my-app
```

If you omit the project name it defaults to `project-name`:

```bash
bash setup-server.sh
```

---

## Shell Aliases Added

| Alias | Command | Description |
|-------|---------|-------------|
| `dc` | `docker compose` | Shorthand for docker compose |
| `pr` | `docker exec proxy_server nginx -s reload` | Reload Nginx inside the proxy container |

> **Note:** After the script runs, open a new terminal or run `source ~/.bashrc` manually for the aliases to take effect in your current session.

---

## After Setup

```bash
cd ~/docker/proxy

# Build and start the proxy container
dc up -d --build

# Add a site config
vi nginx-config/mysite.conf

# Reload Nginx after config changes
pr
```

---

## SSL / HTTPS

SSL certificates are expected at:

```
~/docker/proxy/certs/           ← general certs
~/docker/proxy/certs/letsencrypt/  ← Let's Encrypt certs
```

The Dockerfile installs `python3-certbot-nginx` so you can issue Let's Encrypt certificates directly from inside the container:

```bash
docker exec -it proxy_server certbot --nginx -d yourdomain.com
```

---

## Re-running the Script

The script is safe to run multiple times:

- Existing directories are left untouched (`mkdir -p`)
- Aliases already in `~/.bashrc` are skipped
- The `shared` Docker network is only created if it doesn't exist
