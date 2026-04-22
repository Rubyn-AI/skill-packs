# Contributing to Rubyn Skill Packs

Thank you for contributing! This guide covers everything you need to create and submit a skill pack.

## Quick Start

1. Copy the `template/` directory and rename it to your pack name
2. Edit `manifest.json` with your pack's metadata
3. Write your skill files as markdown with YAML frontmatter
4. Validate: `ruby scripts/validate-pack.rb your-pack-name`
5. Open a PR

## Pack Structure

```
your-pack/
  manifest.json       # Required — pack metadata
  README.md           # Optional — shown on rubyn.ai pack page
  first_skill.md      # Skill files — markdown with frontmatter
  second_skill.md
  ...
```

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
| `name` | string | Pack identifier. Lowercase, hyphens allowed. Must match directory name. |
| `displayName` | string | Human-readable name shown in the UI. |
| `description` | string | One-line description (under 120 characters). |
| `version` | string | Semver format: `MAJOR.MINOR.PATCH` (e.g. `1.0.0`). |
| `author` | string | GitHub username or `rubyn` for official packs. |
| `category` | string | One of: `frontend`, `auth`, `payments`, `background`, `api`, `testing`, `infra`, `data`, `authorization`. |
| `skills` | array | List of skill filenames. Every file listed must exist in the directory. |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `tags` | array | Search keywords. Keep it under 10 tags. |
| `compatibility.rubynCode` | string | Minimum rubyn-code version (e.g. `>=0.5.0`). |
| `compatibility.rails` | string | Minimum Rails version (e.g. `>=7.0`). |
| `gemDependencies` | array | Gem names this pack relates to. Used for auto-suggestions. |

### Naming Rules

- Pack names match gem names where possible: `stripe` not `stripe-payments`, `sidekiq` not `background-jobs-sidekiq`.
- Exception: multi-gem packs like `hotwire` (covers `turbo-rails` + `stimulus-rails`).
- **The registry is append-only.** Once a pack name is published, it cannot be renamed, reassigned, or reused. Version bumps are fine; name changes are not. Choose your pack name carefully.

### Categories

| ID | Display Name |
|----|-------------|
| `frontend` | Frontend |
| `auth` | Authentication |
| `payments` | Payments & Commerce |
| `background` | Background Jobs |
| `api` | API & Serialization |
| `testing` | Testing |
| `infra` | Infrastructure |
| `data` | Data & Search |
| `authorization` | Authorization |

## Skill File Format

Each skill file is markdown with YAML frontmatter:

```markdown
---
name: your-skill-name
triggers:
  - keyword phrase one
  - keyword phrase two
  - method_name_or_class
gems:
  - the-gem-name
rails: ">=7.0"
---

# Skill Title

Brief intro paragraph.

## Pattern: Descriptive name

Explain the pattern, then show a working code example.

\`\`\`ruby
# Working code example
class PaymentsController < ApplicationController
  def create
    # ...
  end
end
\`\`\`

## Anti-pattern: What NOT to do

Explain why this is wrong.

\`\`\`ruby
# Bad example — explain what's wrong
\`\`\`
```

### Frontmatter Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | string | Unique skill identifier (lowercase, hyphens). |
| `triggers` | Yes | array | Phrases that activate this skill. When a user asks about these terms or edits files containing them, the skill loads into context. |
| `gems` | No | array | Related gem names. |
| `rails` | No | string | Minimum Rails version for this skill's advice. |

### Writing Good Triggers

Triggers determine when a skill activates. Get these right:

**Too broad** (activates on noise):
```yaml
triggers:
  - controller    # matches every Rails file
  - test          # matches every test discussion
```

**Too narrow** (never activates):
```yaml
triggers:
  - Stripe::Webhook.construct_event with raw body
```

**Just right:**
```yaml
triggers:
  - stripe webhook
  - webhook endpoint
  - stripe signature
  - construct_event
```

Aim for 3-8 triggers per skill. Include the method names, class names, and natural language phrases a developer would use.

## Quality Guidelines

Every skill must have:

- **Valid YAML frontmatter** with `name` and `triggers`
- **At least one "Pattern" section** with a working code example
- **At least one "Anti-pattern" section** showing what NOT to do
- **Rails 7+ conventions** (or 8+ where specified)
- **No placeholder content** — every skill must be immediately useful

Don't duplicate the 112 built-in skills. Those cover core Ruby, Rails, RSpec, Minitest, SOLID principles, and design patterns. Community packs should cover **specific gems and integrations**.

## Validation

Before submitting, validate your pack:

```bash
ruby scripts/validate-pack.rb your-pack-name
```

This checks:
- manifest.json exists and has all required fields
- Version is valid semver
- All listed skill files exist on disk
- All .md files are listed in the manifest
- Each skill file has valid YAML frontmatter with required fields

The PR CI runs this automatically on changed packs.

## Submitting a PR

1. Fork this repository
2. Create your pack directory (use `template/` as a starting point)
3. Run `ruby scripts/validate-pack.rb your-pack` — fix any errors
4. Commit and push to your fork
5. Open a PR against `main`

The CI will validate your pack automatically. A maintainer will review the content quality before merging.

## Content Review Checklist

Before opening your PR, verify each skill file against this checklist:

- [ ] Frontmatter has `name` and `triggers` fields
- [ ] Triggers are specific enough (3-8 per skill, no overly broad terms)
- [ ] At least one `## Pattern:` section with a working, copy-pasteable code example
- [ ] At least one `## Anti-pattern:` section explaining what NOT to do and why
- [ ] Code examples use Rails 7+ conventions (or 8+ where specified in frontmatter)
- [ ] No placeholder or stub content — every section has real, useful guidance
- [ ] Skill doesn't duplicate built-in skills (core Ruby, Rails, RSpec, design patterns)
- [ ] Skill file is listed in `manifest.json` under `skills`
- [ ] `ruby scripts/validate-pack.rb your-pack` passes with 0 errors

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

**A skill file (policy_basics.md) starts like:**
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

Pundit policies are plain Ruby classes that encapsulate authorization logic...

## Pattern: One policy per model
...

## Anti-pattern: Fat controller authorization
...
```

Study the existing packs in this repo for more examples of well-written skills.

## What Happens After Merge

When your PR merges to `main`:
1. CI regenerates `registry.json` with your pack included
2. The registry syncs to rubyn.ai
3. Your pack becomes available via `/install-skills your-pack`
4. It appears in the browsable catalog at rubyn.ai/skills
