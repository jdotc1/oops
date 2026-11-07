require "json"

module Oops
  # Turns captured records into the paste-ready clipboard text, or into JSON
  # for scripts and agents (#json).
  #
  # Per field (command line and output) the pipeline is: strip ANSI, scrub
  # invalid UTF-8, shorten the home directory to "~", mask secrets, apply the
  # config replace table. Output is then fenced.
  # With show_secrets, the home/mask/replace steps are skipped. With time, a
  # "# <local start time>" line precedes each command; with output_only, the
  # "$ command" line is left out.
  class Formatter
    GITHUB_COLLAPSE_LINES = 30

    # lines: output lines after formatting, summed over records.
    # command_line: the formatted first command, without "$ " or indentation.
    Result = Struct.new(:text, :lines, :masked_count, :command_line)

    TIME_FORMAT = "%Y-%m-%d %H:%M:%S %:z".freeze
    ISO_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S%:z".freeze

    def initialize(config:, home: Dir.home, show_secrets: false, github: false, time: false,
                   output_only: false)
      @config = config
      @home = home.to_s
      @show_secrets = show_secrets
      @github = github
      @time = time
      @output_only = output_only
      @masked = 0
    end

    def format(records)
      @masked = 0
      blocks = records.map { |record| build_block(record) }
      text = @github ? blocks.map { |b| github_block(b) }.join("\n") : plain_text(blocks)
      Result.new(text, blocks.sum { |b| b[:count] }, @masked, blocks.first&.dig(:command))
    end

    # The records as a pretty-printed JSON array, oldest first. Command, cwd
    # and output go through the same cleaning as the Markdown text; the
    # formatting options (github, time, output_only) do not apply. Times are
    # ISO 8601 in local time, or null when the record has none.
    def json(records)
      @masked = 0
      items = records.map { |record| json_item(record) }
      "#{JSON.pretty_generate(items)}\n"
    end

    private

    def build_block(record)
      command = clean(record.cmd.to_s).sub(/\s+\z/, "")
      shown = output_lines(clean(PromptSp.strip(record.output.to_s)))
      exit_code = record.exit
      exit_code = nil if exit_code.to_i.zero?
      stamp = start_time(record)
      body = []
      body << "# #{stamp}" if stamp
      body << "$ #{command.gsub("\n", "\n  ").gsub(/^ +$/, '')}" unless @output_only
      body.concat(shown)
      body << "(exit #{exit_code})" if exit_code
      { command: command, exit: exit_code, count: shown.size, time: stamp, content: body.join("\n") }
    end

    # Local time the command started, or nil without --time or for a record
    # that has no start time.
    def start_time(record)
      return nil unless @time && record.started_at

      Time.at(record.started_at.to_i).strftime(TIME_FORMAT)
    end

    def json_item(record)
      { command: clean(record.cmd.to_s).sub(/\s+\z/, ""),
        cwd: record.cwd && clean(record.cwd.to_s),
        exit: record.exit,
        started_at: iso_time(record.started_at),
        ended_at: iso_time(record.ended_at),
        output: output_lines(clean(PromptSp.strip(record.output.to_s))).join("\n") }
    end

    def iso_time(seconds)
      seconds && Time.at(seconds.to_i).strftime(ISO_TIME_FORMAT)
    end

    # Output lines without the trailing blank ones.
    def output_lines(text)
      lines = text.split("\n", -1)
      lines.pop while lines.any? && lines.last.strip.empty?
      lines
    end

    def clean(raw)
      text = Ansi.strip(raw.dup).force_encoding(Encoding::UTF_8).scrub
      return text if @show_secrets

      text = shorten_home(text)
      text, count = Secrets.mask(text, extra: @config.secrets)
      @masked += count
      apply_replace(text)
    end

    def shorten_home(text)
      return text if @home.empty? || @home == "/"

      text.gsub(/#{Regexp.escape(@home)}(?!\w)/, "~")
    end

    def apply_replace(text)
      keys = @config.replace.keys.reject(&:empty?).sort_by { |k| -k.length }
      return text if keys.empty?

      table = @config.replace
      text.gsub(Regexp.union(keys)) { |match| table[match] }
    end

    def plain_text(blocks)
      fenced(blocks.map { |b| b[:content] }.join("\n\n"), "")
    end

    def github_block(block)
      fence = fenced(block[:content], "console")
      return fence if block[:count] <= GITHUB_COLLAPSE_LINES

      parts = []
      parts << "exit #{block[:exit]}" if block[:exit]
      parts << "#{block[:count]} lines"
      parts << block[:time] if block[:time]
      summary = parts.join(", ")
      unless @output_only
        command = escape_html("$ #{block[:command]}".gsub("\n", " "))
        summary = "<code>#{command}</code> — #{summary}"
      end
      "<details>\n<summary>#{summary}</summary>\n\n#{fence}\n</details>\n"
    end

    def fenced(content, language)
      longest = content.scan(/`+/).map(&:length).max.to_i
      fence = "`" * [3, longest + 1].max
      return "#{fence}#{language}\n#{fence}\n" if content.empty?

      "#{fence}#{language}\n#{content}\n#{fence}\n"
    end

    def escape_html(text)
      text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
