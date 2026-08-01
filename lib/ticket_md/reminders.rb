require 'open3'
require 'tempfile'

module TicketMD
  # Talks to macOS Reminders.app via AppleScript/osascript - there's no
  # other public CLI for it. First use triggers a one-time macOS
  # Automation permission prompt for whatever runs `tmd`.
  module Reminders
    class Error < StandardError; end

    def self.list_names
      run(%(tell application "Reminders" to get name of every list))
        .split(', ').map(&:strip).reject(&:empty?)
    end

    def self.create_list(name)
      run(%(tell application "Reminders" to make new list with properties {name:"#{escape(name)}"}))
    end

    # Incomplete reminders in `list_name`, as [{id:, name:}, ...].
    def self.reminders_in(list_name)
      script = <<~APPLESCRIPT
        tell application "Reminders"
          tell list "#{escape(list_name)}"
            set r to reminders whose completed is false
            set output to {}
            repeat with x in r
              set end of output to (id of x) & tab & (name of x)
            end repeat
          end tell
        end tell
        set AppleScript's text item delimiters to linefeed
        output as text
      APPLESCRIPT
      out = run(script)
      out.each_line(chomp: true).reject(&:empty?).map do |line|
        id, name = line.split("\t", 2)
        { id: id, name: name }
      end
    end

    def self.delete_reminder(id)
      run(%(tell application "Reminders" to delete (first reminder whose id is "#{escape(id)}")))
    end

    def self.run(script)
      Tempfile.create(['tmd-reminders', '.applescript']) do |f|
        f.write(script)
        f.flush
        out, err, status = Open3.capture3('osascript', f.path)
        raise Error, err.strip unless status.success?

        out.strip
      end
    end

    def self.escape(str)
      str.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
    end
  end
end
