---
name: devise-confirmable-lockable
triggers:
  - confirmable
  - lockable
  - email confirmation
  - account lock
  - unlock account
  - confirm email
  - reconfirmable
gems:
  - devise
rails: ">=7.0"
---

# Devise Confirmable & Lockable

## Confirmable: Email verification

```ruby
# User model
devise :confirmable

# Migration adds:
# t.string   :confirmation_token
# t.datetime :confirmed_at
# t.datetime :confirmation_sent_at
# t.string   :unconfirmed_email  # for reconfirmable
```

### Configuration

```ruby
# config/initializers/devise.rb
config.confirm_within = 3.days           # Token expiry
config.reconfirmable = true              # Require confirmation on email change
config.allow_unconfirmed_access_for = 2.days  # Grace period before requiring confirmation
```

### Pattern: Skip confirmation in seeds/tests

```ruby
user = User.new(email: "admin@example.com", password: "password")
user.skip_confirmation!
user.save!
```

### Anti-pattern: Confirming users in the controller

```ruby
# BAD — bypasses the confirmation flow
user.confirm

# GOOD — let Devise handle it via the confirmation email link
# The user clicks the link, Devise confirms automatically
```

## Lockable: Account lockout

```ruby
# User model
devise :lockable

# Migration adds:
# t.integer  :failed_attempts, default: 0
# t.string   :unlock_token
# t.datetime :locked_at
```

### Pattern: Unlock strategies

```ruby
config.lock_strategy = :failed_attempts
config.maximum_attempts = 5

# :time — auto-unlock after a period
config.unlock_strategy = :time
config.unlock_in = 1.hour

# :email — send unlock instructions
config.unlock_strategy = :email

# :both — either time or email
config.unlock_strategy = :both
```

### Pattern: Admin unlock

```ruby
# In a controller or console
user = User.find_by(email: "locked@example.com")
user.unlock_access!
```
