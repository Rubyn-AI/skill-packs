---
name: testing-turbo
triggers:
  - test turbo
  - system test turbo
  - assert_turbo_stream
  - capybara turbo
  - turbo test
  - request spec turbo
gems:
  - turbo-rails
rails: ">=7.0"
---

# Testing Turbo

## Request specs for Turbo Stream responses

```ruby
# spec/requests/comments_spec.rb
RSpec.describe "Comments", type: :request do
  describe "POST /posts/:post_id/comments" do
    let(:post_record) { create(:post) }

    it "returns a turbo stream response" do
      post post_comments_path(post_record),
        params: { comment: { body: "Great post!" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="append" target="comments"')
    end

    it "returns 422 with errors for invalid input" do
      post post_comments_path(post_record),
        params: { comment: { body: "" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

The key is sending the `Accept: text/vnd.turbo-stream.html` header. Without it, the controller serves the HTML fallback.

## System tests with Turbo

Capybara system tests work with Turbo out of the box — the JavaScript driver (Selenium, Cuprite, Playwright) processes Turbo navigations naturally.

```ruby
# spec/system/comments_spec.rb
RSpec.describe "Adding comments", type: :system do
  it "adds a comment without full page reload" do
    post = create(:post)
    visit post_path(post)

    fill_in "Comment", with: "Great post!"
    click_button "Post comment"

    # The comment appears via Turbo Stream — no page reload
    expect(page).to have_text("Great post!")

    # Verify the URL didn't change (no full navigation)
    expect(page).to have_current_path(post_path(post))
  end

  it "shows inline errors on invalid submission" do
    post = create(:post)
    visit post_path(post)

    click_button "Post comment"  # Empty body

    expect(page).to have_text("Body can't be blank")
    # Form is still visible (re-rendered via 422, not redirected)
  end
end
```

## Anti-pattern: Testing Turbo behavior with controller tests

Controller tests bypass the middleware stack and don't process Turbo. Use request specs or system tests instead.

```ruby
# BAD — controller tests don't test Turbo behavior
RSpec.describe CommentsController, type: :controller do
  it "does turbo stuff" do  # This test proves nothing about Turbo
    post :create, params: { comment: { body: "hi" } }
  end
end

# GOOD — request specs with proper Accept header
RSpec.describe "Comments", type: :request do
  it "returns turbo stream" do
    post comments_path, params: { ... },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end
end
```

## Testing broadcasts

```ruby
# spec/models/message_spec.rb
RSpec.describe Message, type: :model do
  it "broadcasts on create" do
    room = create(:room)

    expect {
      create(:message, room: room)
    }.to have_broadcasted_to(room)
      .with_stream_for(room)
      .from_channel(Turbo::StreamsChannel)
  end
end
```

Or with `assert_broadcasts` in Minitest:

```ruby
assert_broadcasts("rooms:#{room.id}", 1) do
  Message.create!(room: room, body: "Hello")
end
```

## Pattern: Waiting for Turbo in system tests

Turbo navigations are asynchronous. Capybara's built-in waiting handles most cases, but for broadcasts you may need explicit waits.

```ruby
it "receives a broadcast message" do
  room = create(:room)
  visit room_path(room)

  # Simulate another user sending a message
  Message.create!(room: room, body: "Hello from another user")

  # Capybara waits up to Capybara.default_max_wait_time for this
  expect(page).to have_text("Hello from another user")
end
```

If broadcasts are slow in tests, verify your test cable adapter:

```yaml
# config/cable.yml
test:
  adapter: async  # Use async, not test, for system tests with broadcasts
```

The `test` adapter doesn't deliver broadcasts. Use `async` for system tests that verify real-time features.

## Testing Turbo Frame navigation

```ruby
it "loads content in a frame" do
  visit posts_path

  within_frame "post_#{post.id}" do  # NOT iframe — Turbo Frame
    click_link "Edit"
    fill_in "Title", with: "Updated"
    click_button "Save"
    expect(page).to have_text("Updated")
  end
end
```

Note: `within_frame` is for iframes. For Turbo Frames, just scope with `within`:

```ruby
within "##{dom_id(post)}" do
  click_link "Edit"
  # Turbo replaces this frame's content
  expect(page).to have_field("Title")
end
```
