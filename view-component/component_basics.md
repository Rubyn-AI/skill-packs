---
name: viewcomponent-basics
triggers:
  - view component
  - ViewComponent
  - component class
  - render component
  - ApplicationComponent
gems:
  - view_component
rails: ">=7.0"
---

# ViewComponent Basics

ViewComponent encapsulates a chunk of view logic into a Ruby class with a template. Components are testable in isolation, faster than partials, and enforce a clear interface.

## Pattern: Basic component

```ruby
# app/components/alert_component.rb
class AlertComponent < ViewComponent::Base
  def initialize(type: :info, dismissible: false)
    @type = type
    @dismissible = dismissible
  end

  private

  attr_reader :type, :dismissible

  def css_class
    case type
    when :info    then "alert-info"
    when :success then "alert-success"
    when :warning then "alert-warning"
    when :error   then "alert-error"
    end
  end
end
```

```erb
<%# app/components/alert_component.html.erb %>
<div class="alert <%= css_class %>" role="alert">
  <%= content %>
  <% if dismissible %>
    <button class="alert-dismiss" aria-label="Dismiss">&times;</button>
  <% end %>
</div>
```

```erb
<%# Usage in a view %>
<%= render AlertComponent.new(type: :success, dismissible: true) do %>
  Your changes have been saved.
<% end %>
```

## Pattern: Component with `before_render`

```ruby
class BreadcrumbComponent < ViewComponent::Base
  def initialize(items:)
    @items = items
  end

  def before_render
    # Access helpers, request context, etc. here — not in initialize
    @current_path = request.path
  end

  def render?
    # Don't render if only one breadcrumb
    @items.length > 1
  end
end
```

`render?` lets the component decide whether to render at all. Cleaner than wrapping `<% if ... %>` in the parent view.

## Anti-pattern: Business logic in components

```ruby
# BAD — component queries the database
class UserListComponent < ViewComponent::Base
  def initialize
    @users = User.active.order(:name)  # DB query in a component!
  end
end

# GOOD — pass data in
class UserListComponent < ViewComponent::Base
  def initialize(users:)
    @users = users
  end
end

# Controller prepares the data
def index
  @users = User.active.order(:name)
  # render is implicit — the view uses the component
end
```

Components receive data. Controllers query data. Don't mix them.

## Anti-pattern: Using instance variables without initialization

```ruby
# BAD — relies on ERB's implicit instance variable behavior
class CardComponent < ViewComponent::Base
  # No initialize, template uses @title directly
end

# GOOD — explicit interface
class CardComponent < ViewComponent::Base
  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end
end
```

Always declare the component's interface in `initialize`. This makes the component self-documenting and enables IDE autocompletion.

## Inline components (no template file)

```ruby
class BadgeComponent < ViewComponent::Base
  erb_template <<~ERB
    <span class="badge badge-<%= @color %>"><%= content %></span>
  ERB

  def initialize(color: "gray")
    @color = color
  end
end
```

Good for tiny components where a separate `.erb` file is overkill.
