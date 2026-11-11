require "open3"
require "shellwords"
require "securerandom"
require "timeout"

class PipelineCommandExecutor
  Result = Data.define(:stdout, :stderr, :exit_code)
  MAX_OUTPUT_BYTES = Integer(ENV.fetch("CI_EXECUTOR_MAX_OUTPUT_BYTES", 200_000))
  OPERATION_TIMEOUT = 120

  def initialize(source_path:, run_id:)
    @source_path = source_path
    @run_id = run_id
    @container_name = "ci-run-#{Integer(run_id)}-#{SecureRandom.hex(6)}"
    @image = ENV.fetch("CI_EXECUTOR_IMAGE", "ruby:3.4.8-slim")
    @command_timeout = Integer(ENV.fetch("CI_EXECUTOR_TIMEOUT", "300"))
    @run_timeout = Integer(ENV.fetch("CI_RUN_TIMEOUT", "900"))
    @workspace_limit = Integer(ENV.fetch("CI_EXECUTOR_WORKSPACE_BYTES", 200 * 1024 * 1024))
  end

  def execute(jobs)
    raise "Container execution is not configured" unless ENV["CI_EXECUTOR"] == "docker"

    @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @run_timeout
    ensure_image
    create_container
    start_container
    copy_source
    jobs.call(self)
  ensure
    remove_container
  end

  def run(command)
    remaining = (@deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)).ceil
    raise "Pipeline jobs exceeded the total runtime limit" unless remaining.positive?

    command_timeout = [ @command_timeout, remaining ].min
    shell_command = "timeout --signal=TERM --kill-after=5s #{command_timeout}s sh -lc #{Shellwords.escape(command)}"
    run_docker(
      "exec", "--user", "1000:1000", "--workdir", "/workspace",
      @container_name, "sh", "-lc", shell_command,
      timeout: command_timeout + OPERATION_TIMEOUT,
      check: false
    )
  end

  private

  def create_container
    run_docker(
      "create", "--name", @container_name,
      "--network", "none", "--cpus", "1", "--memory", "512m", "--pids-limit", "128",
      "--memory-swap", "512m", "--user", "1000:1000", "--read-only", "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
      "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m",
      "--tmpfs", "/workspace:rw,nosuid,nodev,size=#{@workspace_limit},uid=1000,gid=1000,mode=0770",
      @image, "sh", "-lc", "while :; do sleep 3600; done",
      timeout: OPERATION_TIMEOUT
    )
  end

  def ensure_image
    result = run_docker("image", "inspect", @image, timeout: OPERATION_TIMEOUT, check: false)
    return if result.exit_code.zero?

    run_docker("pull", @image, timeout: 600)
  end

  def start_container
    run_docker("start", @container_name, timeout: OPERATION_TIMEOUT)
  end

  def copy_source
    run_docker("cp", "--archive", "#{@source_path}/.", "#{@container_name}:/workspace", timeout: OPERATION_TIMEOUT)
  end

  def remove_container
    return unless @container_name

    run_docker("rm", "--force", @container_name, timeout: OPERATION_TIMEOUT, check: false, respect_deadline: false)
  rescue StandardError => error
    Rails.logger.warn("Could not remove job container #{@container_name}: #{error.message}")
    nil
  end

  def run_docker(*arguments, timeout:, check: true, respect_deadline: true)
    stdout = +""
    stderr = +""
    status = nil

    Open3.popen3("docker", *arguments) do |stdin, out, err, wait_thread|
      stdin.close
      out_thread = Thread.new { copy_limited(out, stdout) }
      err_thread = Thread.new { copy_limited(err, stderr) }
      begin
        remaining = @deadline && respect_deadline ? [ @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0 ].max : timeout
        status = Timeout.timeout([ timeout, remaining ].min) { wait_thread.value }
      rescue Timeout::Error
        terminate_process(wait_thread)
        raise
      ensure
        out_thread.join
        err_thread.join
      end
    end

    if check && !status&.success?
      raise "Container command failed: #{stderr.presence || stdout.presence || "exit status #{status&.exitstatus}"}"
    end

    Result.new(stdout, stderr, status.exitstatus)
  rescue Timeout::Error
    raise "Container command timed out"
  rescue Errno::ENOENT
    raise "Docker CLI is unavailable to the worker"
  end

  def copy_limited(io, output)
    truncated = false
    while (chunk = io.read(16 * 1024))
      remaining = MAX_OUTPUT_BYTES - output.bytesize
      if remaining.positive?
        output << chunk.byteslice(0, remaining)
      end
      truncated ||= chunk.bytesize > remaining
    end
    output << "\n[output truncated]" if truncated && output.bytesize < MAX_OUTPUT_BYTES + 32
  end

  def terminate_process(wait_thread)
    return if wait_thread.join(0)

    Process.kill("TERM", wait_thread.pid)
    return if wait_thread.join(2)

    Process.kill("KILL", wait_thread.pid)
    wait_thread.join
  rescue Errno::ESRCH
    nil
  end
end
