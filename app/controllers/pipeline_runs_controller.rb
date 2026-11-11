class PipelineRunsController < ApplicationController
  before_action :set_project
  before_action :set_pipeline
  before_action :set_pipeline_run

  def show
    @job_runs = @pipeline_run.job_runs.includes(:execution_logs).order(:id)
  end

  private

  def set_project
    @project = policy_scope(Project).find(params[:project_id])
    authorize @project, :show?
  end

  def set_pipeline
    @pipeline = @project.pipelines.find(params[:pipeline_id])
  end

  def set_pipeline_run
    @pipeline_run = @pipeline.pipeline_runs.find(params[:id])
  end
end
