Rails.application.config.middleware.use Rack::Attack
Rack::Attack.cache.store = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

class Rack::Attack
  throttle("api/ip", limit: 120, period: 60) do |request|
    request.ip if request.path.start_with?("/api/")
  end

  self.throttled_responder = lambda do |_env|
    [429, { "Content-Type" => "application/json", "Retry-After" => "60" }, [{ error: "Rate limit exceeded" }.to_json]]
  end
end
