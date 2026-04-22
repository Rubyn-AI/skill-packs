---
name: turbo-lazy-loading
triggers:
  - lazy load frame
  - loading lazy
  - deferred frame
  - skeleton loading
  - frame src
gems:
  - turbo-rails
rails: ">=7.0"
---

# Lazy-Loaded Turbo Frames

Frames with a `src` attribute fetch their content separately from the main page load. Add `loading: :lazy` to defer until the frame enters the viewport.

## Pattern: Deferred dashboard widgets

```erb
<div class="dashboard-grid">
  <%= turbo_frame_tag "recent_orders", src: dashboard_orders_path, loading: :lazy do %>
    <%= render "shared/skeleton_card" %>
  <% end %>

  <%= turbo_frame_tag "revenue_chart", src: dashboard_revenue_path, loading: :lazy do %>
    <%= render "shared/skeleton_card" %>
  <% end %>

  <%= turbo_frame_tag "notifications", src: dashboard_notifications_path, loading: :lazy do %>
    <%= render "shared/skeleton_card" %>
  <% end %>
</div>
```

The block content is the placeholder shown while loading. Use skeleton screens, spinners, or simple "Loading..." text.

## Pattern: Controller for frame endpoints

Frame endpoints render the same partial as the full page but Turbo extracts only the matching frame.

```ruby
# app/controllers/dashboard_controller.rb
def orders
  @recent_orders = Order.recent.limit(10)
  # Renders the full page, Turbo extracts the "recent_orders" frame
end
```

Or for performance, render just the frame content with `layout: false`:

```ruby
def orders
  @recent_orders = Order.recent.limit(10)
  render partial: "dashboard/orders_widget", layout: false
end
```

## Anti-pattern: Eager loading everything

```erb
<%# BAD — all frames load immediately, defeating the purpose %>
<%= turbo_frame_tag "stats", src: stats_path do %>
  Loading...
<% end %>

<%# GOOD — lazy loads when scrolled into view %>
<%= turbo_frame_tag "stats", src: stats_path, loading: :lazy do %>
  Loading...
<% end %>
```

Without `loading: :lazy`, the frame fetches its `src` immediately after the page loads. For below-the-fold content, always use lazy loading.

## Pattern: Refresh interval with Stimulus

Turbo Frames don't have built-in auto-refresh. Combine with a Stimulus controller:

```javascript
// auto_refresh_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: { type: Number, default: 30000 } }

  connect() {
    this.timer = setInterval(() => {
      this.element.reload()  // Turbo Frame API
    }, this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
```

```erb
<%= turbo_frame_tag "live_stats",
    src: stats_path,
    data: { controller: "auto-refresh", auto_refresh_interval_value: 15000 } do %>
  Loading...
<% end %>
```
