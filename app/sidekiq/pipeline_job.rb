class PipelineJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(pipeline_id)
    Rails.logger.info "Processing Pipeline ##{pipeline_id}"

    pipeline = Pipeline.find(pipeline_id)
    ExecutePipelineService.new(pipeline).call

    Rails.logger.info "Completed Pipeline ##{pipeline_id}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Pipeline not found: #{pipeline_id}"
  rescue => e
    Rails.logger.error "PipelineJob failed for #{pipeline_id}: #{e.message}"
    raise
  end
end
