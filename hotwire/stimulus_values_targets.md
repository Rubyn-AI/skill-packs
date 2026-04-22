---
name: stimulus-values-targets
triggers:
  - stimulus values
  - stimulus targets
  - data-*-value
  - data-*-target
  - static values
  - static targets
  - valueChanged
  - has*Target
gems:
  - stimulus-rails
rails: ">=7.0"
---

# Stimulus Values and Targets

Values are typed data attributes that Stimulus auto-parses. Targets are named element references. Together they replace manual DOM querying and data attribute parsing.

## Values

Declare typed values on the controller. Stimulus generates getters, setters, and change callbacks.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,              // Required, no default
    count: { type: Number, default: 0 },
    open: { type: Boolean, default: false },
    items: { type: Array, default: [] },
    config: { type: Object, default: {} }
  }

  // Auto-generated: this.urlValue, this.countValue, this.openValue, etc.
  // Auto-generated: this.hasUrlValue, this.hasCountValue, etc.
  // Auto-generated: urlValueChanged(), countValueChanged(), etc.

  countValueChanged(newValue, previousValue) {
    // Fires when countValue changes — including on connect
    this.element.textContent = `Count: ${newValue}`
  }
}
```

```erb
<div data-controller="counter"
     data-counter-url-value="<%= api_path %>"
     data-counter-count-value="5"
     data-counter-open-value="true"
     data-counter-items-value='["a","b","c"]'
     data-counter-config-value='{"key":"val"}'>
</div>
```

Supported types: `String`, `Number`, `Boolean`, `Array`, `Object`. Arrays and objects are JSON-parsed from the attribute.

## Anti-pattern: Parsing data attributes manually

```javascript
// BAD — manual parsing
connect() {
  this.url = this.element.dataset.url
  this.count = parseInt(this.element.dataset.count)
  this.open = this.element.dataset.open === "true"
}

// GOOD — use values API
static values = { url: String, count: Number, open: Boolean }
// this.urlValue, this.countValue, this.openValue just work
```

## Targets

Targets are named references to elements inside the controller.

```javascript
export default class extends Controller {
  static targets = ["input", "output", "submitButton"]

  // Auto-generated:
  // this.inputTarget     — first matching element (throws if missing)
  // this.inputTargets    — array of all matching elements
  // this.hasInputTarget  — boolean, true if at least one exists

  greet() {
    this.outputTarget.textContent = `Hello, ${this.inputTarget.value}!`
  }
}
```

```erb
<div data-controller="greeter">
  <input data-greeter-target="input" type="text">
  <button data-action="greeter#greet">Greet</button>
  <span data-greeter-target="output"></span>
</div>
```

## Anti-pattern: Using querySelector instead of targets

```javascript
// BAD — fragile, couples to CSS classes/structure
greet() {
  const input = this.element.querySelector(".greeting-input")
  const output = this.element.querySelector("#output")
}

// GOOD — targets are semantic and refactor-safe
static targets = ["input", "output"]
greet() {
  this.outputTarget.textContent = this.inputTarget.value
}
```

## Pattern: Optional targets with has*Target

Not all targets exist at all times (conditional rendering, lazy loading).

```javascript
export default class extends Controller {
  static targets = ["error"]

  validate() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = "Invalid input"
      this.errorTarget.hidden = false
    }
  }
}
```

Without the `has` check, accessing a missing target throws an error.

## Pattern: Working with multiple targets

`*Targets` (plural) returns all matching elements as an array.

```javascript
export default class extends Controller {
  static targets = ["checkbox"]

  selectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = true)
  }

  get checkedCount() {
    return this.checkboxTargets.filter(cb => cb.checked).length
  }
}
```

## CSS Classes API

Declare CSS class names as data attributes so they're configurable per-instance.

```javascript
export default class extends Controller {
  static classes = ["active", "loading"]

  // this.activeClass     — the class name string
  // this.loadingClass    — the class name string
  // this.hasActiveClass  — boolean

  activate() {
    this.element.classList.add(this.activeClass)
  }
}
```

```erb
<div data-controller="tab"
     data-tab-active-class="bg-blue-500 text-white"
     data-tab-loading-class="opacity-50 pointer-events-none">
</div>
```

This keeps CSS class names out of JavaScript. The same controller works with Tailwind, Bootstrap, or custom CSS — just change the data attribute.

## Pattern: Server-driven values with ERB

Pass server data to Stimulus via values. This is the bridge between Rails and JavaScript.

```erb
<div data-controller="chart"
     data-chart-data-value="<%= @sales_data.to_json %>"
     data-chart-type-value="bar"
     data-chart-refresh-interval-value="<%= @refresh_seconds %>">
</div>
```

Stimulus auto-parses the JSON for Object and Array types. No manual `JSON.parse` needed.
