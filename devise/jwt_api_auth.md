---
name: devise-jwt-api
triggers:
  - devise jwt
  - api authentication
  - token auth
  - bearer token
  - devise api
  - stateless auth
gems:
  - devise
  - devise-jwt
rails: ">=7.0"
---

# Devise JWT API Authentication

## Setup

```ruby
# Gemfile
gem "devise-jwt"

# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
end

# app/models/jwt_denylist.rb
class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist
  self.table_name = "jwt_denylist"
end
```

```ruby
# Migration
create_table :jwt_denylist do |t|
  t.string :jti, null: false
  t.datetime :exp, null: false
end
add_index :jwt_denylist, :jti
```

## Configuration

```ruby
# config/initializers/devise.rb
config.jwt do |jwt|
  jwt.secret = ENV["DEVISE_JWT_SECRET_KEY"]
  jwt.dispatch_requests = [
    ["POST", %r{^/api/v1/sign_in$}]
  ]
  jwt.revocation_requests = [
    ["DELETE", %r{^/api/v1/sign_out$}]
  ]
  jwt.expiration_time = 24.hours.to_i
end
```

## Pattern: API sessions controller

```ruby
# app/controllers/api/v1/sessions_controller.rb
module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        render json: {
          user: UserSerializer.new(resource),
          token: request.env["warden-jwt_auth.token"]
        }, status: :ok
      end

      def respond_to_on_destroy
        if current_user
          render json: { message: "Signed out" }, status: :ok
        else
          render json: { message: "No active session" }, status: :unauthorized
        end
      end
    end
  end
end
```

## Pattern: Authenticating API requests

Clients send the JWT in the `Authorization` header:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

```ruby
# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_user!

      private

      def authenticate_user!
        head :unauthorized unless current_user
      end
    end
  end
end
```

## Anti-pattern: Storing JWTs in localStorage

JWTs in localStorage are vulnerable to XSS attacks. For browser-based SPAs, use httpOnly cookies instead:

```ruby
# config/initializers/devise.rb
config.jwt do |jwt|
  jwt.cookie_name = "rubyn_jwt"
  jwt.cookie_options = {
    httponly: true,
    secure: Rails.env.production?,
    same_site: :lax
  }
end
```

For native mobile apps, secure device storage (Keychain on iOS, EncryptedSharedPreferences on Android) is appropriate.
