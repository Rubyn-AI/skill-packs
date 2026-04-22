---
name: graphql-mutations
triggers:
  - graphql mutation
  - graphql create
  - graphql update
  - graphql delete
  - mutation resolver
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Mutations

## Pattern: Standard mutation structure

```ruby
# app/graphql/mutations/create_post.rb
module Mutations
  class CreatePost < Mutations::BaseMutation
    argument :title, String, required: true
    argument :body, String, required: false

    field :post, Types::PostType
    field :errors, [String], null: false

    def resolve(title:, body: nil)
      post = context[:current_user].posts.build(title: title, body: body)

      if post.save
        { post: post, errors: [] }
      else
        { post: nil, errors: post.errors.full_messages }
      end
    end
  end
end
```

## Pattern: Mutation with authorization

```ruby
module Mutations
  class DeletePost < Mutations::BaseMutation
    argument :id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(id:)
      post = Post.find(id)

      unless context[:current_user] == post.author || context[:current_user].admin?
        return { success: false, errors: ["Not authorized"] }
      end

      post.destroy!
      { success: true, errors: [] }
    rescue ActiveRecord::RecordNotFound
      { success: false, errors: ["Post not found"] }
    end
  end
end
```

## Pattern: Register mutations

```ruby
# app/graphql/types/mutation_type.rb
module Types
  class MutationType < Types::BaseObject
    field :create_post, mutation: Mutations::CreatePost
    field :update_post, mutation: Mutations::UpdatePost
    field :delete_post, mutation: Mutations::DeletePost
  end
end
```

## Anti-pattern: Raising exceptions in mutations

```ruby
# BAD — GraphQL errors are ugly for clients
def resolve(id:)
  post = Post.find(id)  # Raises RecordNotFound → 500-style error
  post.destroy!
end

# GOOD — return structured errors
def resolve(id:)
  post = Post.find_by(id: id)
  return { success: false, errors: ["Post not found"] } unless post
  post.destroy!
  { success: true, errors: [] }
end
```

Return domain errors as fields. Reserve exceptions for truly unexpected failures.
