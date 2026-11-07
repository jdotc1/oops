require "open3"

module Oops
  # Uploads text as a secret gist through the GitHub CLI and returns its URL.
  # oops never talks to GitHub or touches a token itself; gh does both.
  module Gist
    class Error < StandardError; end

    FILENAME = "oops.md".freeze
    # Seconds to wait for gh; it has to reach GitHub, so this is longer than
    # the clipboard timeout.
    TIMEOUT = 30
    NO_GH = "--gist needs the GitHub CLI (gh). Install it from https://cli.github.com " \
            "and run  gh auth login  once.".freeze
    NOT_LOGGED_IN = "gh is not logged in to GitHub. Run  gh auth login  first.".freeze

    module_function

    # Returns the gist URL. Raises Error when gh is missing, not logged in,
    # fails, times out or prints no URL. env supplies PATH for finding gh.
    def create(text, description:, env: ENV, timeout: TIMEOUT)
      argv = ["gh", "gist", "create", "-", "--filename", FILENAME, "--desc", description]
      out, err, status = capture(argv, text, env, timeout)
      raise Error, failure_message(err) unless status.success?

      url = out.lines.map(&:strip).reverse.find { |line| line.start_with?("https://") }
      raise Error, "gh gist create printed no URL" if url.nil?

      url
    end

    def capture(argv, text, env, timeout)
      spawn_env = env["PATH"] ? { "PATH" => env["PATH"] } : {}
      Open3.popen3(spawn_env, *argv, pgroup: true) do |stdin, stdout, stderr, wait|
        readers = [Thread.new { stdout.read }, Thread.new { stderr.read }]
        begin
          stdin.write(text)
        rescue Errno::EPIPE
          nil
        end
        stdin.close
        unless wait.join(timeout)
          kill_group(wait.pid)
          readers.each(&:kill)
          raise Error, "gh timed out after #{timeout}s"
        end
        [readers[0].value.to_s, readers[1].value.to_s, wait.value]
      end
    rescue Errno::ENOENT
      raise Error, NO_GH
    rescue SystemCallError, IOError => e
      raise Error, "gh: #{e.message}"
    end

    def kill_group(pid)
      Process.kill("KILL", -pid)
    rescue SystemCallError
      nil
    end

    # gh asks for `gh auth login` when it has no usable token. Otherwise the
    # last line of its stderr holds the error; earlier lines are progress.
    def failure_message(err)
      return NOT_LOGGED_IN if err.match?(/gh auth login/)

      last = err.lines.map(&:strip).reject(&:empty?).last
      last ? "gh gist create failed: #{last}" : "gh gist create failed"
    end

    private_class_method :capture, :kill_group, :failure_message
  end
end
