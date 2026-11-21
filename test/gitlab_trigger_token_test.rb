# frozen_string_literal: true

require "test_helper"

class GitlabTriggerTokenTest < Minitest::Test
  def mask(text) = Oops::Secrets.mask(text)

  def test_trigger_credentials_are_fully_redacted
    token = "glptt-#{'Ab3_' * 8}" # Synthetic value; not an issued credential.
    assert_equal ["[secret]", 1], mask(token)
    assert_equal ["trigger=[secret]", 1], mask("trigger=#{token}")
    assert_equal ["[secret]", 1], mask("glptt-#{'A' * 200}")
  end

  def test_shell_split_token_is_redacted
    assert_equal ["echo [secret]", 1], mask(%(echo glp"tt-#{'Ab3_' * 8}"))
  end

  def test_short_or_embedded_lookalikes_are_preserved
    token = "glptt-#{'Ab3_' * 8}"
    [
      "glptt-#{'A' * 19}",
      "glptt-example",
      "pre#{token}",
      "#{token}_suffix"
    ].each { |candidate| assert_equal [candidate, 0], mask(candidate) }
  end
end
