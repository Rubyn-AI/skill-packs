---
name: devise-security-hardening
triggers:
  - devise security
  - password policy
  - brute force
  - account lockout
  - session timeout
  - paranoid mode
gems:
  - devise
rails: ">=7.0"
---

# Devise Security Hardening

## Pattern: Paranoid mode

Don't reveal whether an email exists in your system.

```ruby
# config/initializers/devise.rb
config.paranoid = true
```

With paranoid mode on:
- Password reset says "If your email is in our system, you'll receive instructions" regardless of whether the email exists
- Sign-up doesn't reveal duplicate emails in error messages
- Confirmation resend doesn't leak email existence

## Pattern: Strong password requirements

```ruby
# config/initializers/devise.rb
config.password_length = 10..128

# For custom complexity rules, add a validation:
# app/models/user.rb
class User < ApplicationRecord
  validate :password_complexity

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      errors.add(:password, "must include at least one lowercase letter, one uppercase letter, and one digit")
    end
  end
end
```

## Pattern: Account lockout

```ruby
# config/initializers/devise.rb
config.lock_strategy = :failed_attempts
config.maximum_attempts = 5
config.unlock_strategy = :time  # or :email, or :both
config.unlock_in = 1.hour
config.last_attempt_warning = true  # Warn user on the last attempt
```

## Pattern: Session timeout

```ruby
# config/initializers/devise.rb
config.timeout_in = 30.minutes  # Requires :timeoutable module
```

## Pattern: Rate limiting sign-in attempts

Devise locks accounts after N failed attempts, but you should also rate-limit at the request level to prevent distributed brute force.

```ruby
# Using rack-attack
# config/initializers/rack_attack.rb
Rack::Attack.throttle("logins/ip", limit: 5, period: 60.seconds) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

Rack::Attack.throttle("logins/email", limit: 5, period: 60.seconds) do |req|
  if req.path == "/users/sign_in" && req.post?
    req.params.dig("user", "email")&.downcase&.strip
  end
end
```

## Anti-pattern: Not expiring sessions on password change

By default, Devise signs out all other sessions when a user changes their password. Don't disable this.

```ruby
# GOOD — this is the default, don't change it
# Devise automatically invalidates other sessions on password change

# BAD — disabling session invalidation
# config.sign_in_after_change_password = false  # Don't do this
```

## Pattern: Audit trail for authentication events

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :trackable  # Tracks sign_in_count, current_sign_in_at, last_sign_in_at, IPs

  after_commit :log_sign_in, on: :update, if: :saved_change_to_sign_in_count?

  private

  def log_sign_in
    Rails.logger.info("User #{id} signed in from #{current_sign_in_ip}")
    # Or write to an audit log table
  end
end
```
