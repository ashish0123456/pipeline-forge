module Api
  module V1
    class PipelineRunsController < BaseController
      before_action :set_project
      before_action :set_pipeline
      before_action :set_run, only: [ :show, :retry ]

      def index
        runs = @pipeline.pipeline_runs.recent
        runs = runs.where(status: params[:status]) if PipelineRun.statuses.key?(params[:status].to_s)
        total = runs.count
        runs = runs.limit(per_page).offset((page - 1) * per_page)
        render json: { data: runs.map { |run| serialize(run) }, pagination: { page: page, per_page: per_page, total: total } }
      end

      def show
        render json: { data: serialize(@run, include_jobs: true) }
      end

      def retry
        authorize @project, :run?
        run = CreatePipelineRun.call(@pipeline, idempotency_key: "retry-#{@run.id}-#{SecureRandom.uuid}")
        render json: { data: serialize(run) }, status: :accepted
      end

      private

      def set_project
        @project = policy_scope(Project).find(params[:project_id])
        authorize @project, :show?
      end

      def set_pipeline
        @pipeline = @project.pipelines.find(params[:pipeline_id])
      end

      def set_run
        @run = @pipeline.pipeline_runs.find(params[:id])
      end

      def serialize(run, include_jobs: false)
        result = { id: run.id, pipeline_id: run.pipeline_id, status: run.status, created_at: run.created_at, started_at: run.started_at, finished_at: run.finished_at }
        result[:jobs] = run.job_runs.includes(:job).map { |job_run| { id: job_run.id, job_id: job_run.job_id, name: job_run.job.name, status: job_run.status, attempt: job_run.attempt, exit_code: job_run.exit_code } } if include_jobs
        result
      end
    end
  end
end
