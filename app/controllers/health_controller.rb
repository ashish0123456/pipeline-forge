class HealthController < ApplicationController
    skip_before_action :authenticate_user!
    skip_forgery_protection

    def check
        ActiveRecord::Base.connection.execute("SELECT 1")
        redis_ok = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping == "PONG"
        render json: { status: "ok", database: "ok", redis: redis_ok ? "ok" : "failed" },
            status: redis_ok ? :ok : :service_unavailable
    rescue StandardError => error
        Rails.logger.error("Health check failed: #{error.class}: #{error.message}")
        render json: { status: "failed" }, status: :service_unavailable
    end
end
