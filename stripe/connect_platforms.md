---
name: stripe-connect
triggers:
  - stripe connect
  - marketplace
  - platform payments
  - connected account
  - onboarding
  - transfer
  - application fee
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Connect Platforms

Stripe Connect powers marketplaces and platforms where your app facilitates payments between buyers and sellers/service providers.

## Account types

| Type | Managed by | Best for |
|------|-----------|---------|
| Standard | Seller manages their own Stripe dashboard | Marketplaces where sellers are businesses |
| Express | Stripe-hosted onboarding, limited dashboard | Gig platforms, creator platforms |
| Custom | Your platform manages everything | Full white-label experience |

Express is the sweet spot for most Rails apps — Stripe handles identity verification, tax forms, and payouts.

## Pattern: Creating a connected account

```ruby
class OnboardingController < ApplicationController
  def create
    account = Stripe::Account.create(
      type: "express",
      email: current_user.email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true }
      },
      metadata: { user_id: current_user.id }
    )

    current_user.update!(stripe_account_id: account.id)

    # Generate onboarding link
    link = Stripe::AccountLink.create(
      account: account.id,
      refresh_url: onboarding_refresh_url,
      return_url: onboarding_complete_url,
      type: "account_onboarding"
    )

    redirect_to link.url, allow_other_host: true, status: :see_other
  end
end
```

## Pattern: Creating a charge with application fee

```ruby
# Direct charge — charge appears on connected account's statement
session = Stripe::Checkout::Session.create(
  {
    mode: "payment",
    line_items: [{ price_data: { currency: "usd", unit_amount: 10000, product_data: { name: "Consulting" } }, quantity: 1 }],
    payment_intent_data: {
      application_fee_amount: 1500  # Platform takes $15
    },
    success_url: success_url,
    cancel_url: cancel_url
  },
  { stripe_account: seller.stripe_account_id }  # On behalf of seller
)
```

## Pattern: Destination charges

```ruby
# Destination charge — charge appears on YOUR platform's statement
intent = Stripe::PaymentIntent.create(
  amount: 10000,
  currency: "usd",
  transfer_data: {
    destination: seller.stripe_account_id,
    amount: 8500  # Seller receives $85, platform keeps $15
  }
)
```

## Pattern: Manual transfers (separate charge and transfer)

```ruby
# Step 1: Charge the buyer
charge = Stripe::Charge.create(amount: 10000, currency: "usd", source: token)

# Step 2: Transfer to seller (can happen later, different amount)
Stripe::Transfer.create(
  amount: 8500,
  currency: "usd",
  destination: seller.stripe_account_id,
  transfer_group: "order_#{order.id}"
)
```

Use separate charge and transfer when you need to split payments across multiple sellers or delay payouts.

## Pattern: Check onboarding status

```ruby
def onboarding_complete
  account = Stripe::Account.retrieve(current_user.stripe_account_id)

  if account.charges_enabled && account.payouts_enabled
    current_user.update!(stripe_onboarding_complete: true)
    redirect_to dashboard_path, notice: "You're all set to receive payments!"
  else
    redirect_to onboarding_path, alert: "Please complete your account setup."
  end
end
```

## Pattern: Webhook handling for Connect

Connect webhooks have an `account` field identifying which connected account triggered the event:

```ruby
# Listen on your platform's webhook endpoint
when "account.updated"
  account = event.data.object
  user = User.find_by(stripe_account_id: account.id)
  user&.update!(
    stripe_charges_enabled: account.charges_enabled,
    stripe_payouts_enabled: account.payouts_enabled
  )
```

## Anti-pattern: Storing sensitive seller data yourself

```ruby
# BAD — you're now responsible for PCI/KYC compliance
seller.update!(bank_account: params[:bank_account], ssn: params[:ssn])

# GOOD — let Stripe handle it via onboarding
link = Stripe::AccountLink.create(
  account: seller.stripe_account_id,
  type: "account_onboarding",
  ...
)
```

Stripe's onboarding handles identity verification, tax form collection (1099s), and bank account validation. Don't collect this data yourself.
