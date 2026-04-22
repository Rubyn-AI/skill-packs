---
name: stripe-pay-gem
triggers:
  - pay gem
  - pay stripe
  - pay customer
  - pay subscription
  - pay charge
  - billing rails
gems:
  - stripe
  - pay
rails: ">=7.0"
---

# Pay Gem Integration

Pay wraps Stripe (and Paddle/Braintree) behind a unified ActiveRecord interface. It manages customers, subscriptions, and charges as Rails models instead of raw API calls.

## Setup

```ruby
# Gemfile
gem "pay", "~> 7.0"

# Install
rails pay:install:migrations
rails db:migrate
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe
end
```

This adds `user.payment_processor`, `user.pay_customers`, and billing helper methods.

## Pattern: Checkout with Pay

```ruby
class CheckoutsController < ApplicationController
  def create
    checkout_session = current_user.payment_processor.checkout(
      mode: "subscription",
      line_items: [{ price: "price_1234", quantity: 1 }],
      success_url: dashboard_url,
      cancel_url: pricing_url
    )
    redirect_to checkout_session.url, allow_other_host: true, status: :see_other
  end
end
```

## Pattern: Checking subscription status

```ruby
class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe

  def subscribed?
    payment_processor&.subscribed?
  end

  def on_trial?
    payment_processor&.on_trial?
  end

  def subscription
    payment_processor&.subscription
  end
end
```

```ruby
# In controllers
before_action :require_subscription

def require_subscription
  unless current_user.subscribed?
    redirect_to pricing_path, alert: "Please subscribe to continue."
  end
end
```

## Pattern: Pay webhooks

Pay ships its own webhook controller. Mount it in routes:

```ruby
# config/routes.rb
mount Pay::Engine, at: "/pay"
```

Pay handles `checkout.session.completed`, `customer.subscription.updated`, `invoice.payment_succeeded`, and other events automatically, syncing to its ActiveRecord models.

## Pattern: One-time charges

```ruby
current_user.payment_processor.charge(4900, currency: "usd")
```

## Pattern: Billing portal via Pay

```ruby
def portal
  url = current_user.payment_processor.billing_portal(return_url: dashboard_url).url
  redirect_to url, allow_other_host: true, status: :see_other
end
```

## Anti-pattern: Mixing raw Stripe API calls with Pay

```ruby
# BAD — bypasses Pay's syncing, records get out of sync
Stripe::Subscription.cancel(user.stripe_subscription_id)

# GOOD — use Pay's methods so it updates its own records
current_user.payment_processor.subscription.cancel
```

If you use Pay, go all-in. Mixing raw Stripe calls with Pay means Pay's local records diverge from Stripe's state.

## When to use Pay vs raw Stripe

| Scenario | Use |
|---------|-----|
| Standard SaaS billing (subscriptions, charges, portal) | Pay — handles 90% of cases with less code |
| Complex Stripe Connect marketplace | Raw Stripe — Pay doesn't cover Connect well |
| Metered billing with custom usage reporting | Raw Stripe — more control over usage records |
| Multi-processor (Stripe + Paddle fallback) | Pay — its abstraction layer shines here |
