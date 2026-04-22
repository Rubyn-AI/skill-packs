---
name: graphql-schema-design
triggers:
  - graphql schema
  - graphql type
  - graphql field
  - graphql object
  - GraphQL::Schema
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Schema Design

## Pattern: Type definitions

```ruby
# app/graphql/types/post_type.rb
module Types
  class PostType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :body, String
    field :published_at, GraphQL::Types::ISO8601DateTime
    field :author, Types::UserType, null: false
    field :comments, [Types::CommentType], null: false
    field :comments_count, Integer, null: false

    def comments_count
      object.comments.size
    end

    def author
      # Use dataloader to avoid N+1
      dataloader.with(Sources::ActiveRecordObject, User).load(object.author_id)
    end
  end
end
```

## Pattern: Query root

```ruby
# app/graphql/types/query_type.rb
module Types
  class QueryType < Types::BaseObject
    field :posts, [Types::PostType], null: false do
      argument :published, Boolean, required: false
    end

    field :post, Types::PostType do
      argument :id, ID, required: true
    end

    def posts(published: nil)
      scope = Post.all
      scope = scope.where.not(published_at: nil) if published
      scope.order(created_at: :desc)
    end

    def post(id:)
      Post.find(id)
    end
  end
end
```

## Anti-pattern: Exposing ActiveRecord directly

```ruby
# BAD — leaks database structure, no access control
field :users, [Types::UserType] do
  def resolve
    User.all  # Exposes every user, no pagination, no auth
  end
end

# GOOD — scoped, paginated, authorized
field :users, Types::UserType.connection_type, null: false

def users
  context[:current_user]&.admin? ? User.all : User.none
end
```

## Pattern: Enum types

```ruby
module Types
  class PostStatusType < Types::BaseEnum
    value "DRAFT", value: "draft"
    value "PUBLISHED", value: "published"
    value "ARCHIVED", value: "archived"
  end
end
```

## Pattern: Input types for mutations

```ruby
module Types
  class PostInputType < Types::BaseInputObject
    argument :title, String, required: true
    argument :body, String, required: false
    argument :published, Boolean, required: false, default_value: false
  end
end
```
