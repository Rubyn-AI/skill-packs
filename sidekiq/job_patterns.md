---
name: sidekiq-job-patterns
triggers:
  - sidekiq job
  - perform_async
  - worker
  - background job
  - sidekiq perform
  - ApplicationJob sidekiq
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Job Patterns

## Pattern: Basic job structure

```ruby
# app/jobs/send_welcome_email_job.rb
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
  end
end

# Enqueue
SendWelcomeEmailJob.perform_later(user.id)

# Schedule for later
SendWelcomeEmailJob.set(wait: 5.minutes).perform_later(user.id)
```

## Critical rule: Pass IDs, not objects

```ruby
# BAD — serializes the entire ActiveRecord object into Redis
SendWelcomeEmailJob.perform_later(user)  # Fragile, large payload

# GOOD — pass the ID, look it up in the job
SendWelcomeEmailJob.perform_later(user.id)
```

Why: The object may change between enqueue and execution. Redis stores the serialized argument; large objects waste memory. GlobalID resolves this for ActiveRecord objects, but explicit IDs are more predictable and debuggable.

## Pattern: Idempotent jobs

Jobs may execute more than once (crashes, retries, network issues). Design for it.

```ruby
class ChargeSubscriptionJob < ApplicationJob
  def perform(subscription_id)
    subscription = Subscription.find(subscription_id)

    # Guard: don't charge twice for the same period
    return if subscription.charged_for_current_period?

    # Wrap in a transaction with a unique constraint
    subscription.transaction do
      charge = subscription.charges.create!(
        amount: subscription.plan.price,
        period: subscription.current_period
      )
      PaymentGateway.charge(charge)
      subscription.update!(last_charged_at: Time.current)
    end
  end
end
```

Idempotency strategies: database unique constraints, checking state before acting, using idempotency keys with external APIs.

## Pattern: Job with error context

```ruby
class ProcessOrderJob < ApplicationJob
  def perform(order_id)
    order = Order.find(order_id)
    OrderProcessor.new(order).process!
  rescue ActiveRecord::RecordNotFound
    # Order was deleted between enqueue and execution — don't retry
    Rails.logger.warn("Order #{order_id} not found, skipping")
  rescue PaymentGateway::Error => e
    # Let Sidekiq retry this one
    raise
  rescue => e
    # Unexpected error — log context, then re-raise for retry
    Rails.logger.error("ProcessOrderJob failed for order #{order_id}: #{e.message}")
    raise
  end
end
```

## Anti-pattern: Long-running jobs without checkpointing

```ruby
# BAD — if this job fails at record 5000, all work is lost
class ImportUsersJob < ApplicationJob
  def perform(csv_path)
    CSV.foreach(csv_path) do |row|
      User.create!(name: row[0], email: row[1])
    end
  end
end

# GOOD — process in batches, enqueue follow-up jobs
class ImportUsersJob < ApplicationJob
  BATCH_SIZE = 100

  def perform(csv_path, offset = 0)
    rows = CSV.read(csv_path)
    batch = rows[offset, BATCH_SIZE]
    return if batch.nil? || batch.empty?

    batch.each { |row| User.create!(name: row[0], email: row[1]) }

    # Enqueue the next batch
    if offset + BATCH_SIZE < rows.size
      ImportUsersJob.perform_later(csv_path, offset + BATCH_SIZE)
    end
  end
end
```

## Anti-pattern: Enqueuing inside a transaction

```ruby
# BAD — job may execute before the transaction commits
ActiveRecord::Base.transaction do
  order = Order.create!(params)
  ProcessOrderJob.perform_later(order.id)  # Job fires NOW, order may not exist yet
end

# GOOD — enqueue after commit
order = Order.create!(params)
ProcessOrderJob.perform_later(order.id)

# ALSO GOOD — use after_commit callback
class Order < ApplicationRecord
  after_create_commit :enqueue_processing
  
  private
  def enqueue_processing
    ProcessOrderJob.perform_later(id)
  end
end
```
