---
name: stripe-sca
triggers:
  - 3d secure
  - sca
  - strong customer authentication
  - payment intent
  - requires_action
  - authentication required
  - psd2
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Strong Customer Authentication (SCA / 3D Secure)

SCA is a European regulation (PSD2) requiring two-factor authentication for online payments. Stripe handles most of this automatically, but your code must handle the `requires_action` state.

## How it works

1. Customer enters card details
2. Stripe determines if SCA is needed (based on bank, region, amount)
3. If needed, the customer sees a 3D Secure challenge (bank popup/redirect)
4. Customer completes the challenge
5. Payment goes through

## Pattern: Handling SCA with Checkout Sessions

Checkout Sessions handle SCA automatically. The customer completes the challenge on Stripe's hosted page — no code changes needed.

```ruby
session = Stripe::Checkout::Session.create(
  mode: "payment",
  line_items: [{ price: "price_123", quantity: 1 }],
  success_url: success_url,
  cancel_url: cancel_url
)
# SCA is handled entirely by Stripe's hosted page
```

This is the recommended approach. Stripe handles the full authentication flow.

## Pattern: Handling SCA with PaymentIntents (custom forms)

If you use Stripe Elements (custom payment forms), you must handle the `requires_action` status:

```ruby
# Server: create the PaymentIntent
intent = Stripe::PaymentIntent.create(
  amount: 2000,
  currency: "usd",
  customer: current_user.stripe_customer_id,
  payment_method: params[:payment_method_id],
  confirm: true,
  return_url: payment_complete_url  # For redirect-based auth
)

case intent.status
when "succeeded"
  render json: { success: true }
when "requires_action"
  render json: {
    requires_action: true,
    client_secret: intent.client_secret
  }
else
  render json: { error: "Payment failed" }, status: :unprocessable_entity
end
```

```javascript
// Client: handle the 3D Secure challenge
const { error, paymentIntent } = await stripe.handleNextAction({
  clientSecret: data.client_secret,
});

if (error) {
  showError(error.message);
} else if (paymentIntent.status === "succeeded") {
  showSuccess();
}
```

## Pattern: SCA for off-session payments (subscriptions, saved cards)

For recurring charges where the customer isn't present, set up the PaymentIntent for off-session use:

```ruby
intent = Stripe::PaymentIntent.create(
  amount: 2000,
  currency: "usd",
  customer: customer_id,
  payment_method: payment_method_id,
  off_session: true,
  confirm: true
)
```

If the bank requires authentication, the payment fails with `requires_action`. You must email the customer a link to complete authentication:

```ruby
rescue Stripe::CardError => e
  if e.code == "authentication_required"
    # Send the customer an email with a link to authenticate
    PaymentAuthMailer.required(
      user: user,
      payment_intent_id: e.error.payment_intent.id
    ).deliver_later
  end
end
```

## Anti-pattern: Ignoring requires_action status

```ruby
# BAD — treats requires_action as a failure
if intent.status == "succeeded"
  activate_purchase
else
  show_error("Payment failed")  # Customer can't complete 3D Secure!
end

# GOOD — handle the requires_action flow
case intent.status
when "succeeded"
  activate_purchase
when "requires_action"
  prompt_customer_to_authenticate(intent.client_secret)
end
```

## Test card numbers for SCA

| Card | Behavior |
|------|---------|
| `4000002500003155` | Requires authentication (3D Secure) |
| `4000002760003184` | Requires authentication, completes successfully |
| `4000008260003178` | Requires authentication, fails authentication |
| `4242424242424242` | No authentication required (non-EU) |
