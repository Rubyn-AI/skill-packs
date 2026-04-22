---
name: testing-devise
triggers:
  - test devise
  - sign_in helper
  - devise test
  - authenticate test
  - login test
  - current_user test
gems:
  - devise
rails: ">=7.0"
---

# Testing with Devise

## Request specs: use Devise test helpers

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
end
```

```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  let(:user) { create(:user) }

  describe "GET /posts" do
    it "requires authentication" do
      get posts_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns posts for authenticated users" do
      sign_in user
      get posts_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /posts" do
    it "creates a post" do
      sign_in user
      expect {
        post posts_path, params: { post: { title: "Hello" } }
      }.to change(Post, :count).by(1)
    end
  end
end
```

`sign_in user` sets the Warden session without making an HTTP request. It's fast and doesn't depend on the sign-in form working.

## System tests: sign in through the UI

For system tests, sign in via the actual form to test the full authentication flow:

```ruby
# spec/support/sign_in_helper.rb
module SignInHelper
  def sign_in_as(user, password: "password")
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"
    expect(page).to have_current_path(root_path)
  end
end

RSpec.configure do |config|
  config.include SignInHelper, type: :system
end
```

```ruby
# spec/system/dashboard_spec.rb
RSpec.describe "Dashboard", type: :system do
  it "shows the dashboard after sign in" do
    user = create(:user)
    sign_in_as user
    expect(page).to have_text("Welcome, #{user.name}")
  end
end
```

## Anti-pattern: Using Devise helpers in controller tests

```ruby
# BAD — controller tests are deprecated for request specs
RSpec.describe PostsController, type: :controller do
  before { sign_in create(:user) }  # Devise::Test::ControllerHelpers
end

# GOOD — use request specs with IntegrationHelpers
RSpec.describe "Posts", type: :request do
  before { sign_in create(:user) }  # Devise::Test::IntegrationHelpers
end
```

## Pattern: Factory for Devise users

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "password123!" }
    password_confirmation { password }
    confirmed_at { Time.current }  # Skip confirmation in tests

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :admin do
      role { :admin }
    end

    trait :locked do
      locked_at { Time.current }
    end
  end
end
```

Always set `confirmed_at` in the factory default if you use `confirmable`. Otherwise every test needs to confirm the user first.

## Pattern: Testing authentication in API specs

```ruby
# For token-based auth (devise-jwt)
RSpec.describe "API Posts", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    post user_session_path, params: { user: { email: user.email, password: "password123!" } }
    token = response.headers["Authorization"]
    { "Authorization" => token }
  end

  it "returns posts with valid token" do
    get api_posts_path, headers: auth_headers
    expect(response).to have_http_status(:ok)
  end

  it "returns 401 without token" do
    get api_posts_path
    expect(response).to have_http_status(:unauthorized)
  end
end
```
