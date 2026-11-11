# PipelineForge

PipelineForge is a CI/CD workflow automation platform that enables developers to define, trigger, and monitor multi-stage pipelines with dependency-aware job execution. Built with Ruby on Rails and PostgreSQL, it uses asynchronous processing, reliable execution, and production-oriented backend practices.

## Features

- Project, pipeline, and job management
- Multi-stage pipeline execution with job dependencies
- Durable pipeline and job execution tracking
- Background job processing with Sidekiq and Redis
- Bounded job retries and failure handling
- Idempotent pipeline triggering
- Concurrent execution protection
- Per-job execution logs and status history
- Authentication and project-level authorization
- Versioned REST API with pagination, filtering, and rate limiting
- PostgreSQL constraints, transactions, locking, and optimized indexes
- Redis-backed caching
- Audit logging and application monitoring
- Docker-based isolated job execution

## Running a pipeline

For a manual run, add a public GitHub or GitLab HTTPS repository to a project, create at least one job with a command, then open the pipeline and enter a full 40-character commit SHA. The worker downloads that commit's source archive once and runs the pipeline's jobs against the same checkout. A run records its repository URL and SHA so its source revision is auditable. Open a run from the pipeline's run history to inspect each snapshotted command, status, exit code, and output.

The initial runner is intentionally bounded: archives are limited to 50 MiB compressed and 200 MiB extracted, a run is limited to 20 jobs, commands have a five-minute timeout, the total executor runtime is 15 minutes, and each job's persisted output is limited to 1 MiB by default. Each run snapshots its repository URL, commit SHA, job names, and commands. These limits can be adjusted with the `CI_*` settings in `.env.example`.

Execution requires Docker access for the Sidekiq worker. The Compose files mount the host Docker socket into that worker; Docker socket access is effectively host-admin access. Keep this personal demo limited to repositories and commands you trust, use a dedicated machine, set `DOCKER_GID` to the group ID that can access the Docker socket, and do not treat it as a public multi-tenant CI service. Job containers run without network access, so any dependencies a command needs must already be present in the selected executor image. The default `ruby:3.4.8-slim` image is a minimal Ruby environment, not a preconfigured Rails build image.

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

Compose reads the root `.env` file and passes its values into the app and worker containers. The app and worker use the Compose PostgreSQL service as their database host.

The application will be available at:

```text
http://localhost:3000
```

Set the admin credentials in `.env` before starting Compose:

```bash
CI_SEED_ADMIN_EMAIL=admin@example.com
CI_SEED_ADMIN_PASSWORD=choose-a-strong-local-password
```

On startup, the development app waits for PostgreSQL, prepares/migrates the database, runs the idempotent seed, then starts Rails. The admin password is passed only to the app container, not the Sidekiq worker. No separate seed command is needed:

```bash
docker compose up --build
```

Then sign in at:

```text
http://localhost:3000/login
```

Default administrator email:

```text
admin@example.com
```

The email can be customized using `CI_SEED_ADMIN_EMAIL`. In this development Compose setup, restarting the app applies the password currently in `.env` to that admin account. Do not copy this automatic password-seeding behavior into a production deployment; provision production admin credentials through a controlled one-time process instead.

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

API requests use bearer-token authentication. Pipeline triggers support `Idempotency-Key` to prevent accidental duplicate executions. Browser-triggered runs require a full commit SHA in the `commit_sha` form field; retries reuse the original run's SHA and repository URL.

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
