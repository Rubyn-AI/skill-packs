---
name: turbo-native-strada
triggers:
  - turbo native
  - strada
  - bridge component
  - native app
  - ios turbo
  - android turbo
  - path configuration
gems:
  - turbo-rails
rails: ">=7.0"
---

# Turbo Native & Strada

Turbo Native wraps your Rails app in a native iOS/Android shell. Strada bridges web and native UI components so certain elements render natively while the content stays server-rendered.

## Pattern: Path configuration for native navigation

```json
{
  "settings": {
    "tabs": [
      { "title": "Home", "path": "/", "icon": "house" },
      { "title": "Tasks", "path": "/tasks", "icon": "checklist" }
    ]
  },
  "rules": [
    { "patterns": ["/new$", "/edit$"], "properties": { "presentation": "modal" } },
    { "patterns": ["/sign_in"], "properties": { "presentation": "replace_root" } },
    { "patterns": [".*"], "properties": { "presentation": "push" } }
  ]
}
```

Path configuration controls how the native app presents each URL — push, modal, or replace. It lives on the server so you can update navigation without an app store release.

## Pattern: Strada bridge components

Bridge components let you render native UI for specific web elements.

```erb
<%# A form button that renders natively on mobile %>
<%= form_with model: @post do |f| %>
  <%= f.text_field :title %>
  <button type="submit"
    data-bridge--form-submit-title-value="Save Post"
    data-controller="bridge--form-submit">
    Save Post
  </button>
<% end %>
```

The web version shows a regular button. On native, Strada intercepts the bridge component and renders a native button in the toolbar instead.

## Pattern: Detecting native vs web requests

```ruby
# app/controllers/application_controller.rb
def turbo_native_app?
  request.user_agent.to_s.match?(/Turbo Native/)
end
helper_method :turbo_native_app?
```

```erb
<% if turbo_native_app? %>
  <%# Native-specific UI (no browser chrome, native nav) %>
<% else %>
  <%# Full web UI with header, footer, etc. %>
<% end %>
```

## Anti-pattern: Building a separate API for the mobile app

Turbo Native doesn't need a JSON API. The native app renders your existing HTML views. Don't build a parallel API — serve the same views with conditional native adjustments.
