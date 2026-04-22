---
name: testing-sidekiq
triggers:
  - test sidekiq
  - sidekiq test
  - perform_inline
  - assert_enqueued
  - have_enqueued_sidekiq_job
  - sidekiq testing
gems:
  - sidekiq
rails: ">=7.0"
---

# Testing Sidekiq Jobs

## Setup

```ruby
# spec/rails_helper.rb
require "sidekiq/testing"

RSpec.configure do |config|
  config.before(:each) do
    Sidekiq::Testing.fake!  # Jobs are pushed to a per-class array, not executed
  end
end
```

## Testing modes

| Mode | What happens | Use for |
|------|-------------|---------|
| `Sidekiq::Testing.fake!` | Jobs pushed to array, not executed | Most unit/request tests |
| `Sidekiq::Testing.inline!` | Jobs execute immediately in the same thread | Integration tests |
| `Sidekiq::Testing.disable!` | Jobs enqueue to real Redis | Full system tests with Sidekiq running |

## Pattern: Assert job was enqueued

```ruby
RSpec.describe OrdersController, type: :request do
  it "enqueues a processing job" do
    sign_in user

    expect {
      post orders_path, params: { order: valid_params }
    }.to change(ProcessOrderJob.jobs, :size).by(1)

    # Verify the job arguments
    job = ProcessOrderJob.jobs.last
    expect(job["args"]).to eq([Order.last.id])
  end
end
```

## Pattern: Using ActiveJob test helpers (framework-agnostic)

```ruby
RSpec.describe "Orders", type: :request do
  include ActiveJob::TestHelper

  it "enqueues a processing job" do
    sign_in user

    assert_enqueued_with(job: ProcessOrderJob) do
      post orders_path, params: { order: valid_params }
    end
  end

  it "enqueues the job on the critical queue" do
    assert_enqueued_with(job: ProcessOrderJob, queue: "critical") do
      post orders_path, params: { order: valid_params }
    end
  end
end
```

## Pattern: Testing job logic directly

```ruby
RSpec.describe SendWelcomeEmailJob do
  let(:user) { create(:user) }

  it "sends the welcome email" do
    expect {
      described_class.new.perform(user.id)
    }.to change { ActionMailer::Base.deliveries.count }.by(1)
  end

  it "handles deleted users gracefully" do
    user.destroy!
    expect {
      described_class.new.perform(user.id)
    }.not_to raise_error
  end
end
```

Call `.new.perform(args)` directly — this tests the job's logic without the Sidekiq infrastructure.

## Pattern: Testing with inline mode for integration

```ruby
RSpec.describe "Order processing", type: :request do
  around do |example|
    Sidekiq::Testing.inline! do
      example.run
    end
  end

  it "processes the order end-to-end" do
    sign_in user
    post orders_path, params: { order: valid_params }
    
    # Job ran synchronously — order is already processed
    expect(Order.last.status).to eq("processed")
  end
end
```

## Anti-pattern: Testing Sidekiq internals

```ruby
# BAD — tests Sidekiq, not your code
it "has the right queue" do
  expect(MyJob.get_sidekiq_options["queue"]).to eq("critical")
end

# GOOD — test the behavior, not the configuration
it "processes critical work quickly" do
  # Test that the job actually does what it's supposed to do
  described_class.new.perform(order.id)
  expect(order.reload.status).to eq("processed")
end
```
