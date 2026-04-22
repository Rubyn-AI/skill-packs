---
name: kamal-deployment-basics
triggers:
  - kamal deploy
  - kamal setup
  - deploy.yml
  - kamal init
  - docker deploy
  - container deploy
  - zero downtime
gems:
  - kamal
rails: ">=7.0"
---

# Kamal Deployment Basics

Kamal deploys Rails apps as Docker containers to any server with SSH access. No Kubernetes, no PaaS — just Docker on a VPS.

## Pattern: Initial setup

```bash
gem install kamal
kamal init
```

This generates `config/deploy.yml` and `.kamal/secrets`.

## Pattern: Minimal deploy.yml

```yaml
# config/deploy.yml
service: myapp
image: myorg/myapp

servers:
  web:
    hosts:
      - 192.168.0.1
    labels:
      traefik.http.routers.myapp.rule: Host(`myapp.com`)

registry:
  server: ghcr.io
  username: myorg
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    RAILS_LOG_TO_STDOUT: true
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL

builder:
  multiarch: false  # Set true if building on Apple Silicon for x86 servers

proxy:
  ssl: true
  host: myapp.com

volumes:
  - "myapp_storage:/rails/storage"
```

## Pattern: First deploy

```bash
# Set secrets
kamal secrets set KAMAL_REGISTRY_PASSWORD=ghp_xxxx
kamal secrets set RAILS_MASTER_KEY=$(cat config/master.key)
kamal secrets set DATABASE_URL=postgres://...
kamal secrets set REDIS_URL=redis://...

# Initial setup (installs Docker, Traefik proxy, creates network)
kamal setup

# Subsequent deploys
kamal deploy
```

`kamal setup` is run once. It installs Docker on the server, starts the Traefik proxy, and deploys your app. After that, `kamal deploy` does zero-downtime rolling deploys.

## Pattern: Zero-downtime deployment flow

1. Build Docker image locally (or via CI)
2. Push to container registry
3. Pull new image on each server
4. Start new container alongside the old one
5. Health check passes → Traefik routes traffic to new container
6. Stop old container

```yaml
# Health check configuration
healthcheck:
  path: /up
  port: 3000
  interval: 1s
  max_attempts: 30
```

## Pattern: Running migrations during deploy

```yaml
# config/deploy.yml
servers:
  web:
    hosts:
      - 192.168.0.1
    cmd: bin/rails server

# Run migrations on a single host before rolling out
hooks:
  pre-deploy:
    - kamal app exec --primary 'bin/rails db:migrate'
```

Or use the built-in approach:

```bash
kamal deploy  # Deploys and runs migrations automatically if configured
```

## Anti-pattern: Deploying without health checks

```yaml
# BAD — no health check, Kamal can't verify the new container is healthy
# If the container crashes on startup, traffic routes to a dead container

# GOOD — always configure a health check
healthcheck:
  path: /up
  port: 3000
  max_attempts: 30
```

Rails 7.1+ generates a `/up` health check endpoint by default. Use it.

## Key commands

| Command | What it does |
|---------|-------------|
| `kamal setup` | First-time server provisioning |
| `kamal deploy` | Build, push, deploy with zero downtime |
| `kamal rollback` | Revert to the previous version |
| `kamal app logs` | Tail application logs |
| `kamal app exec 'rails console'` | Open Rails console on the server |
| `kamal app exec 'rails db:migrate'` | Run migrations |
| `kamal proxy reboot` | Restart the Traefik proxy |
| `kamal lock` | Lock deployments (prevent concurrent deploys) |
