---
name: turbo-form-submissions
triggers:
  - form_with turbo
  - turbo form
  - form submission turbo
  - unprocessable_entity
  - disable_with
  - form errors turbo
gems:
  - turbo-rails
rails: ">=7.0"
---

# Form Submissions with Turbo

Turbo intercepts all form submissions by default. Understanding the response conventions is critical — getting the status codes wrong is the most common source of Turbo form bugs.

## The golden rule: status codes

| Outcome | Status code | What Turbo does |
|---------|------------|----------------|
| Success | `302`/`303` (redirect) | Follows the redirect, renders the new page |
| Validation failure | `422` (unprocessable entity) | Re-renders the form with errors in place |
| Server error | `500` | Shows the error page |

```ruby
def create
  @post = Post.new(post_params)

  if @post.save
    redirect_to @post, notice: "Created!"  # 302 → Turbo follows
  else
    render :new, status: :unprocessable_entity  # 422 → Turbo re-renders
  end
end
```

## Anti-pattern: Missing status on failed render

```ruby
# BAD — renders with 200, Turbo treats it as success and replaces the page
render :new  # Default is 200 OK

# GOOD — 422 tells Turbo this is a validation failure
render :new, status: :unprocessable_entity
```

This is the single most common Turbo bug. Without `status: :unprocessable_entity`, Turbo thinks the response succeeded and navigates away from the form.

## Pattern: Disabling the submit button during submission

```erb
<%= form_with model: @post do |f| %>
  <%= f.text_field :title %>
  <%= f.submit "Save", data: { turbo_submits_with: "Saving..." } %>
<% end %>
```

`data-turbo-submits-with` replaces the button text during submission and disables it. No JavaScript needed.

## Pattern: Turbo Stream response on form submit

For forms inside Turbo Frames or when you want to update multiple page sections:

```ruby
def create
  @comment = @post.comments.build(comment_params)

  if @comment.save
    respond_to do |format|
      format.turbo_stream  # renders create.turbo_stream.erb
      format.html { redirect_to @post }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

## Pattern: Form inside a Turbo Frame

When a form lives inside a frame, the response must also contain a matching frame.

```erb
<%= turbo_frame_tag "new_comment" do %>
  <%= form_with model: [@post, Comment.new] do |f| %>
    <%= f.text_area :body %>
    <%= f.submit "Post comment" %>
  <% end %>
<% end %>
```

On success, the controller should redirect — Turbo follows the redirect and extracts the matching frame from the response.

On failure, render the form with `status: :unprocessable_entity` — the response replaces only the frame, keeping the rest of the page intact.

## Pattern: File uploads with Turbo

Turbo handles `multipart/form-data` forms (file uploads) automatically. No special configuration needed.

```erb
<%= form_with model: @document, data: { turbo: true } do |f| %>
  <%= f.file_field :attachment %>
  <%= f.submit "Upload" %>
<% end %>
```

For large file uploads, consider using Active Storage direct uploads to avoid tying up the server process.

## Anti-pattern: Using data-turbo="false" on forms to fix bugs

If your form isn't working with Turbo, the fix is almost always to add `status: :unprocessable_entity` to your failed render — not to disable Turbo on the form.

```erb
<%# BAD — disabling Turbo because the form doesn't work %>
<%= form_with model: @post, data: { turbo: false } do |f| %>

<%# GOOD — fix the controller instead %>
<%# In the controller: render :new, status: :unprocessable_entity %>
```
