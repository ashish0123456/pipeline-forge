class PipelinesController < ApplicationController
    include Auditable
    before_action :set_project
    before_action :set_pipeline, only: [ :show, :edit, :update, :destroy, :run ]

    def set_project
        @project = policy_scope(Project).find(params[:project_id])
        authorize @project, :show?
    end

    def set_pipeline
        @pipeline = @project.pipelines.find(params[:id])
    end

    def index
        @pipelines = @project.pipelines
        respond_to do |format|
            format.html
            format.json { render json: @pipelines }
        end
    end

    def show
        authorize @project
        @pipeline = @project.pipelines.includes(jobs: { job_runs: :execution_logs }, pipeline_runs: { job_runs: :job }).find(params[:id])
        @recent_runs = @pipeline.pipeline_runs.recent.limit(8)
        @latest_run = @recent_runs.first
        respond_to do |format|
            format.html
            format.json { render json: @pipeline }
        end
    end

    def new
        authorize @project, :update?
        @pipeline = @project.pipelines.new
    end

    def edit
        authorize @project, :update?
    end

    def create
        authorize @project, :update?
        @pipeline = @project.pipelines.new(pipeline_params.merge(status: :pending))
        respond_to do |format|
            if @pipeline.save
                record_audit!("pipeline.create", @pipeline)
                format.html { redirect_to [ @project, @pipeline ], notice: "Pipeline was successfully created." }
                format.json { render json: @pipeline, status: :created }
            else
                format.html { render :new, status: :unprocessable_entity }
                format.json { render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity }
            end
        end
    end

    def run
        authorize @project, :run?
        run = CreatePipelineRun.call(
            @pipeline,
            idempotency_key: request.headers["Idempotency-Key"],
            commit_sha: params.require(:commit_sha)
        )
        record_audit!("pipeline.run", run, { pipeline_id: @pipeline.id })
        respond_to do |format|
            format.html { redirect_to [ @project, @pipeline ], notice: "Pipeline execution started." }
            format.json { render json: { id: run.id, status: run.status }, status: :accepted }
        end
    rescue CreatePipelineRun::AlreadyRunning
        respond_to do |format|
            format.html { redirect_to [ @project, @pipeline ], alert: "Pipeline is already running." }
            format.json { render json: { error: "Pipeline is already running" }, status: :conflict }
        end
        rescue ArgumentError, ActionController::ParameterMissing => error
            respond_to do |format|
                format.html { redirect_to [ @project, @pipeline ], alert: error.message }
                format.json { render json: { error: error.message }, status: :unprocessable_entity }
            end
    end

    def update
        authorize @project, :update?
        respond_to do |format|
            if @pipeline.update(pipeline_params)
                record_audit!("pipeline.update", @pipeline)
                format.html { redirect_to [ @project, @pipeline ], notice: "Pipeline was successfully updated." }
                format.json { render json: @pipeline }
            else
                format.html { render :edit, status: :unprocessable_entity }
                format.json { render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity }
            end
        end
    end

    def destroy
        authorize @project, :update?
        @pipeline.destroy
        record_audit!("pipeline.destroy", @pipeline)
        respond_to do |format|
            format.html { redirect_to project_pipelines_url(@project), notice: "Pipeline was successfully destroyed." }
            format.json { render json: { message: "Pipeline deleted successfully" } }
        end
    end

    private

    def pipeline_params
        params.require(:pipeline).permit(:name, :status)
    end
end
