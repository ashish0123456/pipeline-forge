# PipelineForge

PipelineForge is a CI/CD workflow automation platform that enables developers to define, trigger, and monitor multi-stage pipelines with dependency-aware job execution. Built with Ruby on Rails and PostgreSQL, it uses asynchronous processing, reliable execution, and production-oriented backend practices.

## Features

- Project, pipeline, and job management
- Multi-stage pipeline execution with job dependencies
- Durable pipeline and job execution tracking
- Background job processing with Sidekiq and Redis
- Job retries, failure handling, and cancellation
- Idempotent pipeline triggering
- Concurrent execution protection
- Execution logs and real-time status updates
- Authentication and project-level authorization
- Versioned REST API with pagination, filtering, and rate limiting
- PostgreSQL constraints, transactions, locking, and optimized indexes
- Redis-backed caching
- Audit logging and application monitoring
- Docker-based isolated job execution

## Technology Stack

| Category | Technology |
| --- | --- |
| Backend | Ruby 3.4.8, Ruby on Rails 8.1 |
| Database | PostgreSQL 15+ |
| Background Jobs | Sidekiq 8, Redis |
| Frontend | Rails Views, Hotwire, Turbo, Stimulus |
| Authentication | Rails `has_secure_password`, bcrypt |
| Authorization | Pundit |
| API | REST, JSON |
| Rate Limiting | Rack Attack |
| Caching | Rails Cache, Redis |
| Testing | Rails/Minitest |
| Code Quality & Security | RuboCop, Brakeman, Bundler Audit |
| Infrastructure | Docker, Docker Compose |

## Architecture

PipelineForge separates pipeline definitions from their execution history:

```text
Project
  └── Pipeline
       ├── Job
       ├── Job
       └── Job
            │
            ▼
       PipelineRun
          ├── JobRun
          │    └── ExecutionLog
          ├── JobRun
          │    └── ExecutionLog
          └── JobRun
               └── ExecutionLog
```

A `Pipeline` and its `Job` definitions describe what should run, while `PipelineRun` and `JobRun` represent a specific execution.

Sidekiq handles pipeline orchestration and job execution asynchronously. Dependencies determine when individual jobs become runnable, while PostgreSQL transactions, constraints, and row locking maintain consistent execution state.

Pipeline commands are executed separately from the Rails web process using isolated Docker containers with execution limits.

## Getting Started

### Prerequisites

- Docker
- Docker Compose

### Run with Docker

```bash
git clone https://gitlab.com/Ash3941/pipeline-forge.git
cd pipeline-forge

docker compose up --build
```

The application will be available at:

```text
http://localhost:3000
```

Create the initial administrator:

```bash
docker compose exec app bash -lc \
  'CI_SEED_ADMIN_PASSWORD="change-this-password" bundle exec rails db:seed'
```

Then sign in at:

```text
http://localhost:3000/login
```

Default administrator email:

```text
admin@example.com
```

The email can be customized using `CI_SEED_ADMIN_EMAIL`.

## API

PipelineForge provides a versioned REST API under `/api/v1`.

Example:

```text
GET /api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs
```

Execution-related endpoints include:

| Method | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs` | List pipeline runs |
| `GET` | `/api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs/:id` | View a pipeline run |
| `POST` | `/api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs/:id/retry` | Retry a pipeline run |
| `GET` | `/api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs/:pipeline_run_id/execution_logs` | View execution logs |
| `POST` | `/projects/:project_id/pipelines/:id/run` | Trigger a pipeline |

API requests use bearer-token authentication. Pipeline triggers support `Idempotency-Key` to prevent accidental duplicate executions.

## Database & Performance

PostgreSQL is used as the primary source of truth for pipeline and execution state.

The application uses:

- Foreign keys and database constraints
- Unique and composite indexes
- Partial indexes for active executions
- Transactions and row-level locking
- Eager loading to prevent N+1 queries
- Redis-backed caching for frequently accessed data
- PostgreSQL query analysis with `EXPLAIN ANALYZE`

The design keeps execution state durable and consistent while allowing background workers to safely process concurrent jobs.

## Testing

Run the test suite with:

```bash
bin/rails test
```

Run the application quality and security checks with:

```bash
bin/rubocop
bin/brakeman --quiet --no-pager
bin/bundler-audit
bin/rails zeitwerk:check
```

## License

This project is currently not licensed for redistribution.
