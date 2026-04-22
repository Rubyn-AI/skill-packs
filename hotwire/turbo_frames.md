---
name: turbo-frames
triggers:
  - turbo frame
  - turbo_frame_tag
  - lazy loading frame
  - frame navigation
  - dom_id
  - inline editing
  - partial page update
gems:
  - turbo-rails
rails: ">=7.0"
---

# Turbo Frames

Turbo Frames scope navigation to a section of the page. Links and forms inside a frame replace only that frame's content, not the full page.

## Pattern: Inline editing

The most common frame pattern. Show mode and edit mode share the same frame ID so Turbo swaps them automatically.

```erb
<%# show.html.erb — the default view %>
<%= turbo_frame_tag dom_id(post) do %>
  <h2><%= post.title %></h2>
  <p><%= post.body %></p>
  <%= link_to "Edit", edit_post_path(post) %>
<% end %>

<%# edit.html.erb — returned by the edit action %>
<%= turbo_frame_tag dom_id(post) do %>
  <%= form_with model: post do |f| %>
    <%= f.text_field :title %>
    <%= f.text_area :body %>
    <%= f.submit "Save" %>
    <%= link_to "Cancel", post_path(post) %>
  <% end %>
<% end %>
```

The controller needs no special handling. Turbo extracts the matching frame from the full HTML response.

## Pattern: Lazy-loaded content

Load expensive content after the page renders. The frame fetches its `src` URL on appearance.

```erb
<%= turbo_frame_tag "dashboard_stats", src: stats_path, loading: :lazy do %>
  <p>Loading stats...</p>
<% end %>
```

The `loading: :lazy` defers the request until the frame enters the viewport. Without it, the request fires immediately after page load.

## Pattern: Breaking out of a frame

Links inside a frame are scoped to that frame by default. Use `data-turbo-frame` to target a different frame or the whole page.

```erb
<%= turbo_frame_tag dom_id(post) do %>
  <h2><%= post.title %></h2>
  <%# This link replaces the WHOLE page, not just the frame %>
  <%= link_to "View full post", post_path(post), data: { turbo_frame: "_top" } %>
<% end %>
```

Target values:
- `_top` — replace the entire page (break out of the frame)
- `_self` — replace the current frame (default)
- Any frame ID — target a specific frame elsewhere on the page

## Anti-pattern: Frame ID mismatch

If the response doesn't contain a `turbo_frame_tag` with a matching ID, Turbo shows nothing and logs a console error. This is the most common Turbo Frames bug.

```erb
<%# Request expects a frame with id="post_42" but response has: %>
<%= turbo_frame_tag "edit_form" do %>  <%# WRONG — ID doesn't match %>
  ...
<% end %>

<%# Fix: use the same dom_id helper %>
<%= turbo_frame_tag dom_id(@post) do %>  <%# Correct — matches request %>
  ...
<% end %>
```

## Anti-pattern: Wrapping entire pages in frames

Frames are for partial page updates. Wrapping your entire layout in a frame defeats the purpose and breaks browser history, scroll position, and accessibility.

```erb
<%# BAD — the whole page is a frame %>
<%= turbo_frame_tag "main_content" do %>
  <%= yield %>
<% end %>

<%# GOOD — only the dynamic section is framed %>
<div class="layout">
  <nav>...</nav>
  <%= turbo_frame_tag "content" do %>
    <%= yield %>
  <% end %>
  <footer>...</footer>
</div>
```

## Pattern: Frame with a custom src for pagination

Frames can load paginated content by changing their `src` attribute.

```erb
<%= turbo_frame_tag "posts_list" do %>
  <%= render @posts %>

  <% if @posts.next_page %>
    <%= turbo_frame_tag "posts_list", src: posts_path(page: @posts.next_page), loading: :lazy do %>
      <p>Loading more...</p>
    <% end %>
  <% end %>
<% end %>
```

## Controller responses

Frames work with standard Rails controller responses. No special format or `respond_to` block needed for frame requests — Turbo extracts the matching frame from the full HTML.

For non-GET requests (create, update, delete), always redirect on success and render on failure:

```ruby
def update
  @post = Post.find(params[:id])
  if @post.update(post_params)
    redirect_to @post  # Turbo follows the redirect and extracts the frame
  else
    render :edit, status: :unprocessable_entity  # 422 tells Turbo to render errors
  end
end
```

The `status: :unprocessable_entity` is critical. Without it, Turbo treats the response as a success and doesn't re-render the form with errors.
