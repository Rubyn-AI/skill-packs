---
name: kamal-secrets
triggers:
  - kamal secrets
  - kamal env
  - secret management
  - environment variables kamal
  - .kamal/secrets
gems:
  - kamal
rails: ">=7.0"
---

# Kamal Secrets Management

## Pattern: Setting secrets

```bash
# Set individual secrets
kamal secrets set RAILS_MASTER_KEY=$(cat config/master.key)
kamal secrets set DATABASE_URL="postgres://user:pass@db.host:5432/myapp"

# Set from a file
kamal secrets set < .env.production
```

Secrets are stored encrypted in `.kamal/secrets` and injected as environment variables into your containers.

## Pattern: Referencing secrets in deploy.yml

```yaml
env:
  clear:
    RAILS_ENV: production
    RAILS_LOG_TO_STDOUT: true
    RAILS_SERVE_STATIC_FILES: true
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL
    - STRIPE_SECRET_KEY
    - STRIPE_WEBHOOK_SECRET
```

`clear:` values are visible in the config file. `secret:` values are pulled from `.kamal/secrets` at deploy time and never written to disk on the server.

## Anti-pattern: Secrets in the repository

```yaml
# BAD — never put secrets in deploy.yml
env:
  clear:
    DATABASE_URL: postgres://user:password@host/db  # Committed to git!

# GOOD — reference as a secret
env:
  secret:
    - DATABASE_URL
```

## Pattern: Per-destination secrets

```yaml
# config/deploy.yml
destinations:
  staging:
    servers:
      web:
        hosts: [staging.myapp.com]
    env:
      secret:
        - STAGING_DATABASE_URL

  production:
    servers:
      web:
        hosts: [prod1.myapp.com, prod2.myapp.com]
    env:
      secret:
        - PRODUCTION_DATABASE_URL
```

```bash
kamal deploy -d staging
kamal deploy -d production
```

## Pattern: Rotating secrets

```bash
# Update a secret
kamal secrets set RAILS_MASTER_KEY=new_key_value

# Redeploy to pick up the new value
kamal deploy
```

Secrets are injected at container start time. You must redeploy after changing a secret.
