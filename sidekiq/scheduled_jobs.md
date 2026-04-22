---
name: sidekiq-scheduled-jobs
triggers:
  - scheduled job
  - recurring job
  - cron sidekiq
  - perform_at
  - set wait
  - sidekiq-cron
  - sidekiq-scheduler
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Scheduled & Recurring Jobs

## One-time scheduled jobs

```ruby
# Run in 5 minutes
SendReminderJob.set(wait: 5.minutes).perform_later(user.id)

# Run at a specific time
SendReminderJob.set(wait_until: Date.tomorrow.noon).perform_later(user.id)
```

## Pattern: Recurring jobs with sidekiq-cron

```ruby
# Gemfile
gem "sidekiq-cron"

# config/initializers/sidekiq_cron.rb
Sidekiq::Cron::Job.load_from_hash(
  "daily_digest" => {
    "cron" => "0 8 * * *",  # 8 AM daily
    "class" => "DailyDigestJob",
    "queue" => "low"
  },
  "cleanup_expired_sessions" => {
    "cron" => "0 3 * * *",  # 3 AM daily
    "class" => "CleanupExpiredSessionsJob"
  },
  "sync_stripe_subscriptions" => {
    "cron" => "*/15 * * * *",  # Every 15 minutes
    "class" => "SyncStripeSubscriptionsJob",
    "queue" => "default"
  }
)
```

## Pattern: Recurring with Solid Queue (Rails 8+)

```yaml
# config/recurring.yml
production:
  daily_digest:
    class: DailyDigestJob
    schedule: every day at 8am
  cleanup:
    class: CleanupJob
    schedule: every day at 3am
  sync:
    class: SyncJob
    schedule: every 15 minutes
```

## Anti-pattern: Using sleep in jobs for scheduling

```ruby
# BAD — ties up a Sidekiq thread
def perform
  loop do
    check_for_updates
    sleep 60  # Blocks a worker thread for 60 seconds
  end
end

# GOOD — use scheduled jobs
def perform
  check_for_updates
  # Re-enqueue for next run
  self.class.set(wait: 1.minute).perform_later
end

# BEST — use sidekiq-cron for fixed intervals
```

## Pattern: Unique scheduled jobs (prevent duplicates)

```ruby
# With sidekiq-unique-jobs gem
class DailyReportJob < ApplicationJob
  sidekiq_options lock: :until_executed,
                  on_conflict: :log

  def perform
    Report.generate_daily
  end
end
```

Or manually check for existing scheduled jobs:

```ruby
class ScheduledReminderJob < ApplicationJob
  def self.schedule_for(user)
    # Don't schedule if one is already pending
    return if already_scheduled?(user.id)
    set(wait: 24.hours).perform_later(user.id)
  end

  def self.already_scheduled?(user_id)
    scheduled = Sidekiq::ScheduledSet.new
    scheduled.any? { |job| job.klass == name && job.args == [user_id] }
  end
end
```
