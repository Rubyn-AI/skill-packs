---
name: stripe-testing
triggers:
  - stripe test
  - stripe mock
  - stripe fixture
  - test webhook
  - stripe test mode
  - stripe-mock
gems:
  - stripe
rails: ">=7.0"
---

# Testing Stripe Integrations

## Pattern: Use Stripe test mode keys

```ruby
# .env.test
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_test_...
```

Test mode keys create real API calls to Stripe's test environment. Use `stripe-mock` for fully offline tests.

## Pattern: Testing webhooks with signed payloads

```ruby
# spec/requests/webhooks/stripe_spec.rb
RSpec.describe "Stripe Webhooks", type: :request do
  let(:webhook_secret) { "whsec_test_secret" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("STRIPE_WEBHOOK_SECRET").and_return(webhook_secret)
  end

  def stripe_event(type:, object:)
    payload = { type: type, data: { object: object } }.to_json
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, webhook_secret)
    sig_header = "t=#{timestamp},v1=#{signature}"

    post webhooks_stripe_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "HTTP_STRIPE_SIGNATURE" => sig_header
      }
  end

  describe "checkout.session.completed" do
    it "activates the subscription" do
      user = create(:user, stripe_customer_id: "cus_123")

      stripe_event(
        type: "checkout.session.completed",
        object: { id: "cs_123", customer: "cus_123", payment_status: "paid" }
      )

      expect(response).to have_http_status(:ok)
      expect(user.reload.subscription_status).to eq("active")
    end
  end

  describe "invalid signature" do
    it "returns 400" do
      post webhooks_stripe_path,
        params: { type: "test" }.to_json,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "HTTP_STRIPE_SIGNATURE" => "invalid"
        }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
```

## Pattern: VCR cassettes for Stripe API calls

```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<STRIPE_KEY>") { ENV["STRIPE_SECRET_KEY"] }
  config.filter_sensitive_data("<STRIPE_WEBHOOK_SECRET>") { ENV["STRIPE_WEBHOOK_SECRET"] }
end

# Usage
RSpec.describe Subscriptions::CreateService do
  it "creates a checkout session", vcr: { cassette_name: "stripe/create_checkout" } do
    session = described_class.call(user: user, price_id: "price_123")
    expect(session.url).to start_with("https://checkout.stripe.com")
  end
end
```

## Test card numbers

| Number | Scenario |
|--------|---------|
| `4242424242424242` | Success |
| `4000000000000002` | Declined |
| `4000002500003155` | Requires 3D Secure |
| `4000000000009995` | Insufficient funds |
| `4000000000000341` | Attach succeeds, charge fails |

## Anti-pattern: Hitting Stripe's live API in tests

```ruby
# BAD — slow, flaky, costs money
Stripe.api_key = ENV["STRIPE_LIVE_KEY"]

# GOOD — use test mode keys, VCR, or stripe-mock
Stripe.api_key = ENV["STRIPE_TEST_KEY"]
```

Never use live keys in tests. Use test mode keys for integration tests, VCR cassettes for speed, or `stripe-mock` for fully offline testing.
