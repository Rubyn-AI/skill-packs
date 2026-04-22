---
name: viewcomponent-testing
triggers:
  - test component
  - render_inline
  - component spec
  - viewcomponent test
  - with_content
gems:
  - view_component
rails: ">=7.0"
---

# Testing ViewComponents

## Setup

```ruby
# spec/rails_helper.rb
require "view_component/test_helpers"
require "view_component/system_test_helpers"
require "capybara/rspec"

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
```

## Pattern: Basic component test

```ruby
# spec/components/alert_component_spec.rb
RSpec.describe AlertComponent, type: :component do
  it "renders an info alert" do
    render_inline(AlertComponent.new(type: :info)) { "Hello world" }

    expect(page).to have_css(".alert.alert-info", text: "Hello world")
  end

  it "renders a dismiss button when dismissible" do
    render_inline(AlertComponent.new(type: :warning, dismissible: true)) { "Watch out" }

    expect(page).to have_css("button.alert-dismiss")
  end

  it "does not render dismiss button by default" do
    render_inline(AlertComponent.new) { "Info" }

    expect(page).not_to have_css("button.alert-dismiss")
  end
end
```

## Pattern: Testing slots

```ruby
RSpec.describe CardComponent, type: :component do
  it "renders with header and footer slots" do
    render_inline(CardComponent.new) do |card|
      card.with_header { "My Header" }
      card.with_footer { "My Footer" }
      "Body content"
    end

    expect(page).to have_css(".card-header", text: "My Header")
    expect(page).to have_css(".card-body", text: "Body content")
    expect(page).to have_css(".card-footer", text: "My Footer")
  end

  it "renders without optional slots" do
    render_inline(CardComponent.new) { "Just body" }

    expect(page).not_to have_css(".card-header")
    expect(page).not_to have_css(".card-footer")
    expect(page).to have_css(".card-body", text: "Just body")
  end
end
```

## Pattern: Testing render?

```ruby
RSpec.describe BreadcrumbComponent, type: :component do
  it "does not render with a single item" do
    render_inline(BreadcrumbComponent.new(items: ["Home"]))

    expect(page).not_to have_css(".breadcrumb")
  end

  it "renders with multiple items" do
    render_inline(BreadcrumbComponent.new(items: ["Home", "Posts", "Edit"]))

    expect(page).to have_css(".breadcrumb")
    expect(page).to have_text("Home")
    expect(page).to have_text("Posts")
  end
end
```

## Anti-pattern: Testing component internals

```ruby
# BAD — tests private implementation details
it "sets the correct CSS class" do
  component = AlertComponent.new(type: :error)
  expect(component.send(:css_class)).to eq("alert-error")
end

# GOOD — test the rendered output
it "renders with the error class" do
  render_inline(AlertComponent.new(type: :error)) { "Error" }
  expect(page).to have_css(".alert-error")
end
```

Test what the user sees (rendered HTML), not how the component builds it internally.
