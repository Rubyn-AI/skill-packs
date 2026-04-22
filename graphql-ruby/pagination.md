---
name: graphql-pagination
triggers:
  - graphql pagination
  - graphql connection
  - cursor pagination
  - relay connection
  - graphql page
  - graphql nodes edges
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Pagination

## Pattern: Connection-based pagination (Relay-style)

```ruby
class Types::QueryType < Types::BaseObject
  field :posts, Types::PostType.connection_type, null: false

  def posts
    Post.published.order(created_at: :desc)
  end
end
```

`.connection_type` automatically adds `edges`, `nodes`, `pageInfo`, `first`, `after`, `last`, and `before` arguments.

```graphql
query {
  posts(first: 10, after: "abc123") {
    edges {
      cursor
      node {
        id
        title
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## Pattern: Simplified nodes access

```graphql
# Shorter — skip edges, access nodes directly
query {
  posts(first: 10) {
    nodes {
      id
      title
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

## Pattern: Custom connection with total count

```ruby
class Types::PostConnectionWithCountType < GraphQL::Types::Connection
  edge_type(Types::PostType.edge_type)

  field :total_count, Integer, null: false

  def total_count
    # Use SQL count — don't load all records
    object.items.unscope(:order).count
  end
end
```

```ruby
field :posts, Types::PostConnectionWithCountType, null: false
```

## Pattern: Max page size

```ruby
class MyAppSchema < GraphQL::Schema
  default_max_page_size 50
  max_page_size 100  # Hard limit even if client asks for more
end

# Or per-field
field :posts, Types::PostType.connection_type, null: false, max_page_size: 25
```

## Anti-pattern: Offset-based pagination

```ruby
# BAD — offset pagination is slow for large datasets and skips/duplicates on inserts
field :posts, [Types::PostType] do
  argument :page, Integer, required: false, default_value: 1
  argument :per_page, Integer, required: false, default_value: 20
end

def posts(page:, per_page:)
  Post.offset((page - 1) * per_page).limit(per_page)
end

# GOOD — cursor-based pagination (connection_type) is stable and efficient
field :posts, Types::PostType.connection_type, null: false
```

Cursor pagination uses `WHERE id > cursor_id` which is index-friendly and stable when records are inserted or deleted between pages.

## Pattern: Filtering with pagination

```ruby
field :posts, Types::PostType.connection_type, null: false do
  argument :category, String, required: false
  argument :published, Boolean, required: false
end

def posts(category: nil, published: nil)
  scope = Post.all
  scope = scope.where(category: category) if category
  scope = scope.where.not(published_at: nil) if published
  scope.order(created_at: :desc)
end
```

Return an ActiveRecord relation — GraphQL-Ruby handles the cursor logic on the relation.
