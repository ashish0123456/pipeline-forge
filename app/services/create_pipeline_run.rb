class CreatePipelineRun
  class AlreadyRunning < StandardError; end

  def self.call(pipeline, idempotency_key:)
    new(pipeline, idempotency_key).call
  end

  def initialize(pipeline, idempotency_key)
    @pipeline = pipeline
    @idempotency_key = idempotency_key.to_s.presence || SecureRandom.uuid
  end

  def call
    PipelineRun.transaction(requires_new: true) do
      @pipeline.with_lock do
        existing_run = @pipeline.pipeline_runs.find_by(idempotency_key: @idempotency_key)
        return existing_run if existing_run

        if @pipeline.pipeline_runs.where(status: %w[pending running]).exists?
          raise AlreadyRunning
        end

        run = @pipeline.pipeline_runs.create!(idempotency_key: @idempotency_key)
        @pipeline.jobs.ordered.find_each do |job|
          run.job_runs.create!(job: job)
        end
        OrchestratePipelineJob.perform_async(run.id)
        Rails.cache.delete("pipeline/#{@pipeline.id}/runs/v1")
        run
      end
    end
  rescue ActiveRecord::RecordNotUnique
    @pipeline.pipeline_runs.find_by!(idempotency_key: @idempotency_key)
  end
end
