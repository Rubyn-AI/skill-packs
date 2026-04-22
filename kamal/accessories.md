---
name: kamal-accessories
triggers:
  - kamal accessory
  - kamal database
  - kamal redis
  - kamal postgres
  - sidecar container
gems:
  - kamal
rails: ">=7.0"
---

# Kamal Accessories

Accessories are supporting services (databases, Redis, job runners) deployed alongside your app. They run as Docker containers on the same or different servers.

## Pattern: PostgreSQL as an accessory

```yaml
# config/deploy.yml
accessories:
  db:
    image: postgres:16
    host: 192.168.0.1
    port: 5432
    env:
      clear:
        POSTGRES_DB: myapp_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
    options:
      shm-size: 256m
```

## Pattern: Redis as an accessory

```yaml
accessories:
  redis:
    image: redis:7-alpine
    host: 192.168.0.1
    port: 6379
    cmd: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    directories:
      - data:/data
```

## Pattern: Sidekiq job runner

```yaml
servers:
  web:
    hosts:
      - 192.168.0.1
    cmd: bin/rails server
  
  job:
    hosts:
      - 192.168.0.1
    cmd: bundle exec sidekiq -C config/sidekiq.yml
    options:
      memory: 1g
```

`job` runs on the same host as `web` but as a separate container with its own process.

## Managing accessories

```bash
kamal accessory boot db      # Start the database
kamal accessory reboot redis  # Restart Redis
kamal accessory logs db       # View database logs
kamal accessory exec db 'psql -U postgres myapp_production'  # Shell into Postgres
```

## Anti-pattern: Running the database on the same server as the app without volume mounts

```yaml
# BAD — data lost on container restart
accessories:
  db:
    image: postgres:16
    host: 192.168.0.1
    # No directories: — data is ephemeral!

# GOOD — persist data to the host
accessories:
  db:
    image: postgres:16
    host: 192.168.0.1
    directories:
      - data:/var/lib/postgresql/data  # Survives container restarts
```

Always mount a host directory for database data. Without it, restarting the container destroys your data.
