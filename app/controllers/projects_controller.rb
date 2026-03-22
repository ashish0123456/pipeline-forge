class ProjectsController < ApplicationController
    before_action :set_project, only: [:show, :edit, :update, :destroy]
    
    def set_project
        @project = Project.find(params[:id])
    end

    # GET /projects
    def index
        @projects = Project.all
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
    end

    # GET /projects/:id/edit
    def edit
    end

    # POST /projects
    def create
        @project = Project.new(project_params)

        respond_to do |format|
            if @project.save
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
        respond_to do |format|
            if @project.update(project_params)
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
        @project.destroy
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
