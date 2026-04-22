---
name: viewcomponent-slots
triggers:
  - component slot
  - renders_one
  - renders_many
  - named slot
  - polymorphic slot
gems:
  - view_component
rails: ">=7.0"
---

# ViewComponent Slots

Slots define named content areas that callers can fill. They replace complex content_for/yield patterns with a typed, component-scoped API.

## Pattern: Single slot with renders_one

```ruby
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :footer

  def initialize(title: nil)
    @title = title
  end
end
```

```erb
<%# card_component.html.erb %>
<div class="card">
  <% if header? %>
    <div class="card-header"><%= header %></div>
  <% elsif @title %>
    <div class="card-header"><h3><%= @title %></h3></div>
  <% end %>

  <div class="card-body"><%= content %></div>

  <% if footer? %>
    <div class="card-footer"><%= footer %></div>
  <% end %>
</div>
```

```erb
<%# Usage %>
<%= render CardComponent.new do |card| %>
  <% card.with_header do %>
    <h2>Custom Header</h2>
  <% end %>

  <p>Card body content goes here.</p>

  <% card.with_footer do %>
    <%= link_to "Read more", post_path(@post) %>
  <% end %>
<% end %>
```

## Pattern: Collection slot with renders_many

```ruby
class TabsComponent < ViewComponent::Base
  renders_many :tabs, "TabComponent"

  class TabComponent < ViewComponent::Base
    def initialize(title:, active: false)
      @title = title
      @active = active
    end
  end
end
```

```erb
<%# tabs_component.html.erb %>
<div class="tabs">
  <nav>
    <% tabs.each do |tab| %>
      <button class="<%= 'active' if tab.active %>"><%= tab.title %></button>
    <% end %>
  </nav>
  <% tabs.each do |tab| %>
    <div class="tab-panel"><%= tab %></div>
  <% end %>
</div>
```

```erb
<%# Usage %>
<%= render TabsComponent.new do |tabs| %>
  <% tabs.with_tab(title: "Overview", active: true) do %>
    <p>Overview content</p>
  <% end %>
  <% tabs.with_tab(title: "Details") do %>
    <p>Details content</p>
  <% end %>
<% end %>
```

## Pattern: Polymorphic slots

```ruby
class MediaComponent < ViewComponent::Base
  renders_one :media, types: {
    image: "ImageComponent",
    video: "VideoComponent"
  }

  class ImageComponent < ViewComponent::Base
    def initialize(src:, alt:)
      @src = src
      @alt = alt
    end
  end

  class VideoComponent < ViewComponent::Base
    def initialize(src:, poster: nil)
      @src = src
      @poster = poster
    end
  end
end
```

```erb
<%# Usage — caller chooses which type to render %>
<%= render MediaComponent.new do |media| %>
  <% media.with_media_image(src: "/photo.jpg", alt: "A photo") %>
  <p>Caption here</p>
<% end %>
```

## Anti-pattern: Overusing slots

```ruby
# BAD — every element is a slot, overly complex
class FormComponent < ViewComponent::Base
  renders_one :label
  renders_one :input
  renders_one :hint
  renders_one :error
  renders_one :prefix_icon
  renders_one :suffix_icon
  # 6 slots for a form field is too many
end

# GOOD — use initialize params for simple values, slots for complex content
class FormFieldComponent < ViewComponent::Base
  renders_one :hint  # Only slot: hints can be rich HTML

  def initialize(label:, error: nil)
    @label = label
    @error = error
  end
end
```

Use slots for content that callers need to fill with arbitrary HTML. Use initialize parameters for simple strings and options.
