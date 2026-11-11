# CI Platform Architecture Guide

This document explains how this Rails application works from startup to request processing, authentication, persistence, background jobs, and the CI/CD flow. It is written for a beginner, but it also maps the real files and responsibilities used in this project.

---

## 1. What this project is

This app is a lightweight CI/CD platform built with Ruby on Rails. Its main concepts are:

- Project: a repository or application being tracked
- Pipeline: a set of jobs for a project
- Job: an individual stage such as lint, test, or build
- PipelineRun: a run instance of a pipeline
- User: person who logs in and manages projects
- ApiToken: API authentication for non-browser clients

The important runtime pieces in this project are:

- Rails app server (Puma)
- PostgreSQL database
- Redis + Sidekiq for background jobs
- Rails controller/model/service layer for logic
- Pundit for authorization
- Rails cache for lightweight data caching

---

## 2. High-level architecture

At a high level, the application follows the standard Rails MVC pattern:

- Browser sends an HTTP request
- Rails router matches the URL to a controller action
- Controller checks authentication and authorization
- Models talk to the database through ActiveRecord
- Business logic may live in services or jobs
- Views render HTML or JSON
- Response goes back to the browser

The project then adds a pipeline orchestration layer so jobs can be executed asynchronously through Sidekiq.

---

## 3. Startup sequence: from process launch to app boot

### Entry point

Typical Rails startup begins with:

- [bin/rails](bin/rails)
- [config/application.rb](config/application.rb)
- [config/environment.rb](config/environment.rb)
- [config/boot.rb](config/boot.rb)

The real app startup flow is:

1. Ruby loads the app via Bundler.
2. [config/boot.rb](config/boot.rb) boots the environment.
3. [config/application.rb](config/application.rb) defines the Rails app module, loads defaults, and configures autoload behavior.
4. [config/environment.rb](config/environment.rb) initializes the application.
5. Railties load framework components like ActiveRecord, ActionController, ActiveJob, ActionCable, and the app’s initializers.
6. The app is ready to serve HTTP requests.

### Important config files

- [config/application.rb](config/application.rb): app-wide configuration and Rails version defaults
- [config/database.yml](config/database.yml): database connection settings for development, test, and production
- [config/environments/development.rb](config/environments/development.rb): development-specific config
- [config/environments/production.rb](config/environments/production.rb): production settings such as cache and job adapter
- [config/routes.rb](config/routes.rb): request URL definitions

---

## 4. Routing: how URLs become controller actions

All incoming requests are mapped first through the router in [config/routes.rb](config/routes.rb).

Examples from this project:

- GET /login -> `SessionsController#new`
- POST /login -> `SessionsController#create`
- DELETE /logout -> `SessionsController#destroy`
- GET /projects -> `ProjectsController#index`
- GET /projects/:id -> `ProjectsController#show`
- API routes under /api/v1/

The router decides which controller and action to run based on the URL path and HTTP method.

That means the flow is:

Browser request -> router -> controller action -> model/service -> response

---

## 5. The request lifecycle in practice

### Example request: visiting the projects page

Suppose the browser visits `/projects`.

1. The browser sends an HTTP GET request to the Puma server.
2. Rails receives the request and matches the route in [config/routes.rb](config/routes.rb).
3. The request hits `ProjectsController#index`.
4. The controller calls `ApplicationController#authenticate_user!` before the action runs.
5. If no valid user is in the session, the user is redirected to `/login`.
6. If signed in, the controller checks access with Pundit policy scopes.
7. The controller reads data from the database via ActiveRecord.
8. The view renders the HTML page and sends it back to the browser.

### Example request: creating a project

- Request goes to `ProjectsController#create`
- `project_params` extracts only allowed fields
- `Project.new` creates a new model instance
- `authorize @project` checks policy
- `@project.save` writes to PostgreSQL
- On success, redirect or JSON response is returned

---

## 6. Authentication and session flow

### Why authentication exists

This app requires login for most routes. This is enforced centrally in [app/controllers/application_controller.rb](app/controllers/application_controller.rb).

Key behavior:

- `before_action :authenticate_user!`
- If there is no valid current user, the request is redirected or rejected with JSON error
- `current_user` uses the session or bearer token to identify the user

### Session-based login

The login flow is handled by [app/controllers/sessions_controller.rb](app/controllers/sessions_controller.rb).

When a user submits email/password:

1. `User.find_by(email: ...)` looks up the user
2. `user.authenticate(password)` verifies the hashed password
3. `session[:user_id] = user.id` stores the login state
4. The browser continues with the authenticated session

The model in [app/models/user.rb](app/models/user.rb) defines:

- `has_secure_password` for secure password hashing
- `normalizes :email` to lowercase and strip whitespace
- validations for email format and uniqueness

The user is persisted in the database and used for `current_user` checks in every request.

### API token authentication

This app also supports API requests using bearer tokens.

The authentication logic is:

- `ApplicationController#current_user`
- `ApiToken.authenticate(...)`
- [app/models/api_token.rb](app/models/api_token.rb)

This allows clients to send a token in the `Authorization` header and receive user context without a browser session.

---

## 7. Authorization with Pundit

This app uses Pundit for permission checks, not just login checks.

- [app/controllers/application_controller.rb](app/controllers/application_controller.rb) embeds `Pundit::Authorization`
- [app/policies/project_policy.rb](app/policies/project_policy.rb) defines project access rules

### Example rule

`ProjectPolicy` defines rules such as:

- admins can do everything
- maintainers can update or manage a project
- members can view project data

Authorization is applied in controllers like:

- `authorize @project`
- `policy_scope(Project)`

### Why this matters

The app does not trust the controller alone. Before any action is executed, the project-level policy decides whether the current user is allowed to do the action.

---

## 8. Models and database flow

This project uses ActiveRecord, which is Rails’ ORM layer.

### Database config

[config/database.yml](config/database.yml) defines connection details for:

- development
- test
- production

The config includes PostgreSQL adapter settings and environment variables such as:

- `CI_PLATFORM_DATABASE_USERNAME`
- `CI_PLATFORM_DATABASE_PASSWORD`
- `CI_PLATFORM_DATABASE_HOST`

This is how Rails knows where the database lives and how to connect.

### Core models

- [app/models/project.rb](app/models/project.rb): project entity with validations and cache invalidation
- [app/models/pipeline.rb](app/models/pipeline.rb): pipeline definition and status
- [app/models/job.rb](app/models/job.rb): job definition and ordering
- [app/models/user.rb](app/models/user.rb): user identity and auth state
- [app/models/api_token.rb](app/models/api_token.rb): API access tokens
- [app/models/project_membership.rb](app/models/project_membership.rb): join model between user and project
- [app/models/pipeline_run.rb](app/models/pipeline_run.rb): actual execution record of a pipeline
- [app/models/job_run.rb](app/models/job_run.rb): individual execution record for a job

### ActiveRecord behavior

When a controller asks for data:

- Rails builds SQL from model associations and scopes
- PostgreSQL receives the query
- ActiveRecord converts rows into Ruby model objects
- Results are used in the controller and view

For example, `Project.includes(:pipelines)` loads the project and its pipelines efficiently, and `policy_scope(Project)` limits which projects the current user can see.

---

## 9. Important controller logic: ProjectsController

[app/controllers/projects_controller.rb](app/controllers/projects_controller.rb) is a good example of the app’s MVC flow.

### The `index` action

This action:

1. Builds a cache version string
2. Uses `Rails.cache.fetch` to store a project list for a short time
3. Uses `policy_scope(Project)` to limit records to the current user
4. Orders projects by name
5. Returns either HTML or JSON

This pattern improves performance and prevents a user from seeing data they should not access.

### Cache invalidation

The project and pipeline models call `after_commit` hooks to update a cache version value.

This is a simple way to invalidate list caches whenever a project or pipeline changes.

---

## 10. Background jobs and the CI execution flow

This project includes a pipeline runner pattern that is very common in CI systems.

### Core execution model

- [app/services/create_pipeline_run.rb](app/services/create_pipeline_run.rb) creates a new run for a pipeline
- [app/sidekiq/orchestrate_pipeline_job.rb](app/sidekiq/orchestrate_pipeline_job.rb) starts the orchestration work in the background
- [app/services/repository_archive.rb](app/services/repository_archive.rb) downloads a bounded archive for a public GitHub or GitLab commit
- [app/services/execute_pipeline_run.rb](app/services/execute_pipeline_run.rb) sequences the run's jobs and records logs and statuses
- [app/services/pipeline_command_executor.rb](app/services/pipeline_command_executor.rb) runs commands in a constrained Docker container

### Example runtime flow

1. A user triggers a pipeline run.
2. `CreatePipelineRun.call` checks whether the pipeline is already running.
3. It creates a `PipelineRun` record and a `JobRun` for each job.
4. It enqueues `OrchestratePipelineJob` with Sidekiq.
5. The Sidekiq worker fetches the commit's repository archive once.
6. It starts one isolated container and copies the source into its bounded workspace.
7. Jobs run against that checkout in configured/dependency order, with bounded retries and logs.
8. The worker removes temporary data and saves the final pipeline status.

This is an important architectural choice: the web request does not block on long-running CI execution. Instead, it creates database records and returns quickly while background workers do the heavy work.

---

## 11. Redis, Sidekiq, and queueing

This app depends on Redis and Sidekiq for asynchronous work.

Typical roles:

- Redis stores Sidekiq jobs and caches
- Sidekiq processes background tasks
- ActiveJob is configured to use Sidekiq in production

This is important because pipeline execution can take time; the web request should not freeze while jobs run.

---

## 12. Views and UI rendering

The frontend uses Rails standard views and the built-in asset pipeline/import map flow.

Typical files include:

- [app/views/projects](app/views/projects)
- [app/views/layouts](app/views/layouts)
- [app/views/sessions](app/views/sessions)

Rails automatically finds views that match controller names and action names. For example:

- `ProjectsController#index` will render the view under `app/views/projects/index.html.erb`
- `SessionsController#new` renders a login page

The app is not a single-page JavaScript app; it is traditional server-rendered Rails view code with HTML pages that can also return JSON.

---

## 13. Request flow end-to-end

Here is the full path of a browser request in plain English:

1. The browser asks for a URL.
2. Puma receives the request.
3. Rails loads the app and matches the route.
4. `ApplicationController` runs authentication checks.
5. The specific controller action executes.
6. The controller authorizes access using Pundit.
7. Model methods and ActiveRecord queries fetch or update data in PostgreSQL.
8. For slow work, Sidekiq/Redis may be used in the background.
9. The controller selects a response format.
10. A view renders HTML or a JSON payload is returned.
11. The browser displays the result.

In database terms, the app follows this cycle:

Browser -> Router -> Controller -> Policy -> Model -> ActiveRecord -> PostgreSQL -> Ruby object -> View -> Browser

---

## 14. Security and correctness principles in this app

This project uses several good Rails patterns:

- `before_action` authentication in the base controller
- authorization through Pundit
- parameter filtering with `params.require(...).permit(...)`
- protection from CSRF using `protect_from_forgery`
- environment-based configuration via variables
- model-level validation before saves
- cache invalidation when entities change

These are standard, production-minded patterns that make the app safer and easier to maintain.

---

## 15. CI/CD and deployment footprint

The repository also contains the infrastructure pieces for deployment and automation:

- [docker-compose.yml](docker-compose.yml): local app stack
- [docker-compose.prod.yml](docker-compose.prod.yml): production-style compose stack
- [Dockerfile](Dockerfile): container image definition
- [.gitlab-ci.yml](.gitlab-ci.yml): pipeline for CI and image publishing

This tells us the application is designed to run in a containerized environment with a PostgreSQL database and Redis service. The CI pipeline is intended to:

- run tests
- build a Docker image
- push it to a registry

This matches the project’s purpose as a Rails service with background processing.

---

## 16. Summary for beginners

If you are new to Rails, the easiest mental model is this:

- Rails is a framework that maps HTTP requests to Ruby code.
- Controllers are the entry point for requests.
- Models represent database entities and business rules.
- ActiveRecord translates Ruby code into SQL.
- Views render the final HTML.
- Sessions and tokens handle authentication.
- Policies decide whether the user can access something.
- Background jobs handle work that should not block the user.
- PostgreSQL stores the app’s durable data.
- Redis powers caching and background job queues.

This project is a classic Rails application with a CI/CD flavor: it manages projects and pipelines, enforces access control, persists state in PostgreSQL, and uses Sidekiq to execute pipeline jobs asynchronously.

---

## 17. Quick file map

Here is a simple map of the most important code:

- [config/routes.rb](config/routes.rb): URL routing
- [app/controllers/application_controller.rb](app/controllers/application_controller.rb): shared auth and base logic
- [app/controllers/sessions_controller.rb](app/controllers/sessions_controller.rb): login/logout
- [app/controllers/projects_controller.rb](app/controllers/projects_controller.rb): project CRUD with caching
- [app/policies/project_policy.rb](app/policies/project_policy.rb): access control rules
- [app/models/user.rb](app/models/user.rb): user authentication model
- [app/models/api_token.rb](app/models/api_token.rb): token-based API auth
- [app/models/project.rb](app/models/project.rb): project entity
- [app/models/pipeline.rb](app/models/pipeline.rb): pipeline entity
- [app/models/job.rb](app/models/job.rb): job definition
- [app/services/create_pipeline_run.rb](app/services/create_pipeline_run.rb): pipeline run creation
- [app/sidekiq/orchestrate_pipeline_job.rb](app/sidekiq/orchestrate_pipeline_job.rb): background orchestration
- [app/services/repository_archive.rb](app/services/repository_archive.rb): bounded public repository archive fetch
- [app/services/execute_pipeline_run.rb](app/services/execute_pipeline_run.rb): job order, retries, and log persistence
- [app/services/pipeline_command_executor.rb](app/services/pipeline_command_executor.rb): isolated Docker command execution
- [config/database.yml](config/database.yml): database connection setup
- [docker-compose.yml](docker-compose.yml): local service orchestration
- [.gitlab-ci.yml](.gitlab-ci.yml): CI/CD pipeline

This file map should help you navigate the application once you start reading the code in the project.
