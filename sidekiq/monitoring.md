---
name: sidekiq-monitoring
triggers:
  - sidekiq web
  - sidekiq dashboard
  - sidekiq monitoring
  - sidekiq metrics
  - dead set
  - sidekiq mount
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Monitoring

## Mounting the Web UI

```ruby
# config/routes.rb
require "sidekiq/web"

Rails.application.routes.draw do
  # Protected with Devise
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Or with HTTP basic auth
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(username, ENV["SIDEKIQ_USERNAME"]) &
    ActiveSupport::SecurityUtils.secure_compare(password, ENV["SIDEKIQ_PASSWORD"])
  end
  mount Sidekiq::Web => "/sidekiq"
end
```

## Anti-pattern: Unprotected Sidekiq Web

```ruby
# BAD — anyone can access job data, retry/delete jobs
mount Sidekiq::Web => "/sidekiq"

# GOOD — always authenticate
authenticate :user, ->(u) { u.admin? } do
  mount Sidekiq::Web => "/sidekiq"
end
```

The Sidekiq Web UI exposes job arguments (which may contain user IDs, emails, etc.) and allows retrying/deleting jobs. Always protect it.

## Pattern: Health check endpoint

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def sidekiq
    stats = Sidekiq::Stats.new
    latency = Sidekiq::Queue.new.latency

    if latency > 300  # Queue latency > 5 minutes
      render json: { status: "degraded", latency: latency }, status: :service_unavailable
    else
      render json: {
        status: "ok",
        processed: stats.processed,
        failed: stats.failed,
        enqueued: stats.enqueued,
        latency: latency
      }
    end
  end
end
```

## Pattern: Alerting on dead jobs

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    # Send to error tracking
    Sentry.capture_exception(ex, extra: {
      sidekiq_job: job["class"],
      args: job["args"],
      queue: job["queue"],
      retries_exhausted: true
    })

    # Or Slack notification
    SlackNotifier.alert("Dead job: #{job['class']} — #{ex.message}")
  end
end
```

## Key metrics to monitor

| Metric | Warning threshold | What it means |
|--------|-----------------|--------------|
| Queue latency | > 60 seconds | Jobs waiting too long to start |
| Dead set size | > 0 (growing) | Jobs failing permanently |
| Retry set size | > 100 | Many jobs failing and retrying |
| Memory per worker | > 512 MB | Memory leak in job code |
| Processed rate | Declining | Workers may be stuck or crashed |
