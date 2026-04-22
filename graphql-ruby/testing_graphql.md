---
name: graphql-testing
triggers:
  - test graphql
  - graphql spec
  - query spec
  - mutation spec
  - graphql rspec
gems:
  - graphql
rails: ">=7.0"
---

# Testing GraphQL-Ruby

## Pattern: Query specs

```ruby
# spec/graphql/queries/posts_query_spec.rb
RSpec.describe "PostsQuery" do
  let(:user) { create(:user) }
  let!(:published_post) { create(:post, published: true) }
  let!(:draft_post) { create(:post, published: false, author: user) }

  let(:query) do
    <<~GQL
      query {
        posts {
          nodes {
            id
            title
          }
        }
      }
    GQL
  end

  def execute(query, context: {})
    MyAppSchema.execute(query, context: context)
  end

  it "returns published posts" do
    result = execute(query, context: { current_user: user })
    posts = result.dig("data", "posts", "nodes")

    expect(posts.length).to eq(2)
    expect(posts.map { |p| p["title"] }).to include(published_post.title)
  end

  it "returns no posts for unauthenticated users" do
    result = execute(query, context: { current_user: nil })
    posts = result.dig("data", "posts", "nodes")

    expect(posts.length).to eq(1)  # Only published
  end
end
```

## Pattern: Mutation specs

```ruby
RSpec.describe "CreatePostMutation" do
  let(:user) { create(:user) }

  let(:mutation) do
    <<~GQL
      mutation CreatePost($title: String!, $body: String) {
        createPost(input: { title: $title, body: $body }) {
          post {
            id
            title
          }
          errors
        }
      }
    GQL
  end

  it "creates a post" do
    result = MyAppSchema.execute(
      mutation,
      variables: { title: "Hello", body: "World" },
      context: { current_user: user }
    )

    data = result.dig("data", "createPost")
    expect(data["errors"]).to be_empty
    expect(data["post"]["title"]).to eq("Hello")
    expect(Post.count).to eq(1)
  end

  it "returns errors for invalid input" do
    result = MyAppSchema.execute(
      mutation,
      variables: { title: "", body: nil },
      context: { current_user: user }
    )

    data = result.dig("data", "createPost")
    expect(data["errors"]).to include("Title can't be blank")
    expect(data["post"]).to be_nil
  end

  it "requires authentication" do
    result = MyAppSchema.execute(
      mutation,
      variables: { title: "Hello" },
      context: { current_user: nil }
    )

    expect(result["errors"].first["message"]).to eq("You must be logged in")
  end
end
```

## Pattern: Helper method for cleaner specs

```ruby
# spec/support/graphql_helpers.rb
module GraphqlHelpers
  def execute_graphql(query, variables: {}, context: {})
    MyAppSchema.execute(
      query,
      variables: variables,
      context: { current_user: nil }.merge(context)
    )
  end

  def graphql_data(result, path = nil)
    data = result["data"]
    path ? data.dig(*path.split(".")) : data
  end

  def graphql_errors(result)
    result["errors"]&.map { |e| e["message"] } || []
  end
end

RSpec.configure do |config|
  config.include GraphqlHelpers
end
```

## Pattern: Request specs for the full stack

```ruby
RSpec.describe "GraphQL endpoint", type: :request do
  let(:user) { create(:user) }

  it "executes a query" do
    post "/graphql",
      params: { query: "{ posts { nodes { id } } }" }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{user.auth_token}"
      }

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)
    expect(data["data"]["posts"]["nodes"]).to be_an(Array)
  end
end
```

## Anti-pattern: Testing through controllers instead of the schema

```ruby
# BAD — couples test to HTTP layer
post "/graphql", params: { query: "..." }

# GOOD for unit testing — test the schema directly
MyAppSchema.execute(query, context: { current_user: user })
```

Use schema execution for unit tests (fast, no HTTP overhead). Use request specs for integration tests (verifies auth, middleware, serialization).
