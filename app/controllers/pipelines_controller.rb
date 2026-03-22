class PipelinesController < ApplicationController
    before_action :set_project
    before_action :set_pipeline, only: [:show, :edit, :update, :destroy]

    def set_project
        @project = Project.find(params[:project_id])
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
        respond_to do |format|
            format.html
            format.json { render json: @pipeline }
        end
    end

    def new
        @pipeline = @project.pipelines.new
    end

    def edit
    end

    def create
        @pipeline = @project.pipelines.new(pipeline_params.merge(status: :pending))
        respond_to do |format|
            if @pipeline.save
                format.html { redirect_to [@project, @pipeline], notice: "Pipeline was successfully created." }
                format.json { render json: @pipeline, status: :created }
            else
                format.html { render :new, status: :unprocessable_entity }
                format.json { render json: {errors: @pipeline.errors.full_messages}, status: :unprocessable_entity }
            end
        end
    end

    def run
        if @pipeline.pending? || @pipeline.failed?
            @pipeline.update(status: :running)
            PipelineJob.perform_async(@pipeline.id)
            respond_to do |format|
                format.html { redirect_to [@project, @pipeline], notice: "Pipeline execution started." }
                format.json { render json: { message: "Pipeline execution started" }, status: :ok }
            end
        else
            respond_to do |format|
                format.html { redirect_to [@project, @pipeline], alert: "Pipeline cannot be run in current state." }
                format.json { render json: { error: "Pipeline cannot be run in current state" }, status: :unprocessable_entity }
            end
        end
    end

    def update
        respond_to do |format|
            if @pipeline.update(pipeline_params)
                format.html { redirect_to [@project, @pipeline], notice: "Pipeline was successfully updated." }
                format.json { render json: @pipeline }
            else
                format.html { render :edit, status: :unprocessable_entity }
                format.json { render json: {errors: @pipeline.errors.full_messages}, status: :unprocessable_entity }
            end
        end
    end

    def destroy
        @pipeline.destroy
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
