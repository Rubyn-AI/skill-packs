---
name: viewcomponent-previews
triggers:
  - component preview
  - lookbook
  - component preview class
  - preview component
  - component gallery
gems:
  - view_component
rails: ">=7.0"
---

# ViewComponent Previews & Lookbook

Previews let you render components in isolation with different states, making it easy to develop and review them outside your full application.

## Pattern: Basic preview

```ruby
# spec/components/previews/alert_component_preview.rb
# (or test/components/previews/ for Minitest)
class AlertComponentPreview < ViewComponent::Preview
  def info
    render AlertComponent.new(type: :info) do
      "This is informational."
    end
  end

  def success
    render AlertComponent.new(type: :success) do
      "Operation completed."
    end
  end

  def warning_dismissible
    render AlertComponent.new(type: :warning, dismissible: true) do
      "Watch out for this."
    end
  end

  def error
    render AlertComponent.new(type: :error) do
      "Something went wrong."
    end
  end
end
```

Access at `http://localhost:3000/rails/view_components/alert_component/info`.

## Pattern: Preview with Lookbook

Lookbook provides a polished UI for browsing previews with live reload, parameter controls, and documentation.

```ruby
# Gemfile
gem "lookbook", group: :development
```

```ruby
# config/routes.rb (development only)
if Rails.env.development?
  mount Lookbook::Engine, at: "/lookbook"
end
```

Access at `http://localhost:3000/lookbook`.

## Pattern: Annotated previews with Lookbook tags

```ruby
class ButtonComponentPreview < ViewComponent::Preview
  # @label Primary button
  # @display bg_color "#f8f9fa"
  def primary
    render ButtonComponent.new(variant: :primary) do
      "Click me"
    end
  end

  # @label With icon
  # @param icon select [arrow, check, close, download]
  # @param size select [sm, md, lg]
  def with_icon(icon: "check", size: "md")
    render ButtonComponent.new(icon: icon, size: size) do
      "Download"
    end
  end
end
```

`@param` annotations create interactive controls in Lookbook's sidebar. Change parameters without editing code.

## Pattern: Preview with realistic data

```ruby
class UserCardComponentPreview < ViewComponent::Preview
  def default
    user = OpenStruct.new(
      name: "Jane Smith",
      email: "jane@example.com",
      avatar_url: "https://i.pravatar.cc/150?img=5",
      role: "Admin",
      created_at: 2.years.ago
    )
    render UserCardComponent.new(user: user)
  end

  def new_user
    user = OpenStruct.new(
      name: "New User",
      email: "new@example.com",
      avatar_url: nil,
      role: "Member",
      created_at: Time.current
    )
    render UserCardComponent.new(user: user)
  end
end
```

Use `OpenStruct` or factory objects rather than hitting the database. Previews should work without seeds.

## Anti-pattern: No previews at all

Components without previews are black boxes. You can only see them in context of the full page, making it hard to catch styling issues, edge cases, or regressions. Write previews for every component — they take 2 minutes and save hours of debugging.
