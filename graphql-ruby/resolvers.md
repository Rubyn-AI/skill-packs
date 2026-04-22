---
name: graphql-resolvers
triggers:
  - graphql resolver
  - resolver class
  - field resolver
  - graphql query resolve
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Resolvers

## Pattern: Inline resolvers (methods on the type)

For simple fields, define a method on the type class:

```ruby
class Types::PostType < Types::BaseObject
  field :title, String, null: false
  field :excerpt, String

  def excerpt
    object.body&.truncate(200)
  end
end
```

`object` is the underlying ActiveRecord model. If no method is defined, GraphQL-Ruby calls `object.title` automatically.

## Pattern: Dedicated resolver classes

For complex query fields, extract to a resolver class:

```ruby
# app/graphql/resolvers/search_posts.rb
module Resolvers
  class SearchPosts < Resolvers::BaseResolver
    type [Types::PostType], null: false

    argument :query, String, required: true
    argument :category, String, required: false
    argument :limit, Integer, required: false, default_value: 20

    def resolve(query:, category: nil, limit: 20)
      scope = Post.published.search(query)
      scope = scope.where(category: category) if category
      scope.limit([limit, 100].min)
    end
  end
end
```

```ruby
# Wire it to the query type
class Types::QueryType < Types::BaseObject
  field :search_posts, resolver: Resolvers::SearchPosts
end
```

## Pattern: Base resolver with common logic

```ruby
# app/graphql/resolvers/base_resolver.rb
module Resolvers
  class BaseResolver < GraphQL::Schema::Resolver
    def current_user
      context[:current_user]
    end

    def authorized?(**args)
      return true if current_user
      raise GraphQL::ExecutionError, "Authentication required"
    end
  end
end
```

## Pattern: Resolver with authorization

```ruby
module Resolvers
  class AdminUsers < Resolvers::BaseResolver
    type [Types::UserType], null: false

    def authorized?(**args)
      super && current_user.admin?
    end

    def resolve
      User.all.order(:created_at)
    end
  end
end
```

`authorized?` is called before `resolve`. Return `false` or raise to block unauthorized access.

## Anti-pattern: Fat resolvers with business logic

```ruby
# BAD — resolver does too much
def resolve(title:, body:)
  post = Post.new(title: title, body: body, author: current_user)
  post.body = MarkdownProcessor.render(body)
  post.slug = title.parameterize
  NotificationService.notify_followers(current_user, post) if post.save
  post
end

# GOOD — delegate to service objects
def resolve(title:, body:)
  Posts::CreateService.call(
    author: current_user,
    title: title,
    body: body
  )
end
```

Resolvers are adapters between GraphQL and your domain. Keep them thin.

## Anti-pattern: N+1 in resolvers

```ruby
# BAD — each post resolver loads its author separately
def author
  object.author  # N+1 when resolving a list of posts
end

# GOOD — use DataLoader
def author
  dataloader.with(Sources::ActiveRecordObject, User).load(object.author_id)
end
```
