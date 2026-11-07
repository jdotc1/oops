require "test_helper"

class GistTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def gh(script, mode: 0o755)
    path = File.join(@dir, "gh")
    File.write(path, "#!/bin/sh\n#{script}\n")
    File.chmod(mode, path)
    { "PATH" => "#{@dir}:/usr/bin:/bin" }
  end

  def create(env, text: "text", timeout: 5)
    Oops::Gist.create(text, description: "d", env: env, timeout: timeout)
  end

  def test_returns_the_last_url_gh_prints
    env = gh('cat > /dev/null; echo "https://gist.github.com/a/1"; echo "https://gist.github.com/a/2"')
    assert_equal "https://gist.github.com/a/2", create(env)
  end

  def test_gh_that_hangs_is_killed_after_the_timeout
    env = gh("cat > /dev/null; sleep 30")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = assert_raises(Oops::Gist::Error) { create(env, timeout: 0.3) }
    assert_equal "gh timed out after 0.3s", error.message
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end

  # gh exits before reading stdin; writing a large text then hits a closed
  # pipe, which must not hide gh's own error.
  def test_gh_that_does_not_read_stdin
    env = gh('echo "HTTP 422: Validation Failed" >&2; exit 1')
    error = assert_raises(Oops::Gist::Error) { create(env, text: "x" * 1_000_000) }
    assert_equal "gh gist create failed: HTTP 422: Validation Failed", error.message
  end

  def test_gh_that_is_not_executable_counts_as_missing
    env = gh("exit 0", mode: 0o644)
    error = assert_raises(Oops::Gist::Error) { create(env) }
    assert_equal Oops::Gist::NO_GH, error.message
  end

  def test_other_spawn_errors_are_reported
    singleton = Open3.singleton_class
    singleton.alias_method(:__orig_popen3, :popen3)
    singleton.define_method(:popen3) { |*, **| raise Errno::E2BIG }
    error = assert_raises(Oops::Gist::Error) { create(gh("exit 0")) }
    assert_equal "gh: Argument list too long", error.message
  ensure
    singleton.remove_method(:popen3)
    singleton.alias_method(:popen3, :__orig_popen3)
    singleton.remove_method(:__orig_popen3)
  end

  def test_killing_a_finished_process_group_is_harmless
    pid = Process.spawn("true", pgroup: true)
    Process.wait(pid)
    assert_nil Oops::Gist.send(:kill_group, pid)
  end
end
