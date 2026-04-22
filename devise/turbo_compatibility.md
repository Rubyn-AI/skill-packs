---
name: devise-turbo-compatibility
triggers:
  - devise turbo
  - devise hotwire
  - devise 422
  - devise redirect
  - devise sign_in form
  - devise flash
  - devise responder
gems:
  - devise
  - turbo-rails
rails: ">=7.0"
---

# Devise + Turbo Compatibility

Devise was built before Turbo existed. Several default behaviors break with Turbo unless you patch them. These are the fixes.

## Problem: Devise renders with 200 on failed login

Turbo expects `422` for validation failures. Devise's default `SessionsController` renders with `200`, which Turbo treats as a success — the user sees a blank page or unexpected navigation.

## Pattern: Override Devise controllers to return correct status codes

```ruby
# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  def create
    self.resource = warden.authenticate(auth_options)
    if resource
      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      self.resource = resource_class.new(sign_in_params)
      flash.now[:alert] = I18n.t("devise.failure.invalid", authentication_keys: "Email")
      render :new, status: :unprocessable_entity
    end
  end
end

# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  def create
    build_resource(sign_up_params)
    resource.save
    if resource.persisted?
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      render :new, status: :unprocessable_entity
    end
  end
end

# app/controllers/users/passwords_controller.rb
class Users::PasswordsController < Devise::PasswordsController
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    self.resource = resource_class.reset_password_by_token(resource_params)
    if resource.errors.empty?
      resource.unlock_access! if unlockable?(resource)
      if Devise.sign_in_after_reset_password
        flash_message = resource.active_for_authentication? ? :updated : :updated_not_active
        set_flash_message!(:notice, flash_message)
        resource.after_database_authentication
        sign_in(resource_name, resource)
      else
        set_flash_message!(:notice, :updated_not_active)
      end
      respond_with resource, location: after_resetting_password_path_for(resource)
    else
      set_minimum_password_length
      render :edit, status: :unprocessable_entity
    end
  end
end
```

## Wire the custom controllers in routes

```ruby
# config/routes.rb
devise_for :users, controllers: {
  sessions: "users/sessions",
  registrations: "users/registrations",
  passwords: "users/passwords"
}
```

## Fix: Turbo-compatible flash messages

Devise sets flash messages on redirects. With Turbo, flashes render via the standard Rails `flash` partial. Make sure your layout handles them:

```erb
<%# app/views/layouts/application.html.erb %>
<div id="flash">
  <% flash.each do |type, message| %>
    <% next if message.blank? %>
    <div class="flash flash-<%= type %>" data-controller="auto-dismiss">
      <%= message %>
    </div>
  <% end %>
</div>
```

## Fix: navigate: "replace" on Devise redirects

After sign-in, Devise redirects to `after_sign_in_path_for`. Turbo follows the redirect, but the sign-in page stays in browser history. Fix by using `turbo_action: "replace"`:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  private

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end
end
```

Turbo Drive handles `302` redirects after form submission by visiting the redirect URL with `action: "replace"` by default — so the sign-in page doesn't pollute back-button history. This works out of the box with Turbo 7.2+.

## Fix: Sign out with DELETE

Devise defaults to `DELETE` for sign-out. With Turbo, link methods require `data-turbo-method`:

```erb
<%# Works with Turbo %>
<%= button_to "Sign out", destroy_user_session_path, method: :delete %>

<%# Also works — link with turbo method %>
<%= link_to "Sign out", destroy_user_session_path, data: { turbo_method: :delete } %>
```

Or change Devise to use GET for sign-out (simpler but less RESTful):

```ruby
# config/initializers/devise.rb
config.sign_out_via = :get  # or :delete (default)
```

## Anti-pattern: Using `data-method` instead of `data-turbo-method`

```erb
<%# BAD — Rails UJS attribute, doesn't work with Turbo %>
<%= link_to "Sign out", destroy_user_session_path, method: :delete %>

<%# GOOD — Turbo-native attribute %>
<%= link_to "Sign out", destroy_user_session_path, data: { turbo_method: :delete } %>

<%# BEST — button_to handles method automatically %>
<%= button_to "Sign out", destroy_user_session_path, method: :delete %>
```

`button_to` generates a hidden form with the correct `_method` field. It works with both Turbo and non-Turbo contexts.
