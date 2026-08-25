namespace :db do
  namespace :query do
    desc "Analyze the recent pipeline runs query for a pipeline"
    task explain_pipeline_runs: :environment do
    pipeline_id = Integer(ENV.fetch("PIPELINE_ID"))
    sql = <<~SQL
      EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
      SELECT pipeline_runs.id, pipeline_runs.status, pipeline_runs.created_at
      FROM pipeline_runs
      WHERE pipeline_runs.pipeline_id = #{ActiveRecord::Base.sanitize_sql(pipeline_id)}
      ORDER BY pipeline_runs.created_at DESC
      LIMIT 50
    SQL

    puts ActiveRecord::Base.connection.select_values(sql)
    end
  end
end
