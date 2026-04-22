---
name: sidekiq-performance
triggers:
  - sidekiq performance
  - sidekiq memory
  - sidekiq concurrency
  - connection pool
  - sidekiq slow
  - sidekiq optimize
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Performance

## Connection pool sizing

```yaml
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } + ENV.fetch("SIDEKIQ_CONCURRENCY") { 10 } %>
```

Each Sidekiq thread needs a database connection. If `concurrency: 10`, your database pool must be at least 10 (plus whatever your web process needs).

```yaml
# config/sidekiq.yml
:concurrency: <%= ENV.fetch("SIDEKIQ_CONCURRENCY", 10) %>
```

## Pattern: Bulk operations

```ruby
# BAD — 1000 individual Redis round-trips
users.each { |u| SendEmailJob.perform_later(u.id) }

# GOOD — bulk push
Sidekiq::Client.push_bulk(
  "class" => SendEmailJob,
  "args" => users.map { |u| [u.id] }
)

# Or with ActiveJob
SendEmailJob.perform_all_later(users.map { |u| SendEmailJob.new(u.id) })
```

`push_bulk` sends all jobs in a single Redis round-trip.

## Pattern: Memory-conscious jobs

```ruby
class LargeExportJob < ApplicationJob
  def perform(export_id)
    export = Export.find(export_id)

    # BAD — loads all records into memory
    # records = export.scope.to_a

    # GOOD — process in batches
    export.scope.find_each(batch_size: 1000) do |record|
      write_row(record)
    end
  end
end
```

## Pattern: Concurrency tuning

| Scenario | Concurrency | Rationale |
|---------|------------|-----------|
| CPU-bound jobs (PDF generation, image processing) | 2-4 per core | Limited by CPU |
| IO-bound jobs (API calls, email sending) | 10-25 | Threads wait on IO |
| Mixed workload | 10 (default) | Balanced |
| Memory-constrained (512 MB container) | 5 | Each thread uses ~50-100 MB |

```yaml
# config/sidekiq.yml
:concurrency: 10  # Adjust based on your workload
```

## Anti-pattern: Storing large data in job arguments

```ruby
# BAD — serializes CSV into Redis (could be megabytes)
ProcessCsvJob.perform_later(csv_content)

# GOOD — store in Active Storage or S3, pass the reference
csv_blob = ActiveStorage::Blob.create_and_upload!(io: csv_file, filename: "import.csv")
ProcessCsvJob.perform_later(csv_blob.id)
```

Sidekiq stores job arguments in Redis. Large arguments waste Redis memory and slow down serialization. Pass references (IDs, URLs, keys), not data.
