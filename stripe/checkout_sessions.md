---
name: stripe-checkout-sessions
triggers:
  - stripe checkout
  - checkout session
  - stripe payment
  - create checkout
  - stripe buy
  - payment link
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Checkout Sessions

Checkout Sessions are hosted payment pages. Stripe handles the UI, PCI compliance, and payment flow. You create a session and redirect the customer to it.

## Pattern: One-time payment checkout

```ruby
# app/controllers/checkouts_controller.rb
class CheckoutsController < ApplicationController
  def create
    session = Stripe::Checkout::Session.create(
      mode: "payment",
      customer_email: current_user.email,
      client_reference_id: current_user.id,
      line_items: [{
        price_data: {
          currency: "usd",
          product_data: { name: "Pro License" },
          unit_amount: 4900  # $49.00 in cents
        },
        quantity: 1
      }],
      success_url: checkout_success_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: pricing_url
    )

    redirect_to session.url, allow_other_host: true, status: :see_other
  end
end
```

## Pattern: Subscription checkout

```ruby
session = Stripe::Checkout::Session.create(
  mode: "subscription",
  customer: current_user.stripe_customer_id,
  line_items: [{
    price: "price_1234567890",  # Created in Stripe Dashboard or API
    quantity: 1
  }],
  success_url: checkout_success_url + "?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: pricing_url,
  subscription_data: {
    trial_period_days: 14,
    metadata: { user_id: current_user.id }
  }
)
```

## Pattern: Success page that verifies payment

```ruby
# app/controllers/checkouts_controller.rb
def success
  session = Stripe::Checkout::Session.retrieve(params[:session_id])

  if session.payment_status == "paid"
    # Activate the purchase — but prefer doing this in the webhook
    # This page is just for UI confirmation
    redirect_to dashboard_path, notice: "Payment successful!"
  else
    redirect_to pricing_url, alert: "Payment not completed"
  end
end
```

## Anti-pattern: Activating purchases on the success page

```ruby
# BAD — the success page is not guaranteed to load
# The user might close the tab before it loads
def success
  user.update!(plan: "pro")  # This might never run!
end

# GOOD — activate in the webhook, show confirmation on the success page
# The success page only displays a message
# The webhook (checkout.session.completed) does the actual activation
```

Always do the real work in the webhook. The success page is cosmetic.

## Pattern: Pre-creating a Stripe customer

```ruby
# When user signs up, create a Stripe customer for later use
class User < ApplicationRecord
  after_create :create_stripe_customer

  private

  def create_stripe_customer
    customer = Stripe::Customer.create(
      email: email,
      name: name,
      metadata: { user_id: id }
    )
    update_column(:stripe_customer_id, customer.id)
  end
end
```

Pre-creating the customer means checkout sessions can reference them, enabling subscription management, billing portal, and invoice history.
