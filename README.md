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

`.gitlab-ci.yml` runs the Rails test suite for merge requests and `main`. On `main`, it builds the production image and pushes both the commit SHA tag and `latest` to the GitLab Container Registry using GitLab's built-in registry variables.

The pipeline expects a GitLab Docker-in-Docker runner capable of privileged containers. Keep registry credentials and deployment credentials in protected GitLab CI/CD variables, never in the repository.

### Prerequisites

- Docker
- Docker Compose v2
- A GitLab project with Container Registry enabled for CI/CD

### Run with Docker

```bash
git clone https://gitlab.com/Ash3941/pipeline-forge.git
cd pipeline-forge
copy .env.example .env
# Edit .env and set RAILS_MASTER_KEY and CI_PLATFORM_DATABASE_PASSWORD.

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

Stop the local stack with:

```bash
docker compose down
```

To remove local database and Redis data as well, use `docker compose down -v`.

### Production deployment

The production Compose file runs the image published by the GitLab pipeline. Set these variables in the deployment environment before starting it:

```text
CI_REGISTRY_IMAGE=registry.gitlab.com/<group>/<project>
IMAGE_TAG=<commit SHA or latest>
RAILS_MASTER_KEY=<production Rails master key>
CI_PLATFORM_DATABASE_PASSWORD=<strong database password>
```

Log in to the GitLab Container Registry, then run:

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

The application listens on port `80`, and `/up` is the database and Redis health endpoint.

### CI/CD

`.gitlab-ci.yml` runs the Rails test suite for merge requests and `main`. On `main`, it builds the production image and pushes both the commit SHA tag and `latest` to the GitLab Container Registry using GitLab's built-in registry variables. No Docker Hub credentials are required.

The pipeline expects a GitLab Docker-in-Docker runner capable of privileged containers. Keep `RAILS_MASTER_KEY` and deployment credentials in protected GitLab CI/CD variables, never in the repository.

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

Run the same checks locally in the CI order with:

```bash
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager
bin/rails zeitwerk:check
```

## License

This project is currently not licensed for redistribution.
