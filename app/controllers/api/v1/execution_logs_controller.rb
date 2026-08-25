module Api
  module V1
    class ExecutionLogsController < BaseController
      def index
        project = policy_scope(Project).find(params[:project_id])
        authorize project, :show?
        run = project.pipelines.find(params[:pipeline_id]).pipeline_runs.find(params[:pipeline_run_id])
        logs = run.execution_logs.order(:job_run_id, :sequence)
        render json: { data: logs.map { |log| { id: log.id, job_run_id: log.job_run_id, sequence: log.sequence, content: log.content, created_at: log.created_at } } }
      end
    end
  end
end
