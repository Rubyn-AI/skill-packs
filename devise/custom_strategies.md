---
name: devise-custom-strategies
triggers:
  - warden strategy
  - custom authentication
  - api key auth
  - devise strategy
  - custom sign in
gems:
  - devise
rails: ">=7.0"
---

# Custom Devise Authentication Strategies

Devise uses Warden under the hood. For non-standard authentication (API keys, LDAP, SSO), create a custom Warden strategy.

## Pattern: API key authentication

```ruby
# config/initializers/devise.rb
Warden::Strategies.add(:api_key) do
  def valid?
    api_key.present?
  end

  def authenticate!
    user = User.find_by(api_key: api_key)
    user ? success!(user) : fail!("Invalid API key")
  end

  private

  def api_key
    env["HTTP_X_API_KEY"] || params["api_key"]
  end
end

# Wire it up
config.warden do |manager|
  manager.default_strategies(scope: :user).unshift(:api_key)
end
```

## Pattern: Multi-field authentication (username OR email)

```ruby
# config/initializers/devise.rb
config.authentication_keys = [:login]

# app/models/user.rb
class User < ApplicationRecord
  attr_accessor :login

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)&.downcase

    if login
      where("lower(email) = :login OR lower(username) = :login", login: login).first
    else
      where(conditions.to_h).first
    end
  end
end
```

## Anti-pattern: Overriding valid_password? for custom auth

Don't override `valid_password?` to add custom logic. Use a Warden strategy instead — it's the designed extension point and keeps concerns separated.
