---
name: stimulus-outlets
triggers:
  - stimulus outlet
  - outlet
  - controller communication
  - cross-controller
gems:
  - stimulus-rails
rails: ">=7.0"
---

# Stimulus Outlets

Outlets let one controller reference another controller's instance. This is the clean way for controllers to communicate without custom events or global state.

## Pattern: Dropdown controlling a filter

```javascript
// filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["search"]

  filter(event) {
    const category = event.target.dataset.category
    // Call a method on the connected search controller
    this.searchOutlet.filterByCategory(category)
  }
}
```

```erb
<div data-controller="filter" data-filter-search-outlet="#search-panel">
  <button data-action="filter#filter" data-category="ruby">Ruby</button>
  <button data-action="filter#filter" data-category="rails">Rails</button>
</div>

<div id="search-panel" data-controller="search">
  <%# search controller lives here %>
</div>
```

## API

| Property | Returns |
|---------|---------|
| `this.searchOutlet` | First connected outlet instance |
| `this.searchOutlets` | Array of all connected instances |
| `this.hasSearchOutlet` | Boolean — at least one exists |
| `searchOutletConnected(outlet, element)` | Callback when outlet connects |
| `searchOutletDisconnected(outlet, element)` | Callback when outlet disconnects |

## Anti-pattern: Using querySelector to find other controllers

```javascript
// BAD — fragile, breaks if DOM structure changes
const other = document.querySelector("[data-controller='search']")
const ctrl = this.application.getControllerForElementAndIdentifier(other, "search")

// GOOD — use outlets
static outlets = ["search"]
this.searchOutlet.doSomething()
```

Outlets are declarative, tracked, and provide lifecycle callbacks. Manual lookups are fragile and don't notify you when the target disconnects.
