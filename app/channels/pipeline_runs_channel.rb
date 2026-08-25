class PipelineRunsChannel < ApplicationCable::Channel
  def subscribed
    run = PipelineRun.find(params[:pipeline_run_id])
    reject unless authorized?(run)
    stream_for run
  end

  private

  def authorized?(run)
    user = connection.current_user
    user&.admin? || user && ProjectMembership.exists?(project: run.pipeline.project, user: user)
  end
end
