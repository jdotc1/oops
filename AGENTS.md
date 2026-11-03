# Notes for AI coding agents

This file is for AI coding agents (Cursor, Codex, Claude Code and others) working on oops. It is a short version of [CONTRIBUTING.md](CONTRIBUTING.md); read that too, and follow it where the two differ.

## Before you start

- Comment on the issue before you start, so two people do not do the same work.
- Keep one change per pull request. For anything bigger than a small fix, agree on the approach in the issue first.

## Building and testing

- `bin/setup` installs the gems and runs the checks. It needs Ruby 3.3 or newer, zsh and bash.
- `bundle exec rake` runs the whole test suite and then rubocop. Run it before you open the pull request, not only a single test file.
- To try the change as a user would, follow "Try your changes" in the README's "Development" section: install your build and open a **new** terminal tab.
- Never run `oops record` in the terminal you are working in. The tests drive it through their own pty.

## Rules that are easy to miss

- Write the test first and watch it fail for the right reason.
- No runtime gem dependencies. Ruby 3.3 syntax at most. The bash snippet must work on macOS's bash 3.2.
- Masking must stay linear in the input size. Use only made-up tokens in tests, never real ones.
- Comments: the default is none. Follow "Comments" in CONTRIBUTING.md. Write them in English, and never add a `TODO`, change history or tool names.
- If you change `README.md` or `CHANGELOG.md`, make the same change in `README.ja.md` or `CHANGELOG.ja.md`. A user-visible change gets an entry under "Unreleased" in both changelogs.
- Commit messages and the pull request title use the form `type(scope): summary`, for example `feat(cli): add --print to write the text to stdout`.

## The pull request description

Use the sections of [.github/pull_request_template.md](.github/pull_request_template.md). `gh pr create --body` and similar tools skip the template, so copy its sections into the body yourself.

Fill "Verification" with real output, not a description of it:

1. The last line of `bundle exec rake test` for the whole suite (the `N runs, ... 0 failures` line).
2. The summary line of `bundle exec rubocop`.
3. For a change that affects behavior: the commands you ran in a new terminal tab with your build installed, and what they printed. For a docs-only change, write "docs only".

A pull request without these is sent back before review. Never paste session logs or anything private.
