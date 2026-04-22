---
name: stripe-idempotency
triggers:
  - idempotency key
  - stripe duplicate
  - double charge
  - retry safe
  - idempotent stripe
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Idempotency Keys

Idempotency keys prevent duplicate operations when retrying failed requests. Stripe guarantees that a request with the same idempotency key produces the same result.

## Pattern: Using idempotency keys

```ruby
Stripe::Charge.create(
  { amount: 2000, currency: "usd", customer: "cus_123" },
  { idempotency_key: "charge_order_#{order.id}" }
)
```

If you retry this request (network timeout, server crash), Stripe returns the original result instead of creating a duplicate charge.

## Pattern: Generating meaningful keys

```ruby
# GOOD — deterministic, tied to business logic
idempotency_key: "charge_order_#{order.id}"
idempotency_key: "subscribe_user_#{user.id}_plan_#{plan.id}"
idempotency_key: "refund_charge_#{charge.id}"

# BAD — random, can't retry the same operation
idempotency_key: SecureRandom.uuid  # Different on every retry!
```

Keys should be deterministic — the same business operation always generates the same key. Random UUIDs defeat the purpose.

## Pattern: Idempotency in webhook handlers

```ruby
def handle_checkout_completed(session)
  Payment.find_or_create_by!(stripe_session_id: session.id) do |payment|
    payment.user = User.find_by!(stripe_customer_id: session.customer)
    payment.amount = session.amount_total
    payment.status = "completed"
  end
end
```

`find_or_create_by!` with the Stripe ID as the unique key makes the handler idempotent — processing the same webhook twice doesn't create duplicate records.

## Idempotency key lifetime

Keys expire after 24 hours. After that, a new request with the same key creates a new operation.
