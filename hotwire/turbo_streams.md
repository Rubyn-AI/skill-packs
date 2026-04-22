---
name: turbo-streams
triggers:
  - turbo stream
  - turbo_stream
  - broadcast
  - stream action
  - append
  - prepend
  - replace
  - remove
  - update
  - after
  - before
  - morph
  - refresh
gems:
  - turbo-rails
rails: ">=7.0"
---

# Turbo Streams

Turbo Streams deliver page changes as a set of CRUD-like actions. They can arrive via HTTP responses (inline) or WebSocket (broadcast). Each action targets a DOM element by ID and manipulates it.

## The 8 built-in stream actions

| Action | What it does |
|--------|-------------|
| `append` | Adds content to the end of the target element |
| `prepend` | Adds content to the beginning |
| `replace` | Replaces the entire target element (including the element itself) |
| `update` | Replaces the inner HTML of the target (keeps the element) |
| `remove` | Removes the target element |
| `before` | Inserts content before the target element |
| `after` | Inserts content after the target element |
| `morph` | Morphs the target element (Rails 8+ / Turbo 8) |

## Pattern: Inline streams from controller actions

Return Turbo Stream responses for non-GET requests. The controller responds with `turbo_stream` format.

```ruby
# app/controllers/comments_controller.rb
def create
  @comment = @post.comments.create!(comment_params)

  respond_to do |format|
    format.turbo_stream  # renders create.turbo_stream.erb
    format.html { redirect_to @post }
  end
end

def destroy
  @comment = Comment.find(params[:id])
  @comment.destroy!

  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@comment)) }
    format.html { redirect_to @comment.post }
  end
end
```

```erb
<%# app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.append "comments" do %>
  <%= render @comment %>
<% end %>

<%= turbo_stream.update "comment_count" do %>
  <%= @post.comments.count %> comments
<% end %>

<%= turbo_stream.replace "comment_form" do %>
  <%= render "comments/form", comment: Comment.new, post: @post %>
<% end %>
```

Multiple stream actions in a single response is the power move — update several parts of the page at once.

## Pattern: Broadcast streams via WebSocket

Push updates to all connected clients when a model changes. Requires ActionCable.

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :room

  after_create_commit -> {
    broadcast_append_to room, target: "messages", partial: "messages/message"
  }

  after_update_commit -> {
    broadcast_replace_to room, target: dom_id(self), partial: "messages/message"
  }

  after_destroy_commit -> {
    broadcast_remove_to room, target: dom_id(self)
  }
end
```

```erb
<%# app/views/rooms/show.html.erb %>
<%= turbo_stream_from @room %>

<div id="messages">
  <%= render @room.messages %>
</div>
```

`turbo_stream_from @room` subscribes to the ActionCable channel. The callbacks push stream actions to all subscribers.

## Pattern: Broadcast with explicit channel targeting

For more control, specify the stream name and partial.

```ruby
after_create_commit -> {
  broadcast_append_to(
    "project_#{project_id}_tasks",
    target: "task_list",
    partial: "tasks/task",
    locals: { task: self }
  )
}
```

## Anti-pattern: Using streams for GET requests

Turbo Streams are for mutations (create, update, delete). Never return `turbo_stream` format for a GET request — it confuses browser history and breaks the back button.

```ruby
# BAD — stream response on a GET
def index
  respond_to do |format|
    format.turbo_stream  # Don't do this
    format.html
  end
end

# GOOD — use Turbo Frames for GET-based partial updates
# Just render HTML and let the frame extract what it needs
def index
  @posts = Post.all
  render :index
end
```

## Anti-pattern: Missing dom_id on target elements

Stream actions target elements by DOM ID. If the target element doesn't have the expected ID, the action silently fails.

```erb
<%# BAD — no ID on the container %>
<div class="comments">
  <%= render @comments %>
</div>

<%# GOOD — ID matches the stream target %>
<div id="comments">
  <%= render @comments %>
</div>

<%# ALSO GOOD — use dom_id on each item for replace/remove %>
<%= render @comments %>
<%# Each comment partial should wrap in: %>
<%= tag.div id: dom_id(comment) do %>
  ...
<% end %>
```

## Pattern: Conditional stream vs HTML response

Always provide an HTML fallback for clients without JavaScript or Turbo.

```ruby
def create
  @task = @project.tasks.build(task_params)

  if @task.save
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @project, notice: "Task created" }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

## Pattern: Flash messages via streams

Append flash notifications to a shared container.

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.append "comments" do %>
  <%= render @comment %>
<% end %>

<%= turbo_stream.update "flash" do %>
  <p class="notice">Comment posted!</p>
<% end %>
```

```erb
<%# application.html.erb %>
<div id="flash">
  <% flash.each do |type, message| %>
    <p class="<%= type %>"><%= message %></p>
  <% end %>
</div>
```

## Stream templates for complex actions

For actions involving multiple targets, use `.turbo_stream.erb` templates. For simple single-target actions, inline the response in the controller.

Inline (simple):
```ruby
format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@comment)) }
```

Template (complex):
```ruby
format.turbo_stream  # renders destroy.turbo_stream.erb with multiple actions
```
