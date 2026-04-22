---
name: kamal-asset-bridging
triggers:
  - kamal assets
  - asset compilation
  - precompile
  - cdn kamal
  - docker assets
  - asset pipeline kamal
gems:
  - kamal
rails: ">=7.0"
---

# Kamal Asset Compilation & Bridging

## Pattern: Precompile assets in the Docker build

```dockerfile
# Dockerfile
FROM ruby:4.0-slim AS base
WORKDIR /rails

FROM base AS build
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs npm
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test
COPY . .

# Precompile assets inside the Docker build
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE_DUMMY=1
RUN bundle exec rails assets:precompile

FROM base
COPY --from=build /rails /rails
EXPOSE 3000
CMD ["bin/rails", "server"]
```

`SECRET_KEY_BASE_DUMMY=1` is a Rails 7.1+ feature that allows asset precompilation without a real secret key. Assets are compiled during `docker build`, not during deployment.

## Pattern: Serving assets from a CDN

```ruby
# config/environments/production.rb
config.asset_host = "https://cdn.myapp.com"
```

```yaml
# config/deploy.yml
env:
  clear:
    RAILS_ASSET_HOST: "https://cdn.myapp.com"
```

Upload your compiled assets to the CDN after building:

```bash
# In CI/CD, after docker build:
aws s3 sync public/assets s3://myapp-assets/ --cache-control "public, max-age=31536000"
# Or use CloudFront, Cloudflare R2, DigitalOcean Spaces, etc.
```

## Pattern: Asset fingerprinting for cache busting

Rails automatically fingerprints assets (`application-abc123.css`). With proper `Cache-Control` headers, browsers cache assets indefinitely and fetch new ones only when the fingerprint changes.

```ruby
# config/environments/production.rb
config.assets.digest = true  # Default in production
config.public_file_server.headers = {
  "Cache-Control" => "public, max-age=31536000, immutable"
}
```

## Pattern: Propshaft (Rails 8+ default)

```ruby
# Gemfile
gem "propshaft"  # Replaces sprockets in Rails 8
```

Propshaft is simpler than Sprockets — it fingerprints and serves assets without compilation steps. CSS and JS are handled by `cssbundling-rails` and `jsbundling-rails`.

## Anti-pattern: Running asset precompilation during deploy

```bash
# BAD — slows down every deploy, risks failure on production servers
kamal app exec 'rails assets:precompile'

# GOOD — precompile in the Docker build (cached between deploys)
# See Dockerfile pattern above
```

Asset precompilation in the Docker build means it only runs when assets actually change (Docker layer caching). Running it during deploy adds minutes to every deployment.

## Pattern: Persistent storage for Active Storage uploads

```yaml
# config/deploy.yml
volumes:
  - "myapp_storage:/rails/storage"
```

User uploads (Active Storage with local disk) need a persistent volume. Without this, uploads are lost when the container restarts.

For multi-server deployments, use cloud storage (S3, GCS, R2) instead of local disk:

```ruby
# config/storage.yml
production:
  service: S3
  access_key_id: <%= ENV["AWS_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["AWS_SECRET_ACCESS_KEY"] %>
  bucket: myapp-uploads
  region: us-east-1
```
