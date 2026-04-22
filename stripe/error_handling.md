---
name: stripe-error-handling
triggers:
  - stripe error
  - stripe exception
  - StripeError
  - CardError
  - rate limit stripe
  - stripe retry
gems:
  - stripe
rails: ">=7.0"
---

# Stripe Error Handling

## Error hierarchy

```ruby
Stripe::StripeError
├── Stripe::CardError              # Card declined, insufficient funds
├── Stripe::RateLimitError         # Too many requests
├── Stripe::InvalidRequestError    # Invalid parameters
├── Stripe::AuthenticationError    # Bad API key
├── Stripe::APIConnectionError     # Network failure
└── Stripe::APIError               # Stripe server error (500)
```

## Pattern: Comprehensive error handling

```ruby
class PaymentsController < ApplicationController
  def create
    charge = Stripe::Charge.create(
      amount: @amount,
      currency: "usd",
      customer: current_user.stripe_customer_id
    )
    redirect_to receipt_path(charge.id)
  rescue Stripe::CardError => e
    # Card was declined — show user the decline reason
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue Stripe::RateLimitError
    # Too many requests — retry after a delay
    RetryPaymentJob.set(wait: 5.seconds).perform_later(current_user.id, @amount)
    redirect_to payments_path, notice: "Processing your payment..."
  rescue Stripe::InvalidRequestError => e
    # Bug in our code — log and show generic error
    Rails.logger.error("Stripe InvalidRequestError: #{e.message}")
    Sentry.capture_exception(e)
    flash.now[:alert] = "Something went wrong. Please try again."
    render :new, status: :unprocessable_entity
  rescue Stripe::AuthenticationError
    # API key is wrong — critical, alert the team
    Rails.logger.fatal("Stripe authentication failed — check API keys")
    Sentry.capture_message("Stripe API key invalid", level: :fatal)
    flash.now[:alert] = "Payment system unavailable. Please try later."
    render :new, status: :service_unavailable
  rescue Stripe::APIConnectionError
    # Network issue — safe to retry
    flash.now[:alert] = "Could not connect to payment processor. Please try again."
    render :new, status: :service_unavailable
  rescue Stripe::APIError
    # Stripe server error — safe to retry
    flash.now[:alert] = "Payment processor is temporarily unavailable."
    render :new, status: :service_unavailable
  end
end
```

## Pattern: Retries with exponential backoff

```ruby
class StripeRetryService
  MAX_RETRIES = 3

  def self.call(&block)
    retries = 0
    begin
      yield
    rescue Stripe::RateLimitError, Stripe::APIConnectionError, Stripe::APIError => e
      retries += 1
      raise if retries > MAX_RETRIES
      sleep(2 ** retries)  # 2, 4, 8 seconds
      retry
    end
  end
end

# Usage
StripeRetryService.call do
  Stripe::Customer.create(email: user.email)
end
```

## Anti-pattern: Catching all Stripe errors the same way

```ruby
# BAD — treats card declines the same as server errors
rescue Stripe::StripeError => e
  flash[:alert] = "Payment failed"
end

# GOOD — handle each type appropriately
# CardError → show user the decline reason
# RateLimitError → retry
# InvalidRequestError → log bug
# AuthenticationError → alert team
# APIConnectionError/APIError → retry later
```
