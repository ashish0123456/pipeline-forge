class CommandExecutor
  Result = Data.define(:stdout, :stderr, :exit_code)

  def self.call(command)
    new(command).call
  end

  def initialize(command)
    @command = command.to_s.strip
  end

  def call
    raise ArgumentError, "command is blank" if @command.blank?
    raise "Container execution is not configured" unless ENV["CI_EXECUTOR"] == "docker"

    stdout, stderr, status = Timeout.timeout(Integer(ENV.fetch("CI_EXECUTOR_TIMEOUT", "900"))) do
      Open3.capture3(
        "docker", "run", "--rm", "--network", "none", "--cpus", "1", "--memory", "512m",
        "--read-only", "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m",
        ENV.fetch("CI_EXECUTOR_IMAGE", "ruby:3.4-slim"), "sh", "-lc", @command
      )
    end
    Result.new(stdout, stderr, status.exitstatus)
  end
end
