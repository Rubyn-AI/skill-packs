---
name: pundit-namespaced-policies
triggers:
  - namespaced policy
  - admin policy
  - api policy
  - module policy
  - pundit namespace
gems:
  - pundit
rails: ">=7.0"
---

# Pundit Namespaced Policies

Different parts of your app may need different authorization rules for the same model. Admin controllers need different policies than public-facing controllers.

## Pattern: Namespaced policies with policy_scope

```ruby
# app/policies/admin/post_policy.rb
module Admin
  class PostPolicy < ApplicationPolicy
    def index?
      user.admin?
    end

    def update?
      user.admin?
    end

    def destroy?
      user.admin? && !record.published?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.all  # Admins see everything
      end
    end
  end
end
```

```ruby
# app/policies/post_policy.rb (public)
class PostPolicy < ApplicationPolicy
  def show?
    record.published? || user == record.author
  end

  def update?
    user == record.author
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.published.or(scope.where(author: user))
    end
  end
end
```

## Pattern: Using namespaced policies in controllers

```ruby
# app/controllers/admin/posts_controller.rb
module Admin
  class PostsController < Admin::BaseController
    def index
      @posts = policy_scope(Post, policy_scope_class: Admin::PostPolicy::Scope)
    end

    def update
      @post = Post.find(params[:id])
      authorize @post, policy_class: Admin::PostPolicy
      @post.update!(post_params)
    end
  end
end
```

Pass `policy_class:` to `authorize` and `policy_scope_class:` to `policy_scope` to use the namespaced policy.

## Pattern: Automatic namespace resolution

If your controller is namespaced, Pundit can resolve the policy automatically:

```ruby
# In Admin::PostsController, authorize(@post) looks for:
# 1. Admin::PostPolicy (namespaced — found!)
# 2. PostPolicy (fallback)
```

This works out of the box if your policy class name matches the controller namespace.

## Pattern: API policies

```ruby
# app/policies/api/v1/post_policy.rb
module Api
  module V1
    class PostPolicy < ApplicationPolicy
      def show?
        true  # API is public
      end

      def create?
        user.present? && user.api_access?
      end

      def update?
        user == record.author && user.api_access?
      end

      class Scope < ApplicationPolicy::Scope
        def resolve
          scope.published  # API only exposes published content
        end
      end
    end
  end
end
```

## Anti-pattern: One policy trying to handle all contexts

```ruby
# BAD — messy conditionals for different contexts
class PostPolicy < ApplicationPolicy
  def update?
    if admin_context?
      user.admin?
    elsif api_context?
      user == record.author && user.api_access?
    else
      user == record.author
    end
  end
end

# GOOD — separate policy per context
# PostPolicy for public
# Admin::PostPolicy for admin
# Api::V1::PostPolicy for API
```
