# Coverage is measured only when asked (CI uploads it to Codecov), so the usual
# test run stays as fast as before.
if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-cobertura"
  SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::CoberturaFormatter]
  SimpleCov.start { add_filter "/test/" }
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "oops"
require "stringio"
require "tmpdir"
