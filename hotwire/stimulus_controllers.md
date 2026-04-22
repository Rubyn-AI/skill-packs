---
name: stimulus-controllers
triggers:
  - stimulus
  - stimulus controller
  - data-controller
  - data-action
  - connect
  - disconnect
  - javascript controller
  - js behavior
gems:
  - stimulus-rails
rails: ">=7.0"
---

# Stimulus Controllers

Stimulus is a modest JavaScript framework for HTML you already have. Controllers connect to DOM elements via `data-controller` attributes and respond to events via `data-action` attributes.

## Pattern: Basic controller structure

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { open: { type: Boolean, default: false } }
  static classes = ["hidden"]

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.contentTarget.classList.toggle(this.hiddenClass, !this.openValue)
  }
}
```

```erb
<div data-controller="toggle" data-toggle-hidden-class="hidden">
  <button data-action="click->toggle#toggle">Toggle</button>
  <div data-toggle-target="content">
    Content that shows/hides
  </div>
</div>
```

Key rules:
- Controller file name matches the `data-controller` value: `toggle_controller.js` → `data-controller="toggle"`
- Multi-word controllers use kebab-case in HTML, underscore in filenames: `copy_to_clipboard_controller.js` → `data-controller="copy-to-clipboard"`
- The controller is scoped to its element and descendants. It cannot reach outside its DOM tree.

## Pattern: Event handling with data-action

The `data-action` attribute wires DOM events to controller methods.

```erb
<%# Syntax: event->controller#method %>
<div data-controller="search">
  <%# Explicit event %>
  <input data-action="input->search#filter" type="text">

  <%# Default event (click for buttons, input for inputs, submit for forms) %>
  <button data-action="search#reset">Reset</button>

  <%# Multiple actions on one element %>
  <input data-action="input->search#filter focus->search#expand blur->search#collapse">

  <%# Keyboard events with key filters (Stimulus 3.2+) %>
  <input data-action="keydown.enter->search#submit keydown.escape->search#clear">
</div>
```

Default events by element type:
- `<input>`, `<textarea>`, `<select>` → `input`
- `<form>` → `submit`
- `<button>`, `<a>`, everything else → `click`

## Pattern: Lifecycle callbacks

```javascript
export default class extends Controller {
  connect() {
    // Called when controller connects to the DOM
    // Set up event listeners, start timers, fetch data
    console.log("connected to", this.element)
  }

  disconnect() {
    // Called when element is removed from the DOM
    // Clean up listeners, stop timers, cancel fetches
  }
}
```

`connect()` fires when the element enters the DOM — including on Turbo page navigations and Turbo Stream insertions. This makes Stimulus + Turbo a natural pair: new HTML arrives, controllers auto-connect.

## Anti-pattern: Querying outside the controller scope

```javascript
// BAD — reaches outside the controller's DOM tree
export default class extends Controller {
  toggle() {
    document.querySelector(".modal").classList.toggle("open")
  }
}

// GOOD — use targets to reference elements inside the controller
export default class extends Controller {
  static targets = ["modal"]

  toggle() {
    this.modalTarget.classList.toggle("open")
  }
}
```

If you need to communicate with elements outside your controller's tree, use custom events, outlets (see stimulus_outlets skill), or Stimulus values that both controllers observe.

## Anti-pattern: Fat controllers

If a controller is over 50 lines, it's doing too much. Split into smaller controllers that each own one behavior.

```javascript
// BAD — one controller doing everything
export default class extends Controller {
  validateForm() { /* ... */ }
  submitForm() { /* ... */ }
  showNotification() { /* ... */ }
  animateTransition() { /* ... */ }
  trackAnalytics() { /* ... */ }
}

// GOOD — compose small controllers
// form_validation_controller.js
// notification_controller.js
// analytics_controller.js
```

```erb
<form data-controller="form-validation analytics" data-action="submit->form-validation#validate">
  ...
</form>
```

Multiple controllers on one element is idiomatic Stimulus. Composition over inheritance.

## Pattern: Dispatching custom events

Controllers communicate with each other via custom DOM events.

```javascript
// dropdown_controller.js
export default class extends Controller {
  select(event) {
    this.dispatch("selected", {
      detail: { value: event.target.dataset.value }
    })
  }
}

// filter_controller.js — listens for the dropdown's event
export default class extends Controller {
  applyFilter(event) {
    const { value } = event.detail
    // filter logic here
  }
}
```

```erb
<div data-controller="filter">
  <div data-controller="dropdown" data-action="dropdown:selected->filter#applyFilter">
    <button data-action="dropdown#select" data-value="recent">Recent</button>
    <button data-action="dropdown#select" data-value="popular">Popular</button>
  </div>
  <div data-filter-target="results">...</div>
</div>
```

The event name is `controller-name:event-name`. Stimulus auto-prefixes the controller name.

## Naming conventions

| Convention | Example |
|-----------|---------|
| Controller filename | `clipboard_controller.js` |
| HTML identifier | `data-controller="clipboard"` |
| Multi-word filename | `content_loader_controller.js` |
| Multi-word HTML | `data-controller="content-loader"` |
| Action | `data-action="click->clipboard#copy"` |
| Target | `data-clipboard-target="source"` |
| Value | `data-clipboard-url-value="/api/copy"` |
| CSS class | `data-clipboard-active-class="bg-green-100"` |
