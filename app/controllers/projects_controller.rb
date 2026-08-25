class ProjectsController < ApplicationController
    include Auditable
    before_action :set_project, only: [:show, :edit, :update, :destroy]
    
    def set_project
        @project = policy_scope(Project).find(params[:id])
        authorize @project
    end

    # GET /projects
    def index
        cache_version = Rails.cache.fetch("projects/index/version", expires_in: 1.year) { 1 }
        cache_key = "projects/index/v2/#{cache_version}/user/#{current_user.id}"
        @projects = Rails.cache.fetch(cache_key, expires_in: 30.seconds) do
            Project.includes(:pipelines).order(:name).to_a
        end
        respond_to do |format|
            format.html
            format.json { render json: @projects }
        end
    end

    # GET /projects/:id
    def show
        respond_to do |format|
            format.html
            format.json { render json: @project }
        end
    end

    # GET /projects/new
    def new
        @project = Project.new
        authorize @project
    end

    # GET /projects/:id/edit
    def edit
        authorize @project, :update?
    end

    # POST /projects
    def create
        @project = Project.new(project_params)
        authorize @project

        respond_to do |format|
            if @project.save
                record_audit!("project.create", @project)
                format.html { redirect_to @project, notice: "Project was successfully created." }
                format.json { render json: @project, status: :created }
            else
                format.html { render :new, status: :unprocessable_entity }
                format.json { render json: {errors: @project.errors.full_messages}, status: :unprocessable_entity }
            end
        end
    end

    # PATCH /projects/:id
    def update
        authorize @project
        respond_to do |format|
            if @project.update(project_params)
                record_audit!("project.update", @project)
                format.html { redirect_to @project, notice: "Project was successfully updated." }
                format.json { render json: @project }
            else
                format.html { render :edit, status: :unprocessable_entity }
                format.json { render json: {errors: @project.errors.full_messages}, status: :unprocessable_entity }
            end
        end
    end

    # DELETE /projects/:id
    def destroy
        authorize @project
        @project.destroy
        record_audit!("project.destroy", @project)
        respond_to do |format|
            format.html { redirect_to projects_url, notice: "Project was successfully destroyed." }
            format.json { render json: {message: "Deleted #{@project.name} Successfully"} }
        end
    end

    private

    def project_params
        params.require(:project).permit(:name, :repository_url)
    end

end
