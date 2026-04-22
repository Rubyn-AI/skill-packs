---
name: sidekiq-retry-strategies
triggers:
  - sidekiq retry
  - retry count
  - dead set
  - sidekiq_options retry
  - exponential backoff
  - discard_on
  - retry_on
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Retry Strategies

## Default retry behavior

Sidekiq retries failed jobs 25 times over approximately 21 days with exponential backoff. After all retries are exhausted, the job moves to the Dead Set.

## Pattern: Custom retry count

```ruby
class SendNotificationJob < ApplicationJob
  sidekiq_options retry: 5  # Only retry 5 times instead of 25

  def perform(notification_id)
    notification = Notification.find(notification_id)
    NotificationService.deliver(notification)
  end
end
```

## Pattern: No retries

```ruby
class LogAnalyticsJob < ApplicationJob
  sidekiq_options retry: 0  # Never retry — analytics are fire-and-forget

  def perform(event_data)
    AnalyticsService.track(event_data)
  end
end
```

## Pattern: Rails retry_on and discard_on

```ruby
class ExternalApiJob < ApplicationJob
  # Retry up to 3 times with 5-second wait for API errors
  retry_on ExternalApi::RateLimitError, wait: 5.seconds, attempts: 3

  # Retry with exponential backoff
  retry_on ExternalApi::TimeoutError, wait: :polynomially_longer, attempts: 5

  # Don't retry — just discard
  discard_on ActiveRecord::RecordNotFound
  discard_on ExternalApi::PermanentError

  def perform(resource_id)
    resource = Resource.find(resource_id)
    ExternalApi.sync(resource)
  end
end
```

`wait: :polynomially_longer` uses the formula `(attempt ** 4) + 2` seconds. Attempt 1 = 3s, attempt 2 = 18s, attempt 3 = 83s, attempt 4 = 258s.

## Pattern: Custom death handler

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    # Notify when a job exhausts all retries
    ErrorTracker.notify(ex, context: {
      job_class: job["class"],
      job_args: job["args"],
      retry_count: job["retry_count"]
    })
  end
end
```

## Anti-pattern: Catching all exceptions to prevent retries

```ruby
# BAD — swallows all errors, job silently fails
def perform(user_id)
  begin
    risky_operation(user_id)
  rescue => e
    Rails.logger.error(e.message)
    # Error swallowed — Sidekiq thinks job succeeded
  end
end

# GOOD — let Sidekiq handle retries, rescue only specific non-retryable errors
def perform(user_id)
  risky_operation(user_id)
rescue ActiveRecord::RecordNotFound
  # Expected — user was deleted, don't retry
  Rails.logger.info("User #{user_id} not found, skipping")
rescue NetworkError
  # Let this bubble up so Sidekiq retries
  raise
end
```
