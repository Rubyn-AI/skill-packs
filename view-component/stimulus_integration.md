---
name: viewcomponent-stimulus
triggers:
  - component stimulus
  - viewcomponent javascript
  - component controller
  - component data-controller
  - component with stimulus
gems:
  - view_component
  - stimulus-rails
rails: ">=7.0"
---

# ViewComponent + Stimulus Integration

Components that need interactivity pair with Stimulus controllers. The component renders the HTML and data attributes; the Stimulus controller adds behavior.

## Pattern: Component with a dedicated Stimulus controller

```ruby
# app/components/dropdown_component.rb
class DropdownComponent < ViewComponent::Base
  def initialize(label:, items:)
    @label = label
    @items = items
  end
end
```

```erb
<%# app/components/dropdown_component.html.erb %>
<div data-controller="dropdown" class="dropdown">
  <button data-action="click->dropdown#toggle" data-dropdown-target="button">
    <%= @label %>
  </button>

  <ul data-dropdown-target="menu" class="dropdown-menu hidden">
    <% @items.each do |item| %>
      <li>
        <%= link_to item[:label], item[:url], data: { action: "click->dropdown#select" } %>
      </li>
    <% end %>
  </ul>
</div>
```

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  select() {
    this.menuTarget.classList.add("hidden")
  }

  // Close when clicking outside
  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    document.addEventListener("click", this.close.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.close.bind(this))
  }
}
```

## Pattern: Passing component data to Stimulus via values

```ruby
class ChartComponent < ViewComponent::Base
  def initialize(data:, type: "bar")
    @data = data
    @type = type
  end
end
```

```erb
<div data-controller="chart"
     data-chart-data-value="<%= @data.to_json %>"
     data-chart-type-value="<%= @type %>">
  <canvas data-chart-target="canvas"></canvas>
</div>
```

The component handles the Ruby-to-HTML bridge. Stimulus handles the JavaScript. Clean separation.

## Pattern: Reusable Stimulus controller across components

Multiple components can share the same Stimulus controller if they follow the same DOM contract:

```erb
<%# toggle_component.html.erb %>
<div data-controller="toggle">
  <button data-action="toggle#toggle">Show/Hide</button>
  <div data-toggle-target="content"><%= content %></div>
</div>

<%# accordion_item_component.html.erb %>
<div data-controller="toggle" data-toggle-open-value="false">
  <h3 data-action="click->toggle#toggle"><%= @title %></h3>
  <div data-toggle-target="content"><%= content %></div>
</div>
```

One `toggle_controller.js` powers both components.

## Anti-pattern: Inline JavaScript in components

```erb
<%# BAD — JavaScript in the template %>
<div onclick="this.querySelector('.menu').classList.toggle('hidden')">
  ...
</div>

<%# GOOD — Stimulus controller %>
<div data-controller="dropdown" data-action="click->dropdown#toggle">
  ...
</div>
```

Keep JavaScript in Stimulus controllers. Components are HTML and Ruby.

## Anti-pattern: Component importing its own JS

```ruby
# BAD — components shouldn't manage their own JS bundles
class DropdownComponent < ViewComponent::Base
  def before_render
    content_for(:head) { javascript_include_tag("dropdown") }
  end
end
```

Stimulus auto-loads controllers from `app/javascript/controllers/`. The component just needs to reference the correct `data-controller` name. No manual script loading.
