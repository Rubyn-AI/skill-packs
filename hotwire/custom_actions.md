---
name: turbo-custom-actions
triggers:
  - custom turbo action
  - turbo:before-stream-render
  - StreamActions
  - custom stream action
gems:
  - turbo-rails
rails: ">=7.0"
---

# Custom Turbo Stream Actions

Beyond the 8 built-in actions, you can define custom stream actions for specialized DOM manipulation.

## Pattern: Define a custom action

```javascript
// app/javascript/application.js
import { StreamActions } from "@hotwired/turbo"

// Add a "highlight" action that adds a CSS class temporarily
StreamActions.highlight = function() {
  const target = this.targetElements[0]
  if (target) {
    target.classList.add("highlight")
    setTimeout(() => target.classList.remove("highlight"), 2000)
  }
}

// Add a "redirect" action
StreamActions.redirect = function() {
  Turbo.visit(this.getAttribute("url"))
}

// Add a "console_log" action (useful for debugging)
StreamActions.console_log = function() {
  console.log(this.templateContent.textContent)
}
```

## Pattern: Using custom actions from the server

```erb
<%# In a turbo_stream.erb template %>
<turbo-stream action="highlight" target="<%= dom_id(@post) %>">
</turbo-stream>

<turbo-stream action="redirect" url="<%= posts_path %>">
</turbo-stream>
```

Or from Ruby:

```ruby
turbo_stream.action(:highlight, dom_id(@post))
```

## Pattern: Custom action with template content

```javascript
StreamActions.notification = function() {
  const html = this.templateContent
  document.getElementById("notifications").appendChild(html.cloneNode(true))
  // Auto-dismiss after 5 seconds
  setTimeout(() => html.remove(), 5000)
}
```

```erb
<turbo-stream action="notification" target="notifications">
  <template>
    <div class="toast toast-success">
      <%= @message %>
    </div>
  </template>
</turbo-stream>
```

## Anti-pattern: Overusing custom actions

Custom actions add JavaScript that must be loaded and maintained. Before creating one, check if a built-in action with a well-structured partial would work.

```erb
<%# Often better than a custom "notification" action: %>
<%= turbo_stream.append "notifications" do %>
  <%= render "shared/toast", message: "Saved!", type: :success %>
<% end %>
```

Reserve custom actions for behavior that genuinely can't be expressed as append/replace/update with the right partial.
