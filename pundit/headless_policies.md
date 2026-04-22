---
name: pundit-headless-policies
triggers:
  - headless policy
  - policy without record
  - dashboard policy
  - pundit no record
  - authorize without model
gems:
  - pundit
rails: ">=7.0"
---

# Pundit Headless Policies

Headless policies authorize actions that don't operate on a specific record — like accessing a dashboard, running a report, or viewing admin pages.

## Pattern: Headless policy with a symbol

```ruby
# app/policies/dashboard_policy.rb
class DashboardPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  def admin?
    user.admin?
  end

  def analytics?
    user.admin? || user.role.in?(%w[manager analyst])
  end
end
```

```ruby
# Controller
class DashboardController < ApplicationController
  def show
    authorize :dashboard, :show?
  end

  def admin
    authorize :dashboard, :admin?
  end

  def analytics
    authorize :dashboard, :analytics?
  end
end
```

When you pass a symbol (`:dashboard`), Pundit resolves `DashboardPolicy` and passes `nil` as the record.

## Pattern: Handling nil record in the policy

```ruby
class DashboardPolicy < ApplicationPolicy
  def initialize(user, _record)
    # record is nil for headless policies — that's expected
    super
  end

  def show?
    user.present?  # Don't call methods on record — it's nil
  end
end
```

## Pattern: Feature flag policies

```ruby
class FeaturePolicy < ApplicationPolicy
  def beta_access?
    user.beta_tester? || user.admin?
  end

  def ai_assistant?
    user.plan.in?(%w[pro enterprise])
  end
end
```

```ruby
# In any controller
if policy(:feature).ai_assistant?
  # Show AI features
end

# Or in views
<% if policy(:feature).ai_assistant? %>
  <%= render "ai_sidebar" %>
<% end %>
```

## Anti-pattern: Creating a dummy record for headless authorization

```ruby
# BAD — creates an unnecessary object just to satisfy Pundit
authorize Post.new, :can_view_analytics?

# GOOD — use a headless policy with a symbol
authorize :analytics, :show?
```
