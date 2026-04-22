---
name: sidekiq-queues-priorities
triggers:
  - sidekiq queue
  - queue priority
  - queue weight
  - queue_as
  - sidekiq.yml queues
gems:
  - sidekiq
rails: ">=7.0"
---

# Sidekiq Queues & Priorities

## Pattern: Queue configuration

```yaml
# config/sidekiq.yml
:concurrency: 10
:queues:
  - [critical, 6]
  - [default, 3]
  - [low, 1]
```

Weights are relative. With weights 6:3:1, Sidekiq checks `critical` 6 times for every 1 time it checks `low`. This is probabilistic, not guaranteed ordering.

## Pattern: Assigning jobs to queues

```ruby
class BillingJob < ApplicationJob
  queue_as :critical

  def perform(invoice_id)
    Invoice.find(invoice_id).charge!
  end
end

class ReportGenerationJob < ApplicationJob
  queue_as :low

  def perform(report_id)
    Report.find(report_id).generate!
  end
end
```

## Pattern: Queue design by latency SLA

| Queue | Latency goal | Examples |
|-------|-------------|----------|
| `critical` | < 10 seconds | Payment processing, password resets, security alerts |
| `default` | < 1 minute | Email sending, notifications, webhook delivery |
| `low` | < 10 minutes | Report generation, data exports, analytics |
| `bulk` | < 1 hour | CSV imports, batch operations, cleanup tasks |

## Anti-pattern: Too many queues

```yaml
# BAD — one queue per job class, impossible to manage
:queues:
  - send_email
  - generate_report
  - sync_stripe
  - update_search_index
  - process_webhook
  - send_notification

# GOOD — 3-4 queues based on priority/latency
:queues:
  - [critical, 6]
  - [default, 3]
  - [low, 1]
```

More queues = more complexity and harder monitoring. Group by latency requirements, not by job type.

## Pattern: Strict ordering (non-weighted)

```yaml
# Process critical fully before touching default
:queues:
  - critical
  - default
  - low
# No weights = strict FIFO: critical drains completely before default starts
```

Use strict ordering when `critical` must fully drain before lower-priority work runs. Use weighted for fair scheduling.

## Pattern: Dedicated process for critical queues

```bash
# Process 1 — only critical work
bundle exec sidekiq -q critical -c 5

# Process 2 — everything else
bundle exec sidekiq -q default -q low -c 10
```

This ensures critical jobs always have dedicated workers, even when the default queue is backed up.
