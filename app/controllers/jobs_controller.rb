class JobsController < ApplicationController
    before_action :set_pipeline
    before_action :set_job, only: [:show, :edit, :update, :destroy]

    def set_pipeline
        @pipeline = policy_scope(Project).find(params[:project_id]).pipelines.find(params[:pipeline_id])
        authorize @pipeline.project, :show?
    end

    def set_job
        @job = @pipeline.jobs.find(params[:id])
    end

    def index
        @jobs = @pipeline.jobs
        respond_to do |format|
            format.html
            format.json { render json: @jobs }
        end
    end

    def show
        @job_run = @job.job_runs.includes(:execution_logs).order(created_at: :desc).first
        respond_to do |format|
            format.html
            format.json { render json: @job }
        end
    end

    def new
        authorize @pipeline.project, :update?
        @job = @pipeline.jobs.new
    end

    def edit
    end

    def create
        authorize @pipeline.project, :update?
        @job = @pipeline.jobs.create(job_params)
        respond_to do |format|
            if @job.persisted?
                format.html { redirect_to [@pipeline.project, @pipeline, @job], notice: "Job was successfully created." }
                format.json { render json: @job, status: :created }
            else
                format.html { render :new, status: :unprocessable_entity }
                format.json { render json: {errors: @job.errors.full_messages}, status: :unprocessable_entity }
            end
        end
    end

    def update
        authorize @pipeline.project, :update?
        respond_to do |format|
            if @job.update(job_params)
                format.html { redirect_to [@pipeline.project, @pipeline, @job], notice: "Job was successfully updated." }
                format.json { render json: @job }
            else
                format.html { render :edit, status: :unprocessable_entity }
                format.json { render json: {errors: @job.errors.full_messages}, status: :unprocessable_entity }
            end
        end
    end

    def destroy
        authorize @pipeline.project, :update?
        @job.destroy
        respond_to do |format|
            format.html { redirect_to project_pipeline_jobs_url(@pipeline.project, @pipeline), notice: "Job was successfully destroyed." }
            format.json { render json: { message: "Job deleted successfully" } }
        end
    end

    private

    def job_params
        params.require(:job).permit(:name, :status)
    end
end
