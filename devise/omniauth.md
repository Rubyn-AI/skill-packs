---
name: devise-omniauth
triggers:
  - omniauth
  - oauth
  - google sign in
  - github login
  - social login
  - provider callback
gems:
  - devise
  - omniauth
  - omniauth-rails_csrf_protection
rails: ">=7.0"
---

# Devise + OmniAuth

## Pattern: Adding a provider

```ruby
# Gemfile
gem "omniauth-google-oauth2"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"  # Required for POST-based OmniAuth

# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :omniauthable,
         omniauth_providers: [:google_oauth2, :github]
end

# config/initializers/devise.rb
config.omniauth :google_oauth2,
  ENV["GOOGLE_CLIENT_ID"],
  ENV["GOOGLE_CLIENT_SECRET"],
  scope: "email,profile"

config.omniauth :github,
  ENV["GITHUB_CLIENT_ID"],
  ENV["GITHUB_CLIENT_SECRET"],
  scope: "user:email"
```

## Pattern: OmniAuth callback controller

```ruby
# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    handle_auth("Google")
  end

  def github
    handle_auth("GitHub")
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{failure_message}"
  end

  private

  def handle_auth(provider_name)
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider_name) if is_navigational_format?
    else
      session["devise.oauth_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url,
        alert: @user.errors.full_messages.join(", ")
    end
  end
end
```

## Pattern: User.from_omniauth

```ruby
# app/models/user.rb
class User < ApplicationRecord
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
      user.avatar_url = auth.info.image
      user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    end
  end
end
```

## Anti-pattern: GET-based OmniAuth requests (CSRF vulnerability)

OmniAuth 2.0+ requires POST requests. Never use GET links for OAuth.

```erb
<%# BAD — GET request, vulnerable to CSRF %>
<%= link_to "Sign in with Google", user_google_oauth2_omniauth_authorize_path %>

<%# GOOD — POST via button_to %>
<%= button_to "Sign in with Google", user_google_oauth2_omniauth_authorize_path, method: :post %>
```

The `omniauth-rails_csrf_protection` gem enforces this.

## Pattern: Account linking (multiple providers per user)

```ruby
# Migration
create_table :identities do |t|
  t.references :user, null: false, foreign_key: true
  t.string :provider, null: false
  t.string :uid, null: false
  t.timestamps
  t.index [:provider, :uid], unique: true
end

# app/models/identity.rb
class Identity < ApplicationRecord
  belongs_to :user
  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
end

# Modified from_omniauth
def self.from_omniauth(auth)
  identity = Identity.find_or_initialize_by(provider: auth.provider, uid: auth.uid)
  
  if identity.persisted?
    identity.user
  else
    user = User.find_by(email: auth.info.email) || User.new(
      email: auth.info.email,
      password: Devise.friendly_token[0, 20]
    )
    identity.user = user
    identity.save!
    user
  end
end
```
