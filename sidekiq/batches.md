---
name: sidekiq-batches
triggers:
  - sidekiq batch
  - batch callback
  - sidekiq pro batch
  - parallel jobs
  - job coordination
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Batches (Sidekiq Pro)

Batches group related jobs and fire callbacks when all jobs in the batch complete. Requires Sidekiq Pro.

## Pattern: Basic batch

```ruby
batch = Sidekiq::Batch.new
batch.description = "Import users from CSV"
batch.on(:complete, ImportCallbacks, import_id: import.id)
batch.on(:success, ImportCallbacks, import_id: import.id)

batch.jobs do
  csv_rows.each_slice(100).with_index do |chunk, i|
    ImportChunkJob.perform_async(import.id, i, chunk)
  end
end
```

```ruby
class ImportCallbacks
  def on_complete(status, options)
    import = Import.find(options["import_id"])
    import.update!(status: "complete", 
                   total: status.total,
                   failures: status.failures)
  end

  def on_success(status, options)
    import = Import.find(options["import_id"])
    ImportMailer.success(import).deliver_later
  end
end
```

## Callbacks

| Callback | When it fires |
|----------|--------------|
| `on(:complete)` | All jobs finished (success or failure) |
| `on(:success)` | All jobs succeeded (no failures) |
| `on(:death)` | A job in the batch exhausted all retries |

## Pattern: Nested batches

```ruby
parent = Sidekiq::Batch.new
parent.on(:success, FinalCallback)

parent.jobs do
  # Child batch 1: process images
  child1 = Sidekiq::Batch.new
  child1.jobs do
    images.each { |img| ProcessImageJob.perform_async(img.id) }
  end

  # Child batch 2: process metadata
  child2 = Sidekiq::Batch.new
  child2.jobs do
    records.each { |r| ProcessMetadataJob.perform_async(r.id) }
  end
end

# FinalCallback fires when BOTH child batches complete
```

## Alternative without Sidekiq Pro

For open-source Sidekiq, coordinate with a counter:

```ruby
class BatchCoordinator
  def self.start(batch_id, total_jobs)
    Rails.cache.write("batch:#{batch_id}:total", total_jobs)
    Rails.cache.write("batch:#{batch_id}:completed", 0)
  end

  def self.job_completed(batch_id)
    completed = Rails.cache.increment("batch:#{batch_id}:completed")
    total = Rails.cache.read("batch:#{batch_id}:total")

    if completed >= total
      BatchCompleteJob.perform_later(batch_id)
    end
  end
end
```

This is less robust than Sidekiq Pro batches (no retry tracking, no nested batches) but handles simple coordination.
