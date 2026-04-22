---
name: stripe-subscriptions
triggers:
  - stripe subscription
  - recurring billing
  - subscription status
  - cancel subscription
  - upgrade plan
  - downgrade plan
  - trial period
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Subscription Management

## Subscription lifecycle states

| Status | Meaning |
|--------|---------|
| `trialing` | In trial period, no charges yet |
| `active` | Paying and current |
| `past_due` | Payment failed, retrying |
| `canceled` | Canceled (may still be active until period end) |
| `unpaid` | All retry attempts failed |
| `incomplete` | Initial payment requires action (3D Secure) |
| `incomplete_expired` | Initial payment window expired |

## Pattern: Sync subscription status from webhooks

```ruby
# app/services/subscriptions/sync_service.rb
module Subscriptions
  class SyncService
    def self.call(stripe_subscription:)
      user = User.find_by!(stripe_customer_id: stripe_subscription.customer)

      user.update!(
        subscription_status: stripe_subscription.status,
        subscription_plan: stripe_subscription.items.data.first.price.id,
        current_period_end: Time.at(stripe_subscription.current_period_end),
        cancel_at_period_end: stripe_subscription.cancel_at_period_end
      )
    end
  end
end
```

## Pattern: Cancel at period end (graceful cancellation)

```ruby
def cancel
  Stripe::Subscription.update(
    current_user.stripe_subscription_id,
    cancel_at_period_end: true
  )
  # User retains access until current_period_end
end
```

## Pattern: Immediate cancellation

```ruby
def cancel_immediately
  Stripe::Subscription.cancel(current_user.stripe_subscription_id)
  current_user.update!(subscription_status: "canceled")
end
```

## Pattern: Plan upgrade/downgrade

```ruby
def change_plan(new_price_id)
  subscription = Stripe::Subscription.retrieve(current_user.stripe_subscription_id)

  Stripe::Subscription.update(
    subscription.id,
    items: [{
      id: subscription.items.data.first.id,
      price: new_price_id
    }],
    proration_behavior: "create_prorations"  # or "none" or "always_invoice"
  )
end
```

`create_prorations` charges or credits the difference for the current billing period.

## Pattern: Check subscription access in the app

```ruby
# app/models/user.rb
class User < ApplicationRecord
  def subscribed?
    subscription_status.in?(%w[active trialing])
  end

  def subscription_active_or_grace_period?
    subscribed? || (subscription_status == "canceled" && current_period_end&.future?)
  end
end

# In controllers
before_action :require_subscription

def require_subscription
  unless current_user.subscription_active_or_grace_period?
    redirect_to pricing_path, alert: "Please subscribe to access this feature"
  end
end
```

## Anti-pattern: Checking subscription status via API call on every request

```ruby
# BAD — API call on every page load
def subscribed?
  sub = Stripe::Subscription.retrieve(stripe_subscription_id)
  sub.status == "active"
end

# GOOD — sync status from webhooks, check local database
def subscribed?
  subscription_status == "active"
end
```

Webhook sync keeps your database current. Checking the API on every request adds latency and counts against your rate limit.
