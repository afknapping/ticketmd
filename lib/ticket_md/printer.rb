require 'io/console'

module TicketMD
  module Printer
    GREEN_CHECK = "\e[32m✓\e[0m"
    WARNING = "\e[33m⚠\e[0m"
    BOLD = "\e[1m"
    RESET = "\e[0m"
    ANSI_RE = /\e\[[0-9;]*m/.freeze
    ELLIPSIS = '…'
    ID_GAP = 3 # spaces guaranteed between a truncated title and its trailing ticket id

    # Numbering is always global (Repository#numbered_entries covers every
    # folder) so a ticket's number never changes with what's on screen.
    # `only` restricts which folders are shown at all (nil = all of them) -
    # used for the done-only exclusive view. `summarize` folders (eg.
    # "done" in the default view) show just a count instead of the
    # full list, to keep finished work from crowding out active work.
    def self.board(repo, width: terminal_width, only: nil, summarize: ['done'])
      entries = repo.numbered_entries
      lines = []
      visible_folders = only ? repo.folders.select { |f| only.include?(f.name) } : repo.folders
      visible_folders.each do |folder|
        if summarize.include?(folder.name)
          count = repo.tickets_in(folder).length
          lines << (count.positive? ? "#{folder.name.upcase} (#{count})" : folder.name.upcase)
          lines << '  (empty)' if count.zero?
        else
          lines << folder.name.upcase
          folder_entries = entries.select { |e| e.folder == folder }
          if folder_entries.empty?
            lines << '  (empty)'
          else
            folder_entries.each do |e|
              body = format('  %02d %s%s%s%s', e.index, mark_for(e.ticket), BOLD, e.ticket.title, RESET)
              lines << ticket_line(body, e.ticket.id, width)
            end
          end
        end
        lines << ''
      end
      lines = lines.map { |line| truncate(line, width) } if width
      lines.join("\n")
    end

    # Appends the ticket id at the end of the line, hashbang-style
    # (`#42`). When the line is too long for the terminal, the title is
    # truncated instead of the id, always leaving ID_GAP empty spaces
    # before it so the id stays legible and separated from the ellipsis.
    def self.ticket_line(body, id, width)
      suffix = "##{id}"
      full = "#{body} #{suffix}"
      return full unless width && width.positive? && visible_length(full) > width

      budget = [width - ID_GAP - suffix.length, 0].max
      "#{truncate(body, budget)}#{' ' * ID_GAP}#{suffix}"
    end

    def self.mark_for(ticket)
      marks = +''
      marks << "#{WARNING} " if ticket.question?
      marks << "#{GREEN_CHECK} " if ticket.ready?
      marks
    end

    # nil when stdout isn't a real terminal (piped output, etc.) - callers
    # should skip truncation in that case.
    def self.terminal_width
      $stdout.winsize[1]
    rescue StandardError
      nil
    end

    # Truncates by visible characters, so embedded ANSI escapes (eg. the
    # green checkmark, bold titles) don't get miscounted or split
    # mid-sequence. Always closes with RESET in case truncation lands
    # before a style's own closing code, which would otherwise bleed
    # bold/color into everything printed after this line.
    def self.truncate(line, width)
      return line if width <= 0 || visible_length(line) <= width

      target = [width - ELLIPSIS.length, 0].max
      result = +''
      visible = 0
      i = 0
      while i < line.length && visible < target
        m = line[i..].match(/\A#{ANSI_RE}/)
        if m
          result << m[0]
          i += m[0].length
        else
          result << line[i]
          visible += 1
          i += 1
        end
      end
      result + ELLIPSIS + RESET
    end

    def self.visible_length(line)
      line.gsub(ANSI_RE, '').length
    end
  end
end
