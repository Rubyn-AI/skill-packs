---
name: graphql-performance
triggers:
  - graphql performance
  - graphql complexity
  - query depth
  - graphql slow
  - persisted queries
  - graphql n+1
  - max complexity
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Performance

## Pattern: Query complexity analysis

Prevent expensive queries by assigning complexity costs to fields:

```ruby
class Types::PostType < Types::BaseObject
  field :title, String, null: false, complexity: 1
  field :comments, [Types::CommentType], null: false, complexity: 10
  field :author, Types::UserType, null: false, complexity: 5
end

class MyAppSchema < GraphQL::Schema
  max_complexity 200  # Reject queries exceeding this complexity
end
```

A query requesting posts with comments and authors has complexity roughly `posts_count * (1 + 10 + 5)`. If it exceeds 200, the query is rejected before execution.

## Pattern: Query depth limits

Prevent deeply nested queries (common in malicious/accidental abuse):

```ruby
class MyAppSchema < GraphQL::Schema
  max_depth 10  # Reject queries deeper than 10 levels
end
```

```graphql
# This would be rejected if it exceeds max_depth
{
  posts {
    author {
      posts {
        comments {
          author {
            posts {
              # ...keeps going
            }
          }
        }
      }
    }
  }
}
```

## Pattern: Timeout

```ruby
class MyAppSchema < GraphQL::Schema
  use GraphQL::Schema::Timeout, max_seconds: 10
end
```

Long-running queries are terminated after the timeout. Partial results are returned for fields that completed.

## Pattern: Persisted queries

Clients send a hash instead of the full query string. Reduces bandwidth and prevents arbitrary query injection.

```ruby
class MyAppSchema < GraphQL::Schema
  use GraphQL::PersistedQueries,
    compiled_queries: true,
    store: GraphQL::PersistedQueries::RedisStore.new(redis: Redis.new)
end
```

## Pattern: Lookahead for conditional eager loading

```ruby
class Types::QueryType < Types::BaseObject
  field :posts, [Types::PostType], null: false, extras: [:lookahead]

  def posts(lookahead:)
    scope = Post.all

    if lookahead.selects?(:author)
      scope = scope.includes(:author)
    end

    if lookahead.selects?(:comments)
      scope = scope.includes(:comments)
    end

    scope
  end
end
```

`lookahead` tells you which fields the client requested so you can eager-load only what's needed.

## Pattern: Batch loading with DataLoader

See the DataLoader skill for detailed patterns. In summary:

```ruby
def author
  dataloader.with(Sources::ActiveRecordObject, User).load(object.author_id)
end
```

DataLoader batches all `load` calls within a single query execution. This is the primary defense against N+1 queries.

## Anti-pattern: No complexity limits

```ruby
# BAD — any client can send a query that joins every table
class MyAppSchema < GraphQL::Schema
  # No max_complexity, no max_depth, no timeout
end

# GOOD — defense in depth
class MyAppSchema < GraphQL::Schema
  max_complexity 300
  max_depth 12
  use GraphQL::Schema::Timeout, max_seconds: 15
  default_max_page_size 50
end
```

Always set complexity, depth, timeout, and page size limits. Without them, a single malicious query can take down your database.

## Anti-pattern: Eager loading everything

```ruby
# BAD — loads associations the client didn't even ask for
def posts
  Post.includes(:author, :comments, :tags, :categories, :media)
end

# GOOD — use lookahead to load only requested associations
def posts(lookahead:)
  scope = Post.all
  scope = scope.includes(:author) if lookahead.selects?(:author)
  scope = scope.includes(:comments) if lookahead.selects?(:comments)
  scope
end
```
