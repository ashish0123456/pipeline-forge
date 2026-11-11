class CreatePipelineRun
  class AlreadyRunning < StandardError; end

  def self.call(pipeline, idempotency_key:, commit_sha: nil, source_url: pipeline.project.repository_url)
    new(pipeline, idempotency_key, commit_sha, source_url).call
  end

  def initialize(pipeline, idempotency_key, commit_sha, source_url)
    @pipeline = pipeline
    @idempotency_key = idempotency_key.to_s.presence || SecureRandom.uuid
    @commit_sha = commit_sha.to_s.downcase
    @source_url = source_url
  end

  def call
    raise ArgumentError, "A full 40-character commit SHA is required" unless @commit_sha.match?(/\A[a-f0-9]{40}\z/)
    raise ArgumentError, "Add at least one job before running this pipeline" if @pipeline.jobs.empty?
    raise ArgumentError, "Pipelines are limited to 20 jobs" if @pipeline.jobs.count > 20
    raise ArgumentError, "Every job must have a command before this pipeline can run" if @pipeline.jobs.where(command: [ nil, "" ]).exists?

    run, created = PipelineRun.transaction(requires_new: true) do
      @pipeline.with_lock do
        existing_run = @pipeline.pipeline_runs.find_by(idempotency_key: @idempotency_key)
        next [ existing_run, false ] if existing_run

        if @pipeline.pipeline_runs.where(status: %w[pending running]).exists?
          raise AlreadyRunning
        end

        run = @pipeline.pipeline_runs.create!(
          idempotency_key: @idempotency_key,
          commit_sha: @commit_sha,
          source_url: @source_url
        )
        @pipeline.jobs.ordered.each do |job|
          run.job_runs.create!(job: job, command_snapshot: job.command, job_name_snapshot: job.name)
        end
        Rails.cache.delete("pipeline/#{@pipeline.id}/runs/v1")
        [ run, true ]
      end
    end
    OrchestratePipelineJob.perform_async(run.id) if created
    run
  rescue ActiveRecord::RecordNotUnique
    @pipeline.pipeline_runs.find_by!(idempotency_key: @idempotency_key)
  end
end
