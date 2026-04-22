---
name: kamal-monitoring
triggers:
  - kamal logs
  - kamal monitoring
  - kamal health
  - container logs
  - kamal status
  - kamal audit
gems:
  - kamal
rails: ">=7.0"
---

# Kamal Monitoring

## Pattern: Viewing logs

```bash
# Tail application logs (all servers)
kamal app logs

# Tail logs from a specific role
kamal app logs --roles web

# Tail logs from a specific host
kamal app logs --hosts 192.168.0.1

# Follow logs in real-time
kamal app logs -f

# Last 100 lines
kamal app logs -n 100

# Proxy logs (kamal-proxy / Traefik)
kamal proxy logs
```

## Pattern: Structured logging for production

```ruby
# config/environments/production.rb
config.log_formatter = ::Logger::Formatter.new
config.logger = ActiveSupport::TaggedLogging.logger($stdout)

# Or use lograge for structured JSON logs
# Gemfile: gem "lograge"
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_payload do |controller|
  {
    user_id: controller.current_user&.id,
    request_id: controller.request.request_id
  }
end
```

JSON logs are parseable by log aggregators (Datadog, Papertrail, Logflare, CloudWatch).

## Pattern: Container health monitoring

```bash
# Check if all containers are healthy
kamal app details

# Output shows:
# Host: 192.168.0.1 — running (healthy) — image: myorg/myapp:abc123
# Host: 192.168.0.2 — running (healthy) — image: myorg/myapp:abc123
```

## Pattern: Uptime monitoring with the /up endpoint

```ruby
# config/routes.rb (Rails 7.1+ generates this automatically)
get "up" => "rails/health#show", as: :rails_health_check
```

Point an external monitor (UptimeRobot, Betterstack, Pingdom) at `https://myapp.com/up`. It returns `200` when the app is running and the database is connected.

## Pattern: Exception tracking

```ruby
# Gemfile
gem "sentry-ruby"
gem "sentry-rails"

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.profiles_sample_rate = 0.1
  config.environment = Rails.env
end
```

```yaml
# config/deploy.yml
env:
  secret:
    - SENTRY_DSN
```

## Pattern: Deploy notifications

```bash
# After deploy, notify your team/error tracker
kamal deploy && curl -X POST \
  -d "{\"text\": \"Deployed myapp $(kamal app version)\"}" \
  $SLACK_WEBHOOK_URL
```

Or use Kamal hooks:

```yaml
# config/deploy.yml
hooks:
  post-deploy:
    - curl -X POST -d '{"text":"Deployed!"}' $SLACK_WEBHOOK_URL
```

## Pattern: Rollback on failure

```bash
# Rollback to the previous version
kamal rollback

# Rollback to a specific version
kamal rollback abc123def
```

Monitor error rates after deploy. If they spike, rollback immediately and investigate.

## Key commands for troubleshooting

| Command | When to use |
|---------|------------|
| `kamal app logs -f` | Something is broken, check the logs |
| `kamal app details` | Check if containers are running and healthy |
| `kamal app exec 'rails console'` | Debug in production console |
| `kamal app exec 'rails db:migrate:status'` | Check migration state |
| `kamal proxy logs` | SSL or routing issues |
| `kamal proxy details` | Check proxy configuration |
| `kamal rollback` | Deploy went wrong, revert |
| `kamal lock status` | Check if a deploy is in progress |

## Anti-pattern: No monitoring at all

```yaml
# BAD — deploy and hope for the best

# GOOD — minimum viable monitoring
# 1. Uptime monitor on /up (UptimeRobot — free)
# 2. Exception tracking (Sentry — free tier)
# 3. Log aggregation (Papertrail or Logtail — free tier)
# 4. Deploy notifications to Slack/Discord
```

You can set up basic monitoring for a Rails app in 30 minutes with free tiers. There's no excuse for flying blind.
