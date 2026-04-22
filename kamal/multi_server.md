---
name: kamal-multi-server
triggers:
  - kamal multi server
  - kamal roles
  - kamal load balancer
  - horizontal scaling
  - multi host
  - kamal scale
gems:
  - kamal
rails: ">=7.0"
---

# Kamal Multi-Server Deployment

## Pattern: Web + worker roles

```yaml
# config/deploy.yml
service: myapp
image: myorg/myapp

servers:
  web:
    hosts:
      - 192.168.0.1
      - 192.168.0.2
    cmd: bin/rails server
    labels:
      traefik.http.routers.myapp.rule: Host(`myapp.com`)

  worker:
    hosts:
      - 192.168.0.3
    cmd: bundle exec sidekiq -C config/sidekiq.yml
```

Web servers handle HTTP requests. Worker servers process background jobs. Different servers, same Docker image, different commands.

## Pattern: Horizontal scaling

Add more hosts to scale horizontally:

```yaml
servers:
  web:
    hosts:
      - 192.168.0.1
      - 192.168.0.2
      - 192.168.0.3
      - 192.168.0.4  # Just add another IP
```

Put a load balancer (DigitalOcean LB, Cloudflare, AWS ALB) in front of all web hosts. Each host runs the same container.

## Pattern: Per-destination environments (staging + production)

```yaml
# config/deploy.yml (shared)
service: myapp
image: myorg/myapp

# config/deploy.staging.yml
servers:
  web:
    hosts:
      - staging.myapp.com
proxy:
  host: staging.myapp.com

# config/deploy.production.yml
servers:
  web:
    hosts:
      - prod1.myapp.com
      - prod2.myapp.com
  worker:
    hosts:
      - worker1.myapp.com
proxy:
  host: myapp.com
```

```bash
kamal deploy -d staging
kamal deploy -d production
```

## Pattern: Rolling deploys across servers

Kamal deploys to one host at a time by default. The first host gets the new container, passes its health check, then Kamal moves to the next. At no point are all hosts running the old version.

```yaml
deploy:
  drain_timeout: 30  # Seconds to drain connections before stopping old container
```

## Pattern: Run migrations on one host only

```yaml
servers:
  web:
    hosts:
      - 192.168.0.1  # Primary — migrations run here
      - 192.168.0.2
      - 192.168.0.3
```

```bash
# Migrations run on the primary (first) host before deploying to others
kamal app exec --primary 'bin/rails db:migrate'
kamal deploy
```

## Anti-pattern: Different images per role

```yaml
# BAD — separate Dockerfiles for web and worker
servers:
  web:
    image: myorg/myapp-web
  worker:
    image: myorg/myapp-worker

# GOOD — same image, different command
servers:
  web:
    cmd: bin/rails server
  worker:
    cmd: bundle exec sidekiq
```

One image means one build, one push, one version across all roles. Use the `cmd` field to control what each role runs.

## Pattern: Health check per role

```yaml
servers:
  web:
    hosts: [192.168.0.1]
    proxy:
      healthcheck:
        path: /up
        interval: 1
  worker:
    hosts: [192.168.0.3]
    # Workers don't serve HTTP — no proxy health check
    # Kamal checks that the container process is running instead
```
