---
name: your-pack-example-skill
triggers:
  - example keyword phrase
  - ExampleClassName
  - example_method_name
  - example concept
gems:
  - the-gem-name
rails: ">=7.0"
---

# Example Skill: What This Covers

Brief introduction — what problem this skill addresses, when it applies, and
what the developer is typically trying to do when this skill loads.

Keep this to 2–3 sentences. The patterns below do the teaching.

## Pattern: The recommended approach

Explain the pattern in 1–2 sentences, then show working code immediately.

```ruby
# Good — explain what makes this approach correct
class ExampleService
  def self.call(record:, user:)
    new(record: record, user: user).call
  end

  def initialize(record:, user:)
    @record = record
    @user = user
  end

  def call
    authorize!
    process
  end

  private

  def authorize!
    raise ExampleGem::NotAuthorizedError unless @user.can_manage?(@record)
  end

  def process
    ExampleGem::Client.new.perform(
      resource: @record.external_id,
      options: { notify: true }
    )
  end
end
```

```ruby
# Usage in a controller
class RecordsController < ApplicationController
  def update
    @record = Record.find(params[:id])
    ExampleService.call(record: @record, user: current_user)
    redirect_to @record, status: :see_other
  rescue ExampleGem::NotAuthorizedError
    render :edit, status: :unprocessable_entity
  end
end
```

### Why this works

Explain the reasoning: not just "do this" but "do this because..."

For example: the service object encapsulates the gem interaction in one place,
so controller tests don't need to stub the gem directly, and the logic can be
reused from background jobs without duplicating the gem calls.

## Anti-pattern: Inline gem calls scattered across controllers

Explain what's wrong and why developers commonly fall into this pattern.

```ruby
# Bad — gem interaction spread across the codebase
class RecordsController < ApplicationController
  def update
    @record = Record.find(params[:id])
    # Authorization check missing — anyone authenticated can call this
    ExampleGem::Client.new.perform(
      resource: @record.external_id,
      options: { notify: true }
    )
    redirect_to @record, status: :see_other
  end

  def destroy
    @record = Record.find(params[:id])
    # Same gem setup duplicated — two places to update if the API changes
    ExampleGem::Client.new.perform(
      resource: @record.external_id,
      options: { notify: false }
    )
    @record.destroy!
    redirect_to records_path, status: :see_other
  end
end
```

### Why this fails

Concrete consequences of this approach:

- **No authorization** — any authenticated user can trigger the gem operation
- **Duplication** — when the gem's API changes (e.g. new required option), you
  update multiple controllers instead of one service
- **Untestable in isolation** — controller tests must stub the gem client every
  time, coupling tests to implementation details
- **No reuse** — background jobs that need the same operation copy-paste the
  same gem calls
