# Rubyn Skill Packs

Community skill packs for [Rubyn Code](https://rubyn.ai) — Rails-specific best practices for popular gems and patterns.

## What are Skill Packs?

Skill packs extend Rubyn Code's 112 built-in skills with domain-specific knowledge for gems like Hotwire, Stripe, Devise, and more. Each pack is a collection of markdown files that teach the AI how to work with a specific tool or pattern.

## Available Packs

| Pack | Skills | Category | Gems |
|------|--------|----------|------|
| [devise](./devise/) | 8 | Authentication | `devise` |
| [graphql-ruby](./graphql-ruby/) | 9 | API & Serialization | `graphql` |
| [hotwire](./hotwire/) | 14 | Frontend | `turbo-rails`, `stimulus-rails` |
| [kamal](./kamal/) | 7 | Infrastructure | `kamal` |
| [pundit](./pundit/) | 6 | Authorization | `pundit` |
| [sidekiq](./sidekiq/) | 8 | Background Jobs | `sidekiq` |
| [stripe](./stripe/) | 11 | Payments & Commerce | `stripe` |
| [view-component](./view-component/) | 7 | Frontend | `view_component` |

**8 packs, 70 skills total.**

## Installation

```bash
# Install a pack
rubyn-code --install-skills hotwire

# Or from inside a rubyn-code session
rubyn > /install-skills hotwire

# Install multiple packs
rubyn > /install-skills hotwire stripe sidekiq

# List installed packs
rubyn > /skills

# Update installed packs
rubyn > /install-skills --update
```

Skills install to `.rubyn-code/skills/<pack>/` in your project directory. They load on demand when you work with related code.

## Pack Format

Each pack is a directory containing:

- `manifest.json` — Pack metadata (name, description, version, skill list)
- `*.md` — Skill files (markdown with YAML frontmatter)
- `README.md` — Optional pack description

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full format specification.

## Contributing

We welcome community packs! See [CONTRIBUTING.md](./CONTRIBUTING.md) for:

- Pack format and manifest.json schema
- YAML frontmatter fields for skill files
- Trigger best practices
- Quality guidelines
- PR submission process

Use the [template/](./template/) directory as a starting point.

## Development

```bash
# Validate a pack
ruby scripts/validate-pack.rb hotwire

# Validate all packs
ruby scripts/validate-pack.rb --all

# Generate registry.json
ruby scripts/generate-registry.rb --pretty
```

## License

MIT License. See [LICENSE](./LICENSE) for details.
