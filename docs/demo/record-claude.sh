#!/usr/bin/env bash
# Records docs/demo-claude.gif with vhs (brew install vhs): a test fails, then
# Claude Code, asked why, reads it through the oops plugin. Needs Claude Code
# signed in. It runs with your own Claude Code login but loads the plugin from
# this checkout, turns off hooks and the status line for the recording, and
# asks for short English replies, so your setup does not show in the GIF.
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
demo=/tmp/oops-demo-claude
app="$repo/tmp/demo-app"
ruby_bin=$(dirname "$(ruby -e 'puts RbConfig.ruby')")

rm -rf "$demo" "$app"
mkdir -p "$demo/state" "$app"

cat > "$demo/settings.json" <<'JSON'
{"disableAllHooks": true, "statusLine": {"type": "command", "command": "printf ''"}, "spinnerTipsEnabled": false}
JSON

cat > "$demo/bashrc" <<RC
export PATH="$repo/exe:$ruby_bin:\$PATH"
export XDG_STATE_HOME="$demo/state"
eval "\$(oops init bash)"
PS1='\[\e[32m\]\$\[\e[0m\] '
claude() {
  command claude --model sonnet --plugin-dir "$repo/claude-plugin" \\
    --settings "$demo/settings.json" \\
    --append-system-prompt "This session is being recorded for an English README demo: Reply in English, in two or three short sentences." "\$@"
}
RC

cat > "$app/user.rb" <<'RB'
class User
  def initialize(first, last) = (@first, @last = first, last)
  def full_name = @first
end
RB

cat > "$app/test_user.rb" <<'RB'
require "minitest/autorun"
require_relative "user"

class UserTest < Minitest::Test
  def test_full_name
    assert_equal "Taro Yamada", User.new("Taro", "Yamada").full_name
  end
end
RB

# Started from Claude Code, these would mark the demo as a child session.
cd "$repo" && env -u CLAUDECODE -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_SESSION_ID \
  -u CLAUDE_PID -u CLAUDE_CODE_ENTRYPOINT -u OOPS_SESSION -u OOPS_TTY \
  DEMO_RC="$demo/bashrc" DEMO_APP="$app" vhs docs/demo/claude.tape
