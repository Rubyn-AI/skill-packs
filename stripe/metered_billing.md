---
name: stripe-metered-billing
triggers:
  - metered billing
  - usage based
  - usage record
  - meter event
  - per unit pricing
  - consumption billing
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Metered Billing

Metered billing charges customers based on actual usage reported during the billing period. Common for API calls, compute hours, storage, or messages.

## Pattern: Create a metered price

```ruby
# Create via API (or Stripe Dashboard)
price = Stripe::Price.create(
  currency: "usd",
  product: "prod_api_access",
  recurring: {
    interval: "month",
    usage_type: "metered"
  },
  billing_scheme: "per_unit",
  unit_amount: 1  # $0.01 per unit (API call)
)
```

## Pattern: Subscribe a customer to a metered plan

```ruby
subscription = Stripe::Subscription.create(
  customer: current_user.stripe_customer_id,
  items: [{ price: "price_metered_123" }]
)

# Save the subscription item ID — you need it to report usage
current_user.update!(
  stripe_subscription_id: subscription.id,
  stripe_subscription_item_id: subscription.items.data.first.id
)
```

## Pattern: Report usage with the Billing Meter API (Stripe v2)

```ruby
# Modern approach: Stripe Billing Meters (2024+)
Stripe::Billing::MeterEvent.create(
  event_name: "api_calls",
  payload: {
    stripe_customer_id: current_user.stripe_customer_id,
    value: "1"
  }
)
```

## Pattern: Report usage with Subscription Item usage records (classic)

```ruby
# Classic approach: usage records on subscription items
Stripe::SubscriptionItem.create_usage_record(
  current_user.stripe_subscription_item_id,
  quantity: 1,
  timestamp: Time.current.to_i,
  action: "increment"  # or "set" to replace
)
```

## Pattern: Batch usage reporting with a background job

Don't report usage on every API call — batch it.

```ruby
# app/jobs/report_usage_job.rb
class ReportUsageJob < ApplicationJob
  queue_as :low

  def perform
    User.where.not(stripe_subscription_item_id: nil).find_each do |user|
      count = user.api_calls_since_last_report
      next if count.zero?

      Stripe::SubscriptionItem.create_usage_record(
        user.stripe_subscription_item_id,
        quantity: count,
        timestamp: Time.current.to_i,
        action: "increment"
      )

      user.update!(last_usage_reported_at: Time.current)
    end
  end
end
```

```ruby
# Schedule hourly via sidekiq-cron
{ "report_usage" => { "cron" => "0 * * * *", "class" => "ReportUsageJob" } }
```

## Pattern: Usage tracking in your app

```ruby
# app/models/user.rb
class User < ApplicationRecord
  def track_api_call!
    increment!(:api_calls_current_period)
    # Or use Redis for high-throughput counting
    Rails.cache.increment("usage:#{id}:#{Date.current}")
  end

  def api_calls_since_last_report
    if last_usage_reported_at
      api_calls.where("created_at > ?", last_usage_reported_at).count
    else
      api_calls.where(created_at: current_period_start..).count
    end
  end
end
```

## Pattern: Tiered pricing

```ruby
price = Stripe::Price.create(
  currency: "usd",
  product: "prod_api_access",
  recurring: { interval: "month", usage_type: "metered" },
  billing_scheme: "tiered",
  tiers_mode: "graduated",  # or "volume"
  tiers: [
    { up_to: 1000, unit_amount: 0 },        # First 1000 free
    { up_to: 10000, unit_amount: 1 },        # $0.01 each
    { up_to: "inf", unit_amount: 0.5 }       # $0.005 each after 10k
  ]
)
```

`graduated`: each tier applies to units in that range. `volume`: the entire quantity uses the tier the total falls into.

## Anti-pattern: Reporting usage synchronously on every request

```ruby
# BAD — adds Stripe API latency to every request
class ApiController < ApplicationController
  after_action :report_usage

  def report_usage
    Stripe::SubscriptionItem.create_usage_record(...)  # Slow!
  end
end

# GOOD — track locally, report in batch
class ApiController < ApplicationController
  after_action :track_usage

  def track_usage
    current_user.track_api_call!  # Fast local increment
  end
end
# ReportUsageJob runs hourly and reports to Stripe in bulk
```

Stripe's API has rate limits and adds latency. Track usage locally (database counter or Redis) and report to Stripe in periodic batches.

## Anti-pattern: Not handling usage record failures

```ruby
# BAD — swallows errors, usage goes unreported
begin
  Stripe::SubscriptionItem.create_usage_record(...)
rescue Stripe::StripeError
  # Lost usage data!
end

# GOOD — retry with the job system
rescue Stripe::StripeError => e
  Rails.logger.error("Usage report failed: #{e.message}")
  ReportUsageForUserJob.set(wait: 5.minutes).perform_later(user.id)
end
```
