---
name: viewcomponent-vs-phlex
triggers:
  - phlex
  - phlex vs viewcomponent
  - phlex component
  - ruby html
  - component framework
gems:
  - view_component
rails: ">=7.0"
---

# ViewComponent vs Phlex

Both are component frameworks for Rails. They solve the same problem (encapsulated, testable view logic) with different approaches.

## Key differences

| Aspect | ViewComponent | Phlex |
|--------|--------------|-------|
| Templates | ERB/HAML/Slim files | Pure Ruby |
| Rendering | ActionView pipeline | Own rendering engine |
| Speed | ~3x faster than partials | ~7-10x faster than partials |
| Slots | `renders_one`, `renders_many` | `render` + blocks |
| Testing | `render_inline` helper | `render` returns string |
| Ecosystem | Mature, Lookbook, wide adoption | Newer, growing fast |
| Learning curve | Familiar ERB | Must learn Ruby DSL |
| GitHub adoption | Shopify, GitHub, many large apps | Growing, fewer large deployments |

## ViewComponent: ERB templates

```ruby
class CardComponent < ViewComponent::Base
  def initialize(title:)
    @title = title
  end
end
```

```erb
<%# card_component.html.erb %>
<div class="card">
  <h3><%= @title %></h3>
  <%= content %>
</div>
```

## Phlex: Pure Ruby

```ruby
class CardComponent < Phlex::HTML
  def initialize(title:)
    @title = title
  end

  def view_template
    div(class: "card") do
      h3 { @title }
      yield if block_given?
    end
  end
end
```

## When to choose ViewComponent

- Your team knows ERB and wants familiar templates
- You need Lookbook for a component gallery
- You want the largest ecosystem and community support
- You're in a large codebase that already uses ViewComponent

## When to choose Phlex

- You want maximum rendering performance
- You prefer writing HTML in Ruby (no template file context-switching)
- You want components that are plain Ruby objects with no framework magic
- You're starting a new project and want the faster option

## Pattern: Using both together

They're not mutually exclusive. You can use ViewComponent for complex components with slots and Phlex for simple, performance-critical components.

```ruby
# A Phlex component rendered inside a ViewComponent
class DashboardComponent < ViewComponent::Base
  def call
    render PhxStatsWidget.new(count: @count)
  end
end
```

## Anti-pattern: Choosing based on benchmarks alone

Phlex is faster, but ViewComponent is fast enough for almost every app. Choose based on your team's comfort with Ruby HTML DSLs, your need for Lookbook, and your existing codebase — not nanosecond differences.
