---
name: stripe-webhooks
triggers:
  - stripe webhook
  - stripe event
  - webhook endpoint
  - stripe signature
  - construct_event
  - webhook handler
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Webhook Handling

## Always verify webhook signatures

Never process a webhook without verifying the Stripe signature. Without verification, anyone can POST fake events to your endpoint.

```ruby
# app/controllers/webhooks/stripe_controller.rb
module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"]
        )
      rescue JSON::ParserError
        head :bad_request and return
      rescue Stripe::SignatureVerificationError
        head :bad_request and return
      end

      handle_event(event)
      head :ok
    end

    private

    def handle_event(event)
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "invoice.payment_succeeded"
        handle_payment_succeeded(event.data.object)
      when "invoice.payment_failed"
        handle_payment_failed(event.data.object)
      when "customer.subscription.updated"
        handle_subscription_updated(event.data.object)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event.data.object)
      else
        Rails.logger.info("Unhandled Stripe event: #{event.type}")
      end
    end

    def handle_checkout_completed(session)
      # Find your user/order by the client_reference_id or metadata
      user = User.find_by!(stripe_customer_id: session.customer)
      Subscriptions::ActivateService.call(user:, session:)
    end

    def handle_payment_failed(invoice)
      user = User.find_by(stripe_customer_id: invoice.customer)
      return unless user
      SubscriptionMailer.payment_failed(user).deliver_later
    end
  end
end
```

## Route configuration

```ruby
# config/routes.rb
namespace :webhooks do
  post "stripe", to: "stripe#create"
end
```

## Pattern: Idempotent webhook processing

Stripe may send the same event multiple times. Always make your handler idempotent.

```ruby
def handle_checkout_completed(session)
  # Idempotency: check if already processed
  return if Payment.exists?(stripe_session_id: session.id)

  Payment.create!(
    stripe_session_id: session.id,
    user: User.find_by!(stripe_customer_id: session.customer),
    amount: session.amount_total,
    status: "completed"
  )
end
```

## Pattern: Async webhook processing

For complex handlers, enqueue a job to avoid holding the webhook response open.

```ruby
def handle_event(event)
  StripeWebhookJob.perform_later(event.type, event.data.object.to_json)
  # Return 200 immediately — Stripe won't retry
end
```

## Anti-pattern: Fetching the object from Stripe instead of using the event data

```ruby
# BAD — unnecessary API call, adds latency
def handle_checkout_completed(session)
  full_session = Stripe::Checkout::Session.retrieve(session.id)
  # The event data already contains the session object
end

# GOOD — use the data from the event directly
def handle_checkout_completed(session)
  # session is already the full object from the event
  process(session)
end
```

Only fetch from Stripe if you need expanded fields not included in the webhook payload.

## Anti-pattern: Not returning 200 quickly

Stripe waits for your response. If you don't return 200 within ~20 seconds, Stripe marks the delivery as failed and retries. Do your heavy processing in a background job.

## Webhook events to handle (minimum for subscriptions)

| Event | Why |
|-------|-----|
| `checkout.session.completed` | Customer completed checkout |
| `invoice.payment_succeeded` | Recurring payment went through |
| `invoice.payment_failed` | Recurring payment failed |
| `customer.subscription.updated` | Plan change, trial end, status change |
| `customer.subscription.deleted` | Subscription canceled |
