---
name: devise-basic-setup
triggers:
  - devise setup
  - devise install
  - devise generator
  - devise model
  - devise routes
  - devise views
  - devise modules
gems:
  - devise
rails: ">=7.0"
---

# Devise Basic Setup

## Installation

```bash
bundle add devise
rails generate devise:install
rails generate devise User
rails db:migrate
```

## Choosing modules

Enable only the modules you need in the model:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable
end
```

| Module | What it does | Include? |
|--------|-------------|----------|
| `database_authenticatable` | Email/password sign-in | Always |
| `registerable` | Sign-up and account deletion | Usually |
| `recoverable` | Password reset via email | Usually |
| `rememberable` | "Remember me" cookie | Usually |
| `validatable` | Email/password validations | Usually |
| `confirmable` | Email confirmation before sign-in | Production apps |
| `lockable` | Lock account after failed attempts | Production apps |
| `trackable` | Track sign-in count, timestamps, IPs | If you need analytics |
| `timeoutable` | Session expiry after inactivity | Sensitive apps |
| `omniauthable` | OAuth sign-in | If using OAuth |

## Pattern: Generating and customizing views

```bash
rails generate devise:views users
```

This copies Devise's ERB views into `app/views/users/` where you can customize them. Without this, Devise uses its built-in views from the gem.

## Pattern: Require authentication everywhere, allow specific pages

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end

# app/controllers/home_controller.rb
class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
end
```

## Pattern: Custom after-sign-in redirect

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protected

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || dashboard_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end
end
```

`stored_location_for` returns the URL the user was trying to access before being redirected to sign-in. Always check it first.

## Anti-pattern: Adding fields to the Devise User model without permitting them

```ruby
# BAD — new fields are silently ignored by Devise's strong params
# Devise only permits email, password, password_confirmation by default

# GOOD — configure permitted parameters
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :username])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :username, :avatar])
  end
end
```

## Configuration essentials

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  config.mailer_sender = "noreply@yourapp.com"
  config.authentication_keys = [:email]  # or [:username]
  config.password_length = 8..128
  config.timeout_in = 30.minutes  # if using :timeoutable
  config.lock_strategy = :failed_attempts
  config.maximum_attempts = 5
  config.unlock_strategy = :time
  config.unlock_in = 1.hour
  config.sign_out_via = :delete
  config.navigational_formats = ["*/*", :html, :turbo_stream]
end
```

The `navigational_formats` line is critical for Turbo compatibility. Without `:turbo_stream`, Devise won't respond to Turbo requests correctly.
