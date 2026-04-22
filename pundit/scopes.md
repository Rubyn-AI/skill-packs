---
name: pundit-scopes
triggers:
  - policy scope
  - policy_scope
  - pundit scope
  - resolve
  - authorized records
gems:
  - pundit
rails: ">=7.0"
---

# Pundit Scopes

Scopes filter collections based on what the current user is allowed to see. They answer: "which records can this user access?"

## Pattern: Basic scope

```ruby
class PostPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(published: true).or(scope.where(author: user))
      end
    end
  end
end
```

```ruby
# Controller
def index
  @posts = policy_scope(Post)
  # Admin sees all posts
  # Regular user sees published posts + their own drafts
end
```

## Pattern: Scope with joins

```ruby
class ProjectPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:memberships).where(memberships: { user_id: user.id })
      end
    end
  end
end
```

## Pattern: Nested resource scope

```ruby
# app/controllers/comments_controller.rb
def index
  @post = Post.find(params[:post_id])
  authorize @post, :show?  # Can they see the post at all?
  @comments = policy_scope(@post.comments)
end
```

## Anti-pattern: Not using scopes for index actions

```ruby
# BAD — shows all records, relies on view to hide unauthorized ones
def index
  @posts = Post.all
end

# GOOD — scope at the query level
def index
  @posts = policy_scope(Post)
end
```

Always filter at the database level. View-level hiding is a UI convenience, not a security boundary.
