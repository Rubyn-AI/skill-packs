---
name: viewcomponent-patterns
triggers:
  - component pattern
  - collection component
  - component helper
  - component design pattern
  - conditional component
  - component composition
gems:
  - view_component
rails: ">=7.0"
---

# ViewComponent Patterns

## Pattern: Collection rendering

```ruby
class PostListComponent < ViewComponent::Base
  renders_many :posts, PostCardComponent

  def initialize(empty_message: "No posts found.")
    @empty_message = empty_message
  end

  def render?
    true  # Always render — shows empty state
  end
end
```

```erb
<%# post_list_component.html.erb %>
<div class="post-list">
  <% if posts.any? %>
    <% posts.each do |post| %>
      <%= post %>
    <% end %>
  <% else %>
    <p class="empty-state"><%= @empty_message %></p>
  <% end %>
</div>
```

```erb
<%# Usage in view %>
<%= render PostListComponent.new do |list| %>
  <% @posts.each do |post| %>
    <% list.with_post(post: post) %>
  <% end %>
<% end %>
```

## Pattern: Wrapper component (decorator)

```ruby
class PageSectionComponent < ViewComponent::Base
  def initialize(title:, id: nil, collapsible: false)
    @title = title
    @id = id || title.parameterize
    @collapsible = collapsible
  end
end
```

```erb
<section id="<%= @id %>" class="page-section">
  <h2 class="section-title"><%= @title %></h2>
  <div class="section-body">
    <%= content %>
  </div>
</section>
```

Wrapper components standardize layout patterns across your app without copy-pasting HTML structure.

## Pattern: Component with helpers

```ruby
class TimeAgoComponent < ViewComponent::Base
  include ActionView::Helpers::DateHelper

  def initialize(time:)
    @time = time
  end

  def call
    tag.time(time_ago_in_words(@time) + " ago",
             datetime: @time.iso8601,
             title: @time.strftime("%B %d, %Y at %I:%M %p"))
  end
end
```

Inline rendering with `call` instead of a template — good for single-element components.

## Pattern: Conditional rendering with render?

```ruby
class FlashComponent < ViewComponent::Base
  def initialize(flash:)
    @flash = flash
  end

  def render?
    @flash.any?
  end
end
```

`render?` prevents the component from rendering at all (no empty div, no wrapper). Cleaner than `if` in the parent view.

## Pattern: Component with default content

```ruby
class EmptyStateComponent < ViewComponent::Base
  def initialize(title:, icon: "inbox")
    @title = title
    @icon = icon
  end

  def call
    tag.div(class: "empty-state") do
      safe_join([
        tag.span(class: "icon icon-#{@icon}"),
        tag.h3(@title),
        (content.present? ? tag.div(content, class: "empty-body") : tag.p("Nothing here yet."))
      ])
    end
  end
end
```

```erb
<%# With custom content %>
<%= render EmptyStateComponent.new(title: "No results") do %>
  Try adjusting your search filters.
<% end %>

<%# With default content %>
<%= render EmptyStateComponent.new(title: "No results") %>
```

## Anti-pattern: God components

```ruby
# BAD — one component tries to handle every case
class CardComponent < ViewComponent::Base
  def initialize(title:, subtitle: nil, image: nil, badge: nil,
                 footer: nil, actions: [], type: :default, size: :md,
                 horizontal: false, clickable: false, href: nil, ...)
    # 15 parameters, 500-line template
  end
end

# GOOD — compose smaller components
<%= render CardComponent.new do |card| %>
  <% card.with_header { render CardHeaderComponent.new(title: "Post") } %>
  <% card.with_media { render ImageComponent.new(src: @post.image) } %>
  <% card.with_footer { render CardActionsComponent.new(post: @post) } %>
<% end %>
```

If your component has more than 5-6 parameters, it needs slots or decomposition.
