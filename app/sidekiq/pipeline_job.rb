class PipelineJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(pipeline_id)
    pipeline = Pipeline.find(pipeline_id)
    CreatePipelineRun.call(pipeline, idempotency_key: "legacy-#{jid}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Pipeline not found: #{pipeline_id}"
  rescue => e
    Rails.logger.error "PipelineJob failed for #{pipeline_id}: #{e.message}"
    raise
  end
end
