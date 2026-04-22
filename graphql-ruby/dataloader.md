---
name: graphql-dataloader
triggers:
  - graphql dataloader
  - graphql n+1
  - batch loading
  - graphql source
  - GraphQL::Dataloader
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL DataLoader (N+1 Prevention)

## The problem

```graphql
{
  posts {
    author { name }  # N+1: one query per post to load author
  }
}
```

Without batching, loading 50 posts triggers 50 author queries.

## Pattern: DataLoader source for ActiveRecord

```ruby
# app/graphql/sources/active_record_object.rb
module Sources
  class ActiveRecordObject < GraphQL::Dataloader::Source
    def initialize(model_class)
      @model_class = model_class
    end

    def fetch(ids)
      records = @model_class.where(id: ids).index_by(&:id)
      ids.map { |id| records[id] }
    end
  end
end
```

## Pattern: Using DataLoader in type definitions

```ruby
# app/graphql/types/post_type.rb
module Types
  class PostType < Types::BaseObject
    field :author, Types::UserType, null: false

    def author
      dataloader.with(Sources::ActiveRecordObject, User).load(object.author_id)
    end
  end
end
```

DataLoader batches all `load` calls within a single query execution. 50 posts → 1 author query.

## Pattern: DataLoader for has_many associations

```ruby
module Sources
  class HasMany < GraphQL::Dataloader::Source
    def initialize(model_class, foreign_key)
      @model_class = model_class
      @foreign_key = foreign_key
    end

    def fetch(ids)
      records = @model_class.where(@foreign_key => ids).group_by(&@foreign_key)
      ids.map { |id| records[id] || [] }
    end
  end
end

# Usage in type
field :comments, [Types::CommentType], null: false

def comments
  dataloader.with(Sources::HasMany, Comment, :post_id).load(object.id)
end
```

## Anti-pattern: Using ActiveRecord associations directly

```ruby
# BAD — N+1 queries
def comments
  object.comments  # Rails lazy-loads, GraphQL resolves one-by-one
end

# GOOD — DataLoader batches
def comments
  dataloader.with(Sources::HasMany, Comment, :post_id).load(object.id)
end
```

ActiveRecord associations inside GraphQL resolvers are the primary source of N+1 queries. Always use DataLoader.
