# Contributing to Rubyn Skill Packs

This guide covers everything you need to create and submit a skill pack. A new
contributor who reads this document should be able to open a valid PR without
asking questions.

---

## Quick Start

1. Fork this repository
2. Copy `template/` to a new directory named after your pack: `cp -r template/ your-pack-name`
3. Edit `manifest.json` with your pack's metadata
4. Write your skill files as markdown with YAML frontmatter
5. Validate: `ruby scripts/validate-pack.rb your-pack-name`
6. Fix any errors, then open a PR against `main`

---

## Pack Structure

```
your-pack/
  manifest.json       # Required — pack metadata and skill file listing
  README.md           # Optional — shown on rubyn.ai pack page
  first_skill.md      # Skill files — markdown with YAML frontmatter
  second_skill.md
  ...
```

Every `.md` file in the directory must be listed in `manifest.json`. The
validator enforces this both ways: missing listed files and unlisted files both
fail.

---

## manifest.json Schema

```json
{
  "name": "your-pack",
  "displayName": "Your Pack",
  "description": "One-line description of what this pack covers",
  "version": "1.0.0",
  "author": "your-github-username",
  "category": "frontend",
  "tags": ["relevant", "search", "terms"],
  "compatibility": {
    "rubynCode": ">=0.5.0",
    "rails": ">=7.0"
  },
  "gemDependencies": ["the-gem-name"],
  "skills": [
    "first_skill.md",
    "second_skill.md"
  ]
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Pack identifier. Lowercase, hyphens allowed. Must match the directory name exactly. |
| `displayName` | string | Human-readable name shown in the UI and on rubyn.ai. |
| `description` | string | One-line description, 120 characters max. |
| `version` | string | Semver format: `MAJOR.MINOR.PATCH` (e.g. `1.0.0`). |
| `author` | string | Your GitHub username. Use `rubyn` only for official packs. |
| `category` | string | One of the category IDs listed below. |
| `skills` | array | List of skill filenames. Every file listed must exist in the directory. Every `.md` file in the directory must be listed here. |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `tags` | array | Search keywords. Keep it under 10 tags. |
| `compatibility.rubynCode` | string | Minimum rubyn-code gem version required (e.g. `>=0.5.0`). |
| `compatibility.rails` | string | Minimum Rails version the pack's advice applies to (e.g. `>=7.0`). |
| `gemDependencies` | array | Gem names this pack relates to. Used for auto-suggestions when the gem is detected in a project's Gemfile. |

### Categories

| ID | Display Name | Use for |
|----|-------------|---------|
| `frontend` | Frontend | Hotwire, ViewComponent, JS integrations |
| `auth` | Authentication | Devise, JWT, OAuth flows |
| `payments` | Payments & Commerce | Stripe, Pay gem, billing |
| `background` | Background Jobs | Sidekiq, GoodJob, Delayed Job |
| `api` | API & Serialization | GraphQL, JSON:API, REST patterns |
| `testing` | Testing | Test helpers, factories, mocking |
| `infra` | Infrastructure | Kamal, Docker, deployment |
| `data` | Data & Search | Elasticsearch, Redis, data pipelines |
| `authorization` | Authorization | Pundit, CanCanCan, scopes |

### Naming Rules

- Match the gem name where possible: `stripe` not `stripe-payments`, `sidekiq` not `background-jobs`
- Exception for multi-gem packs: `hotwire` covers both `turbo-rails` and `stimulus-rails`
- **Pack names are permanent.** The registry is append-only — once a name is published, it cannot be renamed, reassigned, or reused. Version bumps are fine; name changes are not. Choose carefully.

---

## Skill File Format

Each skill file is a markdown document with YAML frontmatter:

```markdown
---
name: your-skill-name
triggers:
  - keyword phrase one
  - keyword phrase two
  - MethodName
gems:
  - the-gem-name
rails: ">=7.0"
---

# Skill Title

Brief intro — what problem this skill addresses and when it applies.

## Pattern: The recommended approach

Explain the pattern clearly, then show working code.

```ruby
# Good — descriptive comment explaining what this does
class PaymentsController < ApplicationController
  def create
    charge = Stripe::PaymentIntent.create(
      amount: @order.total_cents,
      currency: 'usd',
      payment_method: params[:payment_method_id],
      confirm: true
    )
    @order.mark_paid!(stripe_id: charge.id)
  end
end
```

### Why this works

Explain the reasoning. Not just "do this" but "do this because..."

## Anti-pattern: What to avoid

Explain what's wrong and why developers commonly make this mistake.

```ruby
# Bad — explain specifically what's wrong
class PaymentsController < ApplicationController
  def create
    # Don't do this
  end
end
```

### Why this fails

Concrete consequences — performance degradation, security risk, maintenance burden,
data loss potential, etc.
```

### Frontmatter Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | string | Unique skill identifier. Lowercase, hyphens. Used for loading and deduplication. |
| `triggers` | Yes | array | Phrases that activate this skill. See [Writing Good Triggers](#writing-good-triggers). |
| `gems` | No | array | Related gem names. Informational — used for display, not activation. |
| `rails` | No | string | Minimum Rails version this skill's advice applies to (e.g. `">=7.0"`). |

### Writing Good Triggers

Triggers determine when a skill loads into context. This is the most important
design decision in a skill — get it wrong and the skill never fires, or fires on
everything.

**Too broad** — activates on noise, wastes context on unrelated work:

```yaml
triggers:
  - controller    # matches every Rails file
  - model         # matches every ActiveRecord discussion
  - test          # matches every test mention
```

**Too narrow** — never activates because users don't phrase things that precisely:

```yaml
triggers:
  - Stripe::PaymentIntent.create with idempotency key
  - webhook signature verification with raw body string
```

**Just right** — specific enough to be relevant, broad enough to match natural usage:

```yaml
triggers:
  - stripe webhook
  - webhook endpoint
  - stripe signature
  - construct_event
  - payment intent
  - stripe charge
```

**Rules of thumb:**

- Aim for 3–8 triggers per skill
- Include method names and class names (`construct_event`, `PaymentIntent`)
- Include natural language phrases a developer would use ("stripe webhook", "payment intent")
- Don't include single common words (`payment`, `webhook`, `stripe`) — too broad
- Don't write full sentences — too narrow

---

## Rails 7+ Conventions

All skills must use Rails 7+ conventions unless the `rails` frontmatter field
specifies otherwise.

**Use these patterns:**

```ruby
# Encrypted credentials (not ENV variables for secrets)
Rails.application.credentials.stripe[:secret_key]

# Turbo-aware redirects
redirect_to @record, status: :see_other  # required for Turbo Drive

# Hotwire-style form handling — don't rescue in controllers
# Let the model validate; render unprocessable_entity on failure
def create
  @record = Record.new(record_params)
  if @record.save
    redirect_to @record, status: :see_other
  else
    render :new, status: :unprocessable_entity
  end
end

# Strong parameters — always
def record_params
  params.require(:record).permit(:name, :email)
end
```

**Don't use these:**

```ruby
# Rails 5-era patterns — don't appear in skill examples
render json: { error: 'Not found' }, status: 404  # use :not_found symbol
before_filter :authenticate_user!  # renamed to before_action in Rails 4
```

---

## Quality Guidelines

Every skill must have:

- **Valid YAML frontmatter** with `name` and `triggers`
- **At least one `## Pattern:` section** with a working, copy-pasteable code example
- **At least one `## Anti-pattern:` section** explaining what NOT to do and why
- **Rails 7+ conventions** throughout all code examples
- **No placeholder content** — every section must contain real, immediately-useful guidance

Don't duplicate the 112 built-in skills. Those cover core Ruby, Rails, RSpec,
Minitest, SOLID principles, and design patterns. Community packs should cover
**specific gems and integrations** that the built-ins don't address.

**Anti-patterns to avoid in the pack itself:**

- Skill files that are mostly prose with no code examples
- Code examples with `# TODO: implement this` or `raise NotImplementedError`
- Triggers that fire on every Rails conversation
- Skills that just restate the gem's README without adding opinionated guidance
- Missing anti-pattern sections — showing what NOT to do is as valuable as showing what to do

---

## Validation

Before submitting, validate your pack locally:

```bash
ruby scripts/validate-pack.rb your-pack-name
```

To validate all packs at once:

```bash
ruby scripts/validate-pack.rb --all
```

The validator checks:

- `manifest.json` exists and is valid JSON
- All required manifest fields are present with correct types
- Version is valid semver (`MAJOR.MINOR.PATCH`)
- Every file listed in `skills` exists on disk
- Every `.md` file in the directory is listed in `skills`
- Every skill file has valid YAML frontmatter with `name` and `triggers`
- `triggers` array is not empty

The PR CI runs this automatically on changed packs. A failing validator blocks
merge.

---

## Submitting a PR

1. Fork this repository on GitHub
2. Clone your fork: `git clone https://github.com/your-username/skill-packs.git`
3. Create a branch: `git checkout -b feat/your-pack-name`
4. Copy the template: `cp -r template/ your-pack-name`
5. Write your pack
6. Validate: `ruby scripts/validate-pack.rb your-pack-name`
7. Commit and push to your fork
8. Open a PR against `main` in this repository

**PR title format:** `feat: add <pack-name> pack`

**PR description should include:**
- What gem(s) the pack covers
- How many skills and what they address
- Any Rails version requirements

The CI validates your pack automatically. A maintainer reviews content quality
before merging — validation passing is necessary but not sufficient.

---

## Content Review Checklist

Run through this before opening your PR:

- [ ] Frontmatter has `name` and `triggers` on every skill file
- [ ] Triggers are specific (3–8 per skill, no single generic words)
- [ ] At least one `## Pattern:` section per skill with working, copy-pasteable code
- [ ] At least one `## Anti-pattern:` section per skill explaining what NOT to do and why
- [ ] All code examples use Rails 7+ conventions
- [ ] No placeholder or stub content — every section has real, useful guidance
- [ ] Pack doesn't duplicate built-in skills (core Ruby, Rails, RSpec, design patterns)
- [ ] Every skill file is listed in `manifest.json` under `skills`
- [ ] `ruby scripts/validate-pack.rb your-pack` passes with 0 errors
- [ ] `README.md` describes the pack and lists its skills

---

## Example: Anatomy of a Real Pack

Here's what the `pundit` pack looks like as a reference:

```
pundit/
  manifest.json
  policy_basics.md
  scopes.md
  testing_policies.md
  headless_policies.md
  namespaced_policies.md
  integration_patterns.md
```

**manifest.json:**

```json
{
  "name": "pundit",
  "displayName": "Pundit",
  "description": "Policy classes, scopes, testing, namespacing, and controller integration patterns",
  "version": "1.0.0",
  "author": "rubyn",
  "category": "authorization",
  "tags": ["pundit", "authorization", "policies", "scopes", "permissions"],
  "compatibility": {
    "rubynCode": ">=0.5.0",
    "rails": ">=7.0"
  },
  "gemDependencies": ["pundit"],
  "skills": [
    "policy_basics.md",
    "scopes.md",
    "testing_policies.md",
    "headless_policies.md",
    "namespaced_policies.md",
    "integration_patterns.md"
  ]
}
```

**A skill file (policy_basics.md):**

```markdown
---
name: pundit-policy-basics
triggers:
  - pundit policy
  - authorize
  - policy class
  - pundit setup
  - authorization
gems:
  - pundit
---

# Pundit Policy Basics

Pundit policies are plain Ruby classes that encapsulate authorization logic.
Each model gets one policy class; each action gets one method.

## Pattern: One policy per model

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def update?
    record.user == user || user.admin?
  end

  def destroy?
    user.admin?
  end
end
```

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    authorize @post          # raises Pundit::NotAuthorizedError if denied
    @post.update!(post_params)
    redirect_to @post, status: :see_other
  end
end
```

### Why this works

Authorization logic lives in one place per model. The controller stays thin.
Pundit raises `NotAuthorizedError` — you rescue it once in
`ApplicationController` and render a 403.

## Anti-pattern: Fat controller authorization

```ruby
# Bad — authorization logic scattered in controllers
def update
  @post = Post.find(params[:id])
  unless current_user == @post.user || current_user.admin?
    redirect_to root_path, alert: 'Not authorized'
    return
  end
  @post.update!(post_params)
end
```

### Why this fails

Authorization rules duplicate across actions and controllers. When the rule
changes (e.g. editors can also update), you hunt down every conditional.
Testing requires a full controller spec instead of a plain Ruby unit test.
```

Study the other packs in this repo for more examples before writing your own.

---

## What Happens After Merge

When your PR merges to `main`:

1. CI regenerates `registry.json` with your pack included
2. The registry syncs to rubyn.ai within minutes
3. Your pack becomes available via `/install-skills your-pack`
4. It appears in the browsable catalog at rubyn.ai/skills
