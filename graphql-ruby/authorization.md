---
name: graphql-authorization
triggers:
  - graphql auth
  - graphql authorize
  - graphql pundit
  - graphql permission
  - field visibility
  - graphql access control
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Authorization

## Pattern: Field-level authorization with authorized?

```ruby
class Types::PostType < Types::BaseObject
  field :title, String, null: false
  field :admin_notes, String, null: true

  def self.authorized?(object, context)
    # Object-level: can this user see posts at all?
    true
  end

  def admin_notes
    # Field-level: only admins see admin notes
    return nil unless context[:current_user]&.admin?
    object.admin_notes
  end
end
```

## Pattern: Authorization with Pundit

```ruby
class Types::PostType < Types::BaseObject
  def self.authorized?(post, context)
    user = context[:current_user]
    Pundit.policy(user, post).show?
  end
end

# In mutations
class Mutations::UpdatePost < Mutations::BaseMutation
  argument :id, ID, required: true
  argument :title, String, required: true

  field :post, Types::PostType

  def resolve(id:, title:)
    post = Post.find(id)
    policy = Pundit.policy!(context[:current_user], post)

    unless policy.update?
      raise GraphQL::ExecutionError, "Not authorized to update this post"
    end

    post.update!(title: title)
    { post: post }
  end
end
```

## Pattern: Visibility (hide fields entirely)

```ruby
class Types::UserType < Types::BaseObject
  field :email, String, null: false
  field :phone, String

  # Only visible to admins — other users don't even see the field in schema introspection
  field :admin_dashboard_url, String do
    def visible?(context)
      context[:current_user]&.admin?
    end
  end
end
```

`visible?` hides the field from the schema. `authorized?` keeps it in the schema but returns null or raises when accessed.

## Pattern: Authentication in the GraphQL context

```ruby
# app/controllers/graphql_controller.rb
class GraphqlController < ApplicationController
  skip_before_action :verify_authenticity_token

  def execute
    result = MyAppSchema.execute(
      params[:query],
      variables: params[:variables],
      context: {
        current_user: current_user_from_token,
        request: request
      }
    )
    render json: result
  end

  private

  def current_user_from_token
    token = request.headers["Authorization"]&.sub("Bearer ", "")
    return nil unless token
    User.find_by_auth_token(token)
  end
end
```

## Pattern: Require authentication for all mutations

```ruby
class Mutations::BaseMutation < GraphQL::Schema::Mutation
  def ready?(**args)
    unless context[:current_user]
      raise GraphQL::ExecutionError, "You must be logged in"
    end
    true
  end
end
```

## Anti-pattern: Authorization only in mutations

```ruby
# BAD — queries are unprotected
class Types::QueryType < Types::BaseObject
  field :users, [Types::UserType]
  def users
    User.all  # Anyone can see all users!
  end
end

# GOOD — authorize queries too
def users
  raise GraphQL::ExecutionError, "Not authorized" unless context[:current_user]&.admin?
  User.all
end
```
