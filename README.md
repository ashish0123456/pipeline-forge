# CI Platform

A Rails-based CI/CD platform for managing projects, pipelines, and jobs.

## Prerequisites

- Ruby 3.4.8
- PostgreSQL
- Redis
- Docker & Docker Compose (for containerized development)

## Local Development Setup

### Option 1: Native Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Set up environment variables:
   ```bash
   export CI_PLATFORM_DATABASE_USERNAME=your_db_user
   export CI_PLATFORM_DATABASE_PASSWORD=your_db_password
   ```

3. Create and migrate database:
   ```bash
   rails db:create
   rails db:migrate
   ```

4. Start Redis (if not running):
   ```bash
   redis-server
   ```

5. Start the application:
   ```bash
   rails server
   ```

6. Start Sidekiq for background jobs:
   ```bash
   bundle exec sidekiq
   ```

### Option 2: Docker Compose (Recommended)

1. Start all services:
   ```bash
   docker-compose up --build
   ```

2. The app will be available at http://localhost:3000

## Testing

Run the test suite:
```bash
rails test
```

## Production Deployment

### Using Docker Compose

1. Set environment variables:
   ```bash
   export DOCKERHUB_USERNAME=your_dockerhub_username
   export CI_PLATFORM_DATABASE_PASSWORD=your_db_password
   export RAILS_MASTER_KEY=your_master_key
   ```

2. Run production stack:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

### CI/CD with GitLab

The project includes GitLab CI/CD configuration (`.gitlab-ci.yml`) that:
- Runs tests
- Builds Docker image
- Pushes to DockerHub

Set these CI/CD variables in GitLab:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_PASSWORD`
- `CI_PLATFORM_DATABASE_PASSWORD` (for tests)

## API Endpoints

The application provides both HTML and JSON APIs:

- `GET /projects` - List projects
- `POST /projects` - Create project
- `GET /projects/:id` - Show project
- `PATCH /projects/:id` - Update project
- `DELETE /projects/:id` - Delete project
- `GET /projects/:project_id/pipelines` - List pipelines
- `POST /projects/:project_id/pipelines` - Create pipeline
- `POST /projects/:project_id/pipelines/:id/run` - Run pipeline
- And more...

## Architecture

- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq with Redis
- **Frontend**: Hotwire (Turbo/Stimulus)
- **Styling**: Custom CSS with variables
- **Containerization**: Docker
