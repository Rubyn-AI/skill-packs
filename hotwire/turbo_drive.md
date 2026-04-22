---
name: turbo-drive
triggers:
  - turbo drive
  - page navigation
  - turbo visit
  - turbo:load
  - prefetch
  - progress bar
  - data-turbo
  - disable turbo
gems:
  - turbo-rails
rails: ">=7.0"
---

# Turbo Drive

Turbo Drive intercepts link clicks and form submissions, fetches the response via AJAX, and swaps the `<body>` — turning every page navigation into a fast, SPA-like experience with zero JavaScript.

## How it works

1. User clicks a link
2. Turbo intercepts the click, prevents the browser's default navigation
3. Turbo fetches the URL via `fetch()`
4. Turbo swaps the `<body>` of the current page with the `<body>` from the response
5. Turbo merges the `<head>` (updates title, adds new stylesheets/scripts)
6. History is updated via `pushState`

This happens automatically for all `<a>` tags and `<form>` submissions. No opt-in required.

## Pattern: Disabling Turbo Drive for specific links

Some links should trigger a full page reload (external links, file downloads, OAuth redirects).

```erb
<%# Disable Turbo for a single link %>
<%= link_to "Download PDF", report_path(@report, format: :pdf), data: { turbo: false } %>

<%# Disable Turbo for all links in a section %>
<div data-turbo="false">
  <%= link_to "External site", "https://example.com" %>
  <%= link_to "OAuth login", auth_path %>
</div>

<%# Re-enable inside a disabled section %>
<div data-turbo="false">
  <nav data-turbo="true">
    <%= link_to "Home", root_path %>  <%# This one uses Turbo %>
  </nav>
</div>
```

## Pattern: Prefetching for instant navigation

Turbo prefetches links on hover (after a brief delay) so the response is ready when the user clicks.

```erb
<%# Prefetching is ON by default in Turbo 8. Disable per-link if needed: %>
<%= link_to "Slow page", slow_path, data: { turbo_prefetch: false } %>

<%# Disable prefetching for the whole page in the <head>: %>
<meta name="turbo-prefetch" content="false">
```

## Pattern: Progress bar customization

Turbo shows a thin progress bar at the top during navigation. Customize its appearance and delay.

```css
/* The progress bar element */
.turbo-progress-bar {
  height: 3px;
  background-color: #CC342D; /* Ruby red */
}
```

```javascript
// Delay before showing the bar (default: 500ms)
// Set in application.js
Turbo.setProgressBarDelay(200)
```

## Pattern: Permanent elements

Elements with `data-turbo-permanent` persist across navigations. Useful for audio/video players, chat widgets, or anything with client-side state.

```erb
<audio id="player" data-turbo-permanent>
  <source src="<%= @track.url %>">
</audio>
```

The element must have a unique `id`. On navigation, Turbo transfers the element from the old page to the new page without re-rendering it.

## Anti-pattern: Third-party scripts breaking on navigation

Scripts loaded via `<script>` tags in the body don't re-execute on Turbo navigations. This breaks analytics, chat widgets, and other third-party embeds.

```erb
<%# BAD — this script runs on first page load but not on Turbo navigations %>
<script>
  analytics.track("page_view")
</script>

<%# GOOD — use turbo:load event %>
<script>
  document.addEventListener("turbo:load", () => {
    analytics.track("page_view")
  })
</script>
```

Move third-party script initialization to a `turbo:load` listener or a Stimulus controller's `connect()` callback.

## Anti-pattern: Using DOMContentLoaded

`DOMContentLoaded` fires once on initial page load and never again on Turbo navigations.

```javascript
// BAD — only runs once
document.addEventListener("DOMContentLoaded", () => {
  initializeWidgets()
})

// GOOD — runs on every navigation
document.addEventListener("turbo:load", () => {
  initializeWidgets()
})

// BEST — use Stimulus controllers instead of manual initialization
// Stimulus connect() fires every time the element enters the DOM
```

## Key Turbo events

| Event | When it fires |
|-------|--------------|
| `turbo:click` | A Turbo-eligible link is clicked |
| `turbo:before-visit` | Before a visit starts (cancelable) |
| `turbo:visit` | Visit starts |
| `turbo:before-render` | Before the body is swapped |
| `turbo:render` | After the body is swapped |
| `turbo:load` | After the page is fully loaded (fires on every navigation) |
| `turbo:before-fetch-request` | Before a fetch (add headers here) |
| `turbo:submit-start` | Form submission begins |
| `turbo:submit-end` | Form submission completes |

## Pattern: Adding custom headers to Turbo requests

```javascript
document.addEventListener("turbo:before-fetch-request", (event) => {
  event.detail.fetchOptions.headers["X-Custom-Header"] = "value"
})
```
