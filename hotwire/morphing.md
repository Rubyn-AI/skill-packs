---
name: turbo-morphing
triggers:
  - morph
  - morphing
  - turbo 8
  - idiomorph
  - data-turbo-permanent
  - page refresh morph
gems:
  - turbo-rails
rails: ">=7.2"
---

# Turbo Morphing (Turbo 8)

Turbo 8 introduced morphing as an alternative to full-page replacement. Instead of swapping the entire `<body>`, morphing diffs the old and new DOM and applies surgical updates — preserving scroll position, focus state, CSS transitions, and form inputs.

## Enabling morphing

Morphing is opt-in per page via a `<meta>` tag.

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <meta name="turbo-refresh-method" content="morph">
  <meta name="turbo-refresh-scroll" content="preserve">
  <%= yield :head %>
</head>
```

- `turbo-refresh-method="morph"` — use morphing instead of replacement
- `turbo-refresh-scroll="preserve"` — keep scroll position on page refresh

## Pattern: Stable DOM IDs for morphing

Morphing matches old and new elements by `id`. Without stable IDs, the differ can't pair elements and falls back to replacement (losing state).

```erb
<%# BAD — no IDs, morphing can't match elements %>
<% @posts.each do |post| %>
  <div class="post">
    <h2><%= post.title %></h2>
  </div>
<% end %>

<%# GOOD — stable IDs via dom_id %>
<% @posts.each do |post| %>
  <div id="<%= dom_id(post) %>">
    <h2><%= post.title %></h2>
  </div>
<% end %>
```

Rule: every element that contains state (form inputs, expanded sections, scroll containers) must have a stable `id` attribute.

## Pattern: Turbo Stream morph action

The `morph` stream action surgically updates a target element without replacing it.

```ruby
# Controller or model callback
turbo_stream.morph(dom_id(@post), partial: "posts/post", locals: { post: @post })
```

```erb
<%# In a turbo_stream.erb template %>
<%= turbo_stream.morph dom_id(@post) do %>
  <%= render @post %>
<% end %>
```

This is preferable to `replace` when the target contains form inputs, animations, or Stimulus controllers with state — morphing preserves them.

## Pattern: Excluding elements from morphing

`data-turbo-permanent` prevents an element from being morphed. The element persists across navigations.

```erb
<audio id="player" data-turbo-permanent>
  <source src="<%= @track.url %>">
</audio>
```

Use for: media players, chat widgets, drag-and-drop state, canvas elements, anything with complex client-side state.

## Anti-pattern: Missing IDs on list items

```erb
<%# BAD — morphing reorders the entire list on every update %>
<ul id="notifications">
  <% @notifications.each do |n| %>
    <li><%= n.message %></li>
  <% end %>
</ul>

<%# GOOD — each item has a stable ID %>
<ul id="notifications">
  <% @notifications.each do |n| %>
    <li id="<%= dom_id(n) %>"><%= n.message %></li>
  <% end %>
</ul>
```

## Pattern: Broadcasts with morphing

Combine `broadcast_render_later_to` with morph for efficient real-time updates.

```ruby
class Comment < ApplicationRecord
  after_create_commit -> {
    broadcast_render_later_to(
      post,
      partial: "posts/post",
      locals: { post: post }
    )
  }
end
```

The subscriber page morphs the post partial, adding the new comment without losing scroll or input state elsewhere on the page.

## When to use morph vs replace

| Scenario | Use |
|---------|-----|
| Simple content swap, no client state | `replace` |
| Form on page, preserve input values | `morph` |
| Stimulus controllers with state | `morph` |
| CSS transitions in progress | `morph` |
| Scroll position matters | `morph` + `preserve` |
| Element has event listeners | `morph` (preserves them) |
