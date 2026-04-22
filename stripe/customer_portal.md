---
name: stripe-customer-portal
triggers:
  - customer portal
  - billing portal
  - manage subscription
  - update payment method
  - stripe portal
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Customer Portal

The Billing Portal is a Stripe-hosted page where customers manage subscriptions, update payment methods, and view invoices.

## Pattern: Create a portal session

```ruby
class BillingController < ApplicationController
  def portal
    session = Stripe::BillingPortal::Session.create(
      customer: current_user.stripe_customer_id,
      return_url: dashboard_url
    )
    redirect_to session.url, allow_other_host: true, status: :see_other
  end
end
```

```erb
<%= button_to "Manage Billing", billing_portal_path, method: :post %>
```

## Pattern: Portal configuration

```ruby
Stripe::BillingPortal::Configuration.create(
  business_profile: { headline: "Manage your subscription" },
  features: {
    customer_update: { enabled: true, allowed_updates: ["email", "address"] },
    invoice_history: { enabled: true },
    payment_method_update: { enabled: true },
    subscription_cancel: {
      enabled: true,
      mode: "at_period_end",
      cancellation_reason: {
        enabled: true,
        options: ["too_expensive", "missing_features", "switched_service", "unused", "other"]
      }
    },
    subscription_update: {
      enabled: true,
      default_allowed_updates: ["price", "quantity"],
      products: [{
        product: "prod_basic",
        prices: ["price_basic_monthly", "price_basic_annual"]
      }]
    }
  }
)
```

## Pattern: Deep-link to specific portal sections

```ruby
session = Stripe::BillingPortal::Session.create(
  customer: current_user.stripe_customer_id,
  return_url: dashboard_url,
  flow_data: { type: "payment_method_update" }
)
```

Flow types: `payment_method_update`, `subscription_cancel`, `subscription_update`.

## Pattern: Handle portal events via webhooks

```ruby
when "customer.subscription.updated"
  Subscriptions::SyncService.call(stripe_subscription: event.data.object)
when "customer.subscription.deleted"
  user = User.find_by!(stripe_customer_id: event.data.object.customer)
  user.update!(subscription_status: "canceled")
```

## Anti-pattern: Building your own billing management UI

The portal handles PCI compliance, localization, mobile UX, and every edge case around payment method updates. Only build custom billing UI if you need something the portal genuinely can't do. One redirect replaces months of work.
