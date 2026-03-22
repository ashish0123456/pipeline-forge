class ExecutePipelineService
    def initialize(pipeline)
        @pipeline = pipeline
    end

    def call
        run_pipeline
    end

    private

    def run_pipeline
        Rails.logger.info "Starting execution of pipeline #{@pipeline.id} for project #{@pipeline.project.name}"
        @pipeline.update(status: :running)
        begin
            @pipeline.jobs.each do |job|
                run_job(job)
            end
            @pipeline.update(status: :success)
            Rails.logger.info "Pipeline #{@pipeline.id} completed successfully"
        rescue => e
            @pipeline.update(status: :failed)
            Rails.logger.error "Pipeline #{@pipeline.id} failed: #{e.message}"
            raise
        end
    end

    def run_job(job)
        Rails.logger.info "Running job #{job.id} (#{job.name})"
        job.update(status: :running)
        begin
            # Simulate job execution
            sleep(2)
            # In a real CI, this would run commands, e.g., system("bundle exec rspec")
            job.update(status: :completed)
            Rails.logger.info "Job #{job.id} completed successfully"
        rescue => e
            job.update(status: :failed)
            Rails.logger.error "Job #{job.id} failed: #{e.message}"
            raise
        end
    end
end