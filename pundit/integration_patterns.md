---
name: pundit-integration-patterns
triggers:
  - pundit controller
  - pundit strong params
  - pundit view
  - permitted_attributes
  - policy helper view
  - pundit current_user
gems:
  - pundit
rails: ">=7.0"
---

# Pundit Controller & View Integration

## Pattern: Policy-based strong parameters

Different roles may be allowed to update different fields:

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def permitted_attributes
    if user.admin?
      [:title, :body, :published, :featured, :author_id]
    else
      [:title, :body]
    end
  end
end
```

```ruby
# Controller
class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    authorize @post

    if @post.update(permitted_attributes(@post))
      redirect_to @post
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

`permitted_attributes(@post)` calls `PostPolicy#permitted_attributes` and filters `params[:post]` to only those keys.

## Pattern: Policy in views

```erb
<%# Show edit button only if the user can update %>
<% if policy(@post).update? %>
  <%= link_to "Edit", edit_post_path(@post) %>
<% end %>

<%# Show delete button only if the user can destroy %>
<% if policy(@post).destroy? %>
  <%= button_to "Delete", post_path(@post), method: :delete,
    data: { turbo_confirm: "Are you sure?" } %>
<% end %>

<%# Show admin section only if authorized %>
<% if policy(:dashboard).admin? %>
  <div class="admin-panel">
    ...
  </div>
<% end %>
```

## Pattern: verify_authorized and verify_policy_scoped

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  # Skip for specific controllers
end

class HomeController < ApplicationController
  skip_after_action :verify_authorized, only: [:index]
  skip_after_action :verify_policy_scoped, only: [:index]

  def index
    # Public page — no authorization needed
  end
end
```

These after_actions are safety nets. If you forget to call `authorize` in any action, the app raises `Pundit::AuthorizationNotPerformedError`. Always enable them.

## Pattern: Custom error handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    action = exception.query

    flash[:alert] = t(
      "pundit.#{policy_name}.#{action}",
      default: "You are not authorized to perform this action."
    )

    redirect_back(fallback_location: root_path)
  end
end
```

```yaml
# config/locales/en.yml
en:
  pundit:
    post_policy:
      update?: "You can only edit your own posts."
      destroy?: "You don't have permission to delete this post."
```

## Pattern: Pundit with Turbo

When using Turbo, return 403 instead of redirecting for unauthorized inline actions:

```ruby
def user_not_authorized(exception)
  respond_to do |format|
    format.html { redirect_back(fallback_location: root_path, alert: "Not authorized.") }
    format.turbo_stream {
      render turbo_stream: turbo_stream.update("flash", partial: "shared/flash",
        locals: { alert: "Not authorized." }), status: :forbidden
    }
  end
end
```

## Anti-pattern: Duplicating policy checks in views and controllers

```ruby
# BAD — authorization logic in two places
# Controller:
def update
  @post = Post.find(params[:id])
  if current_user == @post.author || current_user.admin?
    # ...
  end
end
# View:
<% if current_user == @post.author || current_user.admin? %>

# GOOD — single source of truth in the policy
# Controller:
authorize @post
# View:
<% if policy(@post).update? %>
```

The policy is the single source of truth. Controllers call `authorize`, views call `policy().action?`. The logic lives in one place.
