# How This Rails App Works: A Beginner's Guide

Welcome! This guide follows the real paths a request takes through this repository. Read it with the project open and follow the linked files as you go. The app is a CI platform: users organize **projects**, define **pipelines** made of **jobs**, start **pipeline runs**, and inspect the resulting status and logs.

## 1. The Rails picture in one minute

### MVC: Model, View, Controller

**MVC (Model–View–Controller)** is Rails' way of separating responsibilities:

- **Model:** Ruby objects and database behavior, such as `Project` and `Pipeline` in `app/models/`.
- **View:** the HTML shown to a browser, such as `app/views/projects/index.html.erb`.
- **Controller:** receives a request, loads or changes models, then chooses a response, such as `ProjectsController#index`.

A typical page request flows like this:

```text
Browser → config/routes.rb → controller → model/database → view → browser
```

A background action adds a worker:

```text
Browser → route → controller → service → database + job queue → worker → database/logs
```

### Convention over Configuration

**Convention over Configuration** means Rails assumes predictable names and locations so developers do not have to wire every connection by hand. For example, `ProjectsController#index` normally renders `app/views/projects/index.html.erb`; the plural controller name matches the plural view folder, and the action name matches the view file name. A model named `Project` normally uses the `projects` database table. These conventions are why following the file names usually reveals the request path.

### A few terms used below

- **Route:** a rule mapping an HTTP method and URL to a controller action.
- **Action:** a public controller method that handles one request.
- **Active Record:** Rails' model layer. It turns Ruby calls such as `@project.pipelines` into database queries and model objects.
- **Association:** a declared relationship between models, such as `has_many :pipelines`.
- **Strong Parameters:** controller-side filtering that allows only named request fields to be written.
- **Callback:** a method Rails automatically calls at a defined point in a model's life, such as after a database commit.
- **Validation:** a model rule checked before Rails saves a record.
- **Background job:** work put on a queue so a web request does not have to wait for it to finish.

## 2. First request: sign in

### When a visitor opens the sign-in page

Trace:

```text
GET /login
→ config/routes.rb: get "/login", to: "sessions#new"
→ SessionsController#new
→ app/views/sessions/new.html.erb
```

The `new` action is intentionally empty: Rails renders the matching sign-in template using the naming convention. The shared page frame, navigation, stylesheet, and JavaScript tags come from `app/views/layouts/application.html.erb`.

### When the user submits their email and password

Trace:

```text
POST /login
→ config/routes.rb: post "/login", to: "sessions#create"
→ SessionsController#create
→ User.find_by(...) and User#authenticate(...)
→ session[:user_id] is set
→ redirect to projects_path
```

`SessionsController` is an exception to the usual login gate: it skips `authenticate_user!` for `new` and `create`, otherwise a signed-out visitor could not reach the sign-in form. `create` trims and lowercases the email, looks up the user, checks the password through `has_secure_password`, resets the old session, and stores the authenticated user's ID in the new session. On a bad login it re-renders the form with an error.

**Rails concept — session:** a signed browser state Rails reads on later requests. Here, `session[:user_id]` lets the app find the signed-in user without asking for the password again.

**Rails concept — `has_secure_password`:** a Rails model feature used by `User` in `app/models/user.rb`. It stores a password digest (not the plain password) and provides the `authenticate` check used by the login action.

Relevant files: [config/routes.rb](config/routes.rb), [app/controllers/sessions_controller.rb](app/controllers/sessions_controller.rb), [app/models/user.rb](app/models/user.rb), [app/views/sessions/new.html.erb](app/views/sessions/new.html.erb), [app/views/layouts/application.html.erb](app/views/layouts/application.html.erb).

## 3. Every normal request: authentication and access checks

Most browser and API controllers inherit from `ApplicationController` in [app/controllers/application_controller.rb](app/controllers/application_controller.rb). Its `before_action :authenticate_user!` runs before the requested action.

**Rails concept — `before_action`:** a controller hook Rails runs before an action. This app uses it for shared work such as authentication and loading parent records.

`current_user` first checks the browser session. If there is no session user, it checks an `Authorization: Bearer ...` header with `ApiToken.authenticate`. For browser requests without a user, `authenticate_user!` redirects to `/login`; for JSON it returns `401 Unauthorized`.

Authentication answers **“Who are you?”** Authorization answers **“May you do this?”** This app uses Pundit policies for the second question. `ProjectPolicy` in [app/policies/project_policy.rb](app/policies/project_policy.rb) permits admins to access all projects, project members to view, and maintainers (or admins) to update and run pipelines. Controllers call `authorize` for a specific action and `policy_scope(Project)` to restrict which project rows may be found.

**Rails concept — policy scope:** a query-like permission filter. It is important to scope the database lookup itself, not just hide a button in the page.

## 4. Workflow: browse the projects dashboard

### When the user visits Projects

Trace:

```text
GET /projects (or GET /, which is the same page)
→ config/routes.rb: root "projects#index" and resources :projects
→ ApplicationController#authenticate_user!
→ ProjectsController#index
→ policy_scope(Project), includes(:pipelines), order(:name)
→ app/views/projects/index.html.erb (HTML)
→ app/views/layouts/application.html.erb
```

The controller action is in [app/controllers/projects_controller.rb](app/controllers/projects_controller.rb). It scopes records to the current user's allowed projects, loads pipelines along with them, orders the result, and caches the result briefly. `respond_to` also allows this action to return JSON when the request asks for JSON.

The dashboard is [app/views/projects/index.html.erb](app/views/projects/index.html.erb). Its `link_to` helpers build links such as `new_project_path` and project detail URLs. The view reads `@projects`, a controller instance variable made available to the matching template.

**Active Record concept — relation:** calls such as `policy_scope(Project).includes(:pipelines).order(:name)` build a database query. The query can be refined by chaining methods; Rails executes it when the records are needed. `includes` asks Rails to load related pipelines efficiently. In this action, the result is converted to an array before caching.

**Cache callback:** `Project`, `Pipeline`, and `Job` each use `after_commit :expire_project_cache`. After a successful database commit, this increments the projects index cache version, so later requests do not keep displaying an old cached list. `after_commit` runs after the transaction has been committed, not before.

## 5. Workflow: create a project

### When an admin clicks “New project” and submits the form

Form display:

```text
GET /projects/new
→ resources :projects creates the conventional new route
→ ProjectsController#new
→ Project.new and authorize @project
→ app/views/projects/new.html.erb
```

Form submission:

```text
POST /projects
→ resources :projects maps create requests to ProjectsController#create
→ project_params permits name and repository_url
→ Project.new(...) → Project#save → database
→ audit event → redirect to the project page (or re-render with errors)
```

The form uses `form_with` in [app/views/projects/new.html.erb](app/views/projects/new.html.erb). It submits fields named for the model. The action and parameter helpers are defined in [app/controllers/projects_controller.rb](app/controllers/projects_controller.rb).

**Rails concept — Strong Parameters:** `project_params` calls `params.require(:project).permit(:name, :repository_url)`. This requires a `project` form object and only allows those two fields to be saved. It prevents a request from changing fields the form was not meant to control.

**Rails concept — validation:** `Project` in [app/models/project.rb](app/models/project.rb) validates that `name` and `repository_url` are present and that the URL has an HTTP or HTTPS format. If the record is invalid, `save` returns false, errors are placed on the model, and the form displays them rather than saving.

**Rails concept — audit record:** successful create/update/delete actions call `record_audit!` from [app/controllers/concerns/auditable.rb](app/controllers/concerns/auditable.rb). It writes an `AuditEvent` containing the actor, action, record, request ID, IP address, and optional metadata.

**Permission detail:** creating a project requires `ProjectPolicy#create?`, which is admin-only. The create action creates the project itself; it does not automatically add the current user as a project membership. Membership records are represented by `ProjectMembership`.

### When the user views a project

```text
GET /projects/:id
→ ProjectsController#set_project (before_action; scoped lookup and authorization)
→ ProjectsController#show
→ app/views/projects/show.html.erb
```

`set_project` finds the project through `policy_scope(Project)` and authorizes it before `show` uses it. The page shows the repository and links into nested pipelines. Nested paths carry parent IDs so Rails knows which project's pipeline is being requested.

## 6. Workflow: create a pipeline

### When the user clicks “New Pipeline”

```text
GET /projects/:project_id/pipelines/new
→ nested resources :projects / :pipelines in config/routes.rb
→ PipelinesController#set_project (before_action; find and authorize project)
→ PipelinesController#new (requires project update permission)
→ @project.pipelines.new
→ app/views/pipelines/new.html.erb
```

Nested routes express ownership in the URL: a pipeline belongs to a project. The controller builds the new pipeline through `@project.pipelines`, which sets the parent relationship automatically.

### When the user submits the pipeline form

```text
POST /projects/:project_id/pipelines
→ PipelinesController#set_project
→ PipelinesController#create
→ pipeline_params permits name and status
→ @project.pipelines.new(...), with status set to pending
→ Pipeline#save → database → audit event
→ redirect to /projects/:project_id/pipelines/:id
```

The controller and form are [app/controllers/pipelines_controller.rb](app/controllers/pipelines_controller.rb) and [app/views/pipelines/new.html.erb](app/views/pipelines/new.html.erb). `Pipeline` in [app/models/pipeline.rb](app/models/pipeline.rb) belongs to one project, has many jobs and pipeline runs, and validates that its name is present.

**Active Record concept — `belongs_to` / `has_many`:** `belongs_to :project` means a pipeline row holds the project reference; `has_many :jobs` means Rails can find the jobs whose `pipeline_id` points to it. Associations support calls like `@project.pipelines` and `@pipeline.jobs`. `dependent: :destroy` asks Rails to destroy associated records when their parent is destroyed.

**Rails concept — enum:** `Pipeline` declares named states (`pending`, `running`, `success`, `failed`) for its `status`. Enums give convenient methods such as `pending?` while storing the state in the database.

## 7. Workflow: add a job to a pipeline

### When the user opens a pipeline's job list and adds a job

```text
GET /projects/:project_id/pipelines/:pipeline_id/jobs
→ JobsController#set_pipeline
→ JobsController#index → app/views/jobs/index.html.erb

GET /projects/:project_id/pipelines/:pipeline_id/jobs/new
→ JobsController#set_pipeline
→ JobsController#new → @pipeline.jobs.new
→ app/views/jobs/new.html.erb

POST /projects/:project_id/pipelines/:pipeline_id/jobs
→ JobsController#create
→ job_params permits name and status
→ @pipeline.jobs.create(...) → Job validations → database
→ redirect to job detail
```

See [app/controllers/jobs_controller.rb](app/controllers/jobs_controller.rb), [app/views/jobs/index.html.erb](app/views/jobs/index.html.erb), and [app/views/jobs/new.html.erb](app/views/jobs/new.html.erb). `set_pipeline` resolves the project and pipeline through their associations and checks project visibility. Creating or changing a job requires project update permission.

`Job` in [app/models/job.rb](app/models/job.rb) belongs to a pipeline and validates the name, maximum attempt count (1–10), and non-negative position. Its `ordered` scope sorts by position and then ID. It has many job runs; deleting a job with existing runs is restricted by `dependent: :restrict_with_error`.

The job form exposes name, command, and status. The command field is capped at 2,000 characters and is required; job execution does not silently treat an empty command as success.

## 8. Workflow: run a pipeline (the core lifecycle)

### When the user clicks “Run pipeline”

The pipeline detail template in [app/views/pipelines/show.html.erb](app/views/pipelines/show.html.erb) asks the user for a 40-character commit SHA, then submits a POST request.

Trace:

```text
POST /projects/:project_id/pipelines/:id/run
→ config/routes.rb: member { post :run } under project pipelines
→ PipelinesController#set_project and #set_pipeline
→ PipelinesController#run; authorize project :run?
→ CreatePipelineRun.call(@pipeline, commit_sha: ..., idempotency_key: ...)
→ transaction + pipeline row lock
→ create PipelineRun and one JobRun per ordered job
→ OrchestratePipelineJob.perform_async(run.id), after the transaction commits
→ respond 202 JSON or redirect to pipeline page
```

The route is a **member route** because it acts on one specific pipeline identified by `:id`. `button_to` creates a form for the POST request, rather than a plain link pretending to change data.

The business operation is in [app/services/create_pipeline_run.rb](app/services/create_pipeline_run.rb). A **service object** is a plain Ruby object used to keep a multi-step business operation out of the controller. This one:

1. Reuses a run with the same idempotency key if one already exists.
2. Locks the pipeline while checking and creating a run, so two requests do not both start one at the same time.
3. Rejects another pending/running run with `AlreadyRunning`.
4. Creates a `PipelineRun`, then a `JobRun` for each job in `@pipeline.jobs.ordered`.
5. Saves the source URL and commit SHA on the run, then enqueues `OrchestratePipelineJob` after the transaction commits.

An **idempotency key** is a request identifier that makes repeating the same request return the original run instead of creating a duplicate. The browser controller reads it from the `Idempotency-Key` header; if missing, the service makes a random one. A database unique index and locking provide additional protection.

**Rails concept — transaction and lock:** a transaction groups database changes so they succeed or roll back together. `with_lock` locks the pipeline row while its run is checked/created. The database also has a partial unique index limiting each pipeline to one pending or running run. This is a second layer of protection against concurrent requests.

### What happens after the web response

The web request returns quickly. One Sidekiq worker handles the run from source fetch through job completion:

```text
OrchestratePipelineJob#perform
→ marks PipelineRun running
→ ExecutePipelineRun.call
→ RepositoryArchive downloads the commit archive once
→ PipelineCommandExecutor starts one isolated Docker container
→ jobs run in configured/dependency order against the same checkout
→ save JobRun statuses, exit codes, and ExecutionLog rows
→ remove container and temporary files
→ mark PipelineRun successful or failed
```

Key files are [app/sidekiq/orchestrate_pipeline_job.rb](app/sidekiq/orchestrate_pipeline_job.rb), [app/services/execute_pipeline_run.rb](app/services/execute_pipeline_run.rb), [app/services/repository_archive.rb](app/services/repository_archive.rb), and [app/services/pipeline_command_executor.rb](app/services/pipeline_command_executor.rb).

`RepositoryArchive` supports public GitHub and GitLab repositories. It requires the project URL to use HTTPS, downloads the archive for the exact commit SHA, follows only a short list of HTTPS archive hosts, and enforces download-size, extracted-size, file-count, and timeout limits. It strips the archive's top-level folder and rejects unsafe paths, links, and other unsupported archive entries.

`ExecutePipelineRun` orders jobs by position while respecting `depends_on_ids`. It retries a failing command according to that job's `max_attempts`, stops the pipeline on terminal failure, and stores output incrementally with a per-job log-size limit. The pipeline runner uses one container for the run, so every job sees the same checked-out source tree. Commands run in a non-root user context, with networking disabled, a read-only root filesystem, bounded writable temporary directories, CPU/memory/process limits, and timeouts. The worker must be configured with Docker access; without it, runs fail clearly rather than running commands inside the Rails process.

**MVP tradeoff:** because the job container has no network, commands that need to download dependencies during the run will fail. Use an executor image with the needed tools/dependencies already present, or deliberately design a later controlled dependency-install step. Do not remove the network restriction casually; it limits what untrusted repository code can reach.

**Rails concept — background job:** a worker processes queued work outside the web request. Here, `include Sidekiq::Job` and `.perform_async(...)` are the Sidekiq enqueue/worker interface. A worker can take longer or retry without making the browser wait.

**Important distinction — definition vs. run:** `Pipeline` and `Job` are reusable definitions. `PipelineRun` and `JobRun` are the records for one execution attempt. Each run snapshots the repository URL, commit SHA, job name, and command, so editing the definition later does not rewrite what an existing run is meant to execute. Execution logs belong to a particular `JobRun`. That separation preserves history when the definition is run again.

Each run-history entry links to [app/views/pipeline_runs/show.html.erb](app/views/pipeline_runs/show.html.erb), handled by `PipelineRunsController#show`. That page shows the exact source revision and repository, plus each snapshotted command, status, exit code, and saved output.

The pipeline and job detail pages show the newest `PipelineRun` and `JobRun` statuses. Those values describe execution; the `Pipeline` and `Job` status fields belong to the reusable definitions and are not the source of truth for a particular run.

**Run identity:** each new run stores its full commit SHA and source URL. API retry requests reuse those saved values, so changing a project's repository URL later does not silently change the source for an existing run's retry.

### Where status and logs are persisted

The main associations are:

```text
Project has_many Pipelines
Pipeline belongs_to Project; has_many Jobs and PipelineRuns
PipelineRun belongs_to Pipeline; has_many JobRuns
JobRun belongs_to PipelineRun and Job; has_many ExecutionLogs
ExecutionLog belongs_to JobRun
```

The model declarations live in [app/models/project.rb](app/models/project.rb), [app/models/pipeline.rb](app/models/pipeline.rb), [app/models/job.rb](app/models/job.rb), [app/models/pipeline_run.rb](app/models/pipeline_run.rb), [app/models/job_run.rb](app/models/job_run.rb), and [app/models/execution_log.rb](app/models/execution_log.rb). The database structure is reflected in [db/schema.rb](db/schema.rb); migrations under [db/migrate](db/migrate) describe how it was built.

A **migration** is a versioned Ruby file that changes database structure. The schema is generated from migrations; normally edit/create a migration, not `db/schema.rb` by hand. The database schema also has foreign keys, unique indexes, and status/number constraints that protect data even if a request bypasses a model validation.

## 9. Hotwire, Turbo, and live status: what is present

**Hotwire** is a set of Rails tools for adding responsive behavior with less custom JavaScript. **Turbo** handles navigation and form submissions with page updates; **Stimulus** provides small JavaScript controllers. This app imports Turbo and Stimulus through Importmap in [app/javascript/application.js](app/javascript/application.js) and pins them in [config/importmap.rb](config/importmap.rb). The templates use Rails form/link helpers and a Turbo confirmation (`data: { turbo_confirm: ... }`) on the pipeline run button.

**Turbo Frames/Streams:** these are Hotwire tools for updating just part of a page or sending server-rendered updates. The current views do not show a Turbo Frame or a Turbo Stream subscription for pipeline status, so do not assume the visible status changes live without a page refresh.

The project does have an Action Cable channel, [app/channels/pipeline_runs_channel.rb](app/channels/pipeline_runs_channel.rb). `PipelineRun` and `JobRun` broadcast status updates from `after_update_commit` callbacks to `PipelineRunsChannel`. **Action Cable** is Rails' WebSocket feature for server-to-browser messages. The channel checks that the connecting user is an admin or a project member. However, the checked-in pipeline views do not subscribe to this channel, so the broadcast path exists but the current UI does not consume those broadcasts.

## 10. Workflow: call the JSON API

The API routes are grouped under `/api/v1` in [config/routes.rb](config/routes.rb). For example:

```text
GET  /api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs
GET  /api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs/:id
POST /api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs/:id/retry
GET  /api/v1/projects/:project_id/pipelines/:pipeline_id/pipeline_runs/:pipeline_run_id/execution_logs
POST /api/v1/api_tokens
```

A request to list runs follows:

```text
GET /api/v1/.../pipeline_runs
→ Api::V1::PipelineRunsController#index
→ policy-scoped project → associated pipeline → recent runs
→ optional status filter → page/per_page limit and offset
→ JSON response
```

`Api::V1::BaseController` inherits the same authentication and policy behavior, skips browser forgery protection for API requests, and provides bounded pagination helpers (`per_page` is capped at 100). `Api::V1::PipelineRunsController` in [app/controllers/api/v1/pipeline_runs_controller.rb](app/controllers/api/v1/pipeline_runs_controller.rb) also provides `show` and `retry`. The retry action calls `CreatePipelineRun` with a fresh key; it starts a new run rather than reusing the old run's job records. Logs are returned by `Api::V1::ExecutionLogsController#index` in [app/controllers/api/v1/execution_logs_controller.rb](app/controllers/api/v1/execution_logs_controller.rb).

### When an authenticated user creates an API token

```text
POST /api/v1/api_tokens with name (and optional expires_at)
→ Api::V1::ApiTokensController#create
→ ApiToken.issue!
→ persist token digest; return raw token once
```

`ApiToken` in [app/models/api_token.rb](app/models/api_token.rb) generates a random token and stores its SHA-256 digest. The raw token is included in the create response and should be saved by the client; later authentication hashes the bearer token and looks up the digest. The model tracks last use and rejects expired tokens. Treat the raw token like a password.

## 11. Validations, callbacks, and persistence at a glance

These are important Rails features you will meet repeatedly:

- **Validations** make the model reject invalid data before save. Examples: project name/URL in `Project`, pipeline name in `Pipeline`, job name/attempt count/position in `Job`, and unique membership per project/user in `ProjectMembership`.
- **Callbacks** run automatically at lifecycle moments. `Project`, `Pipeline`, and `Job` use `after_commit` to expire a cache version. `PipelineRun` and `JobRun` use `after_update_commit` to broadcast status.
- **Associations** define how records connect and let application code traverse them naturally. `dependent: :destroy` deletes certain owned records when the parent goes away; `dependent: :restrict_with_error` protects jobs that already have run history.
- **Database constraints** are a final guardrail. See indexes and check constraints in `db/schema.rb`; they help preserve consistency under concurrent requests as well as ordinary saves.

## 12. Files to explore next

- Request URL map: [config/routes.rb](config/routes.rb)
- Shared authentication and error handling: [app/controllers/application_controller.rb](app/controllers/application_controller.rb)
- Browser actions: [app/controllers/projects_controller.rb](app/controllers/projects_controller.rb), [app/controllers/pipelines_controller.rb](app/controllers/pipelines_controller.rb), [app/controllers/jobs_controller.rb](app/controllers/jobs_controller.rb)
- UI: [app/views/projects](app/views/projects), [app/views/pipelines](app/views/pipelines), [app/views/jobs](app/views/jobs)
- Core data rules: [app/models](app/models)
- Pipeline creation logic: [app/services/create_pipeline_run.rb](app/services/create_pipeline_run.rb)
- Async execution: [app/sidekiq/orchestrate_pipeline_job.rb](app/sidekiq/orchestrate_pipeline_job.rb), [app/services/execute_pipeline_run.rb](app/services/execute_pipeline_run.rb)
- Source fetch and command isolation: [app/services/repository_archive.rb](app/services/repository_archive.rb), [app/services/pipeline_command_executor.rb](app/services/pipeline_command_executor.rb)
- API: [app/controllers/api/v1](app/controllers/api/v1)
- Database history and current structure: [db/migrate](db/migrate), [db/schema.rb](db/schema.rb)
- Test suite: [test](test)

## 13. A few useful “follow the request” habits

When debugging, start from what you know:

1. Find the clicked helper in the `.erb` view and identify its URL and HTTP method.
2. Find that method/URL in `config/routes.rb`.
3. Open the controller action and any `before_action` that runs first.
4. Follow model associations and validations to understand the database effect.
5. If work is queued, follow the `.perform_async` call to the worker's `perform` method.
6. Check tests under `test/` to see expected behavior.

The current run route uses `CreatePipelineRun`, then one Sidekiq orchestration worker that invokes `ExecutePipelineRun`. That service fetches the commit archive and runs the jobs through `PipelineCommandExecutor`; older simulated execution paths have been removed to keep one clear execution flow.
