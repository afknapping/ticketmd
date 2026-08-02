require 'io/console'
require_relative 'printer'
require_relative 'reminders'
require_relative 'github'

module TicketMD
  class Interactive
    CLEAR = "\e[H\e[2J"
    QUIT_KEYS = ['q', nil, "\u0003", "\u0004"].freeze
    # Cancels an in-progress sub-flow without quitting the whole app -
    # everything QUIT_KEYS cancels, plus Escape.
    CANCEL_KEYS = (QUIT_KEYS + ["\e"]).freeze
    BACKSPACE_KEYS = ["\u007f", "\b"].freeze
    MESSAGE_TTL = 2 # seconds
    FLASH_DELAY = 0.3 # seconds - long enough to actually see a keypress land
    WATCH_INTERVAL = 1.5 # seconds - how often to notice changes made outside the app
    COMMANDS = { 'h' => 'help', 'l' => 'list', 'ld' => 'list done', 'n' => 'new', 'e' => 'edit', 'o' => 'open',
                 'm' => 'move', 'd' => 'delete', 'i' => 'image', 'snc' => 'sync reminders', 'q' => 'quit' }.freeze
    # Not shown in the footer/help - `demo` still resolves via the same
    # "accept as soon as distinct" dispatch as everything else (`d` alone
    # stays ambiguous against it until `de` disambiguates), it's just
    # left out of what gets displayed.
    HIDDEN_COMMANDS = { 'demo' => 'toggle demo data' }.freeze
    ALL_COMMANDS = COMMANDS.merge(HIDDEN_COMMANDS).freeze

    def initialize(repo)
      @repo = repo
      @message = nil
      @message_expires_at = nil
      @view = :default
      @pending_keys = []
    end

    def run
      # Idempotent - a no-op once folders already exist, so this just
      # scaffolds the default structure the first time `tmd` is run
      # somewhere new instead of telling the user to run `tmd setup`.
      @repo.setup!
      loop do
        @repo.reconcile!
        draw
        key = read_key(select_timeout)
        expire_message!
        next if key == :timeout

        if @view == :help
          @view = :default
          next
        end

        break if QUIT_KEYS.include?(key)

        if key.match?(/\A[0-9]\z/)
          select_ticket_by_number(key)
        elsif ALL_COMMANDS.keys.any? { |cmd| cmd.start_with?(key) }
          dispatch_command(key)
        end
      end
    ensure
      print CLEAR
      $stdout.flush
    end

    private

    # Builds the whole frame as one string and explicitly uses \r\n rather
    # than relying on the terminal to translate a bare \n - stdin being
    # repeatedly put in raw mode can affect the shared tty's output
    # post-processing too, and without ONLCR translation each line drifts
    # right instead of returning to column 0.
    def draw
      board =
        if @view == :help
          help_board
        elsif @view == :done_only
          Printer.board(@repo, only: Printer::SUMMARIZED_FOLDERS, summarize: [])
        else
          Printer.board(@repo)
        end

      divider = '=' * (Printer.terminal_width || 40)
      frame = [title_banner, '', board, '', divider, '', "#{COMMANDS.keys.join(' ')} or ticket #", '',
                @message.to_s].join("\n")
      print CLEAR
      print frame.gsub("\n", "\r\n")
      $stdout.flush
    end

    # "TICKET, MD" centered in an "="-padded banner, sized to the current
    # terminal width so it stays centered across resizes.
    def title_banner
      text = ' TICKET, MD '
      width = Printer.terminal_width || 40
      pad = [width - text.length, 0].max
      left = pad / 2
      right = pad - left
      ('=' * left) + text + ('=' * right)
    end

    # Always wakes up at least every WATCH_INTERVAL, even with no message
    # pending, so external changes to the ticket files (Finder, another
    # editor) get picked up and redrawn without needing a keypress.
    def select_timeout
      return WATCH_INTERVAL unless @message_expires_at

      remaining = @message_expires_at - Time.now
      remaining.positive? ? [remaining, WATCH_INTERVAL].min : 0
    end

    def expire_message!
      return unless @message_expires_at && Time.now >= @message_expires_at

      @message = nil
      @message_expires_at = nil
    end

    def show_message(text)
      @message = text
      @message_expires_at = Time.now + MESSAGE_TTL
    end

    # Returns :timeout if `timeout` elapses with no input (used to expire
    # the status message), nil on real EOF (e.g. stdin closed), or the key.
    # A key pushed back via enqueue_key (eg. after peeking for `ld`) is
    # replayed before reading new input, so no keystroke is ever dropped.
    def read_key(timeout)
      return @pending_keys.shift unless @pending_keys.empty?

      $stdin.raw do |io|
        ready = IO.select([io], nil, nil, timeout)
        ready ? io.getc : :timeout
      end
    end

    def enqueue_key(key)
      @pending_keys.push(key)
    end

    # Generic "accept as soon as distinct" for letter commands, same
    # principle as ticket-number entry: `s` fires `snc` immediately since
    # it's the only command starting with `s` - no need to wait for `n`
    # and `c` too. `l` stays ambiguous with `ld` until a second key
    # arrives, since both are complete commands on their own. A key that
    # doesn't extend any known command is replayed via enqueue_key rather
    # than dropped, so eg. `l` then `q` still refreshes AND quits.
    def dispatch_command(first_key)
      # `l` while already showing the done-only view can only sensibly
      # mean "back to normal" - `ld` again is a no-op in that state - so
      # fire immediately instead of waiting to disambiguate against `ld`.
      if first_key == 'l' && @view == :done_only
        flash_command(first_key)
        return run_command('l')
      end

      buf = first_key
      loop do
        candidates = ALL_COMMANDS.keys.select { |cmd| cmd.start_with?(buf) }
        if candidates.length == 1
          flash_command(buf)
          return run_command(candidates.first)
        end

        show_message("Command: #{buf}")
        draw
        key = blocking_key
        if key.nil? || CANCEL_KEYS.include?(key)
          show_message('Cancelled') if key
          return
        end

        extended = buf + key
        if ALL_COMMANDS.keys.any? { |cmd| cmd.start_with?(extended) }
          buf = extended
        else
          run_command(buf) if ALL_COMMANDS.key?(buf)
          enqueue_key(key)
          return
        end
      end
    end

    # Shows the resolved command briefly before acting on it - without
    # this, a command that resolves in a single keystroke (eg. `s` ->
    # `snc`) jumps straight to its own next screen with no perceptible
    # moment where the keypress was actually acknowledged.
    def flash_command(buf)
      @message = "Command: #{buf}"
      draw
      sleep(FLASH_DELAY)
    end

    def run_command(command)
      case command
      when 'h' then show_help
      when 'l' then handle_l
      when 'ld' then handle_ld
      when 'n' then new_ticket
      when 'e', 'o' then edit_ticket
      when 'm' then move_ticket
      when 'd' then delete_ticket
      when 'i' then image_ticket
      when 'snc' then sync_reminders
      when 'demo' then toggle_demo
      end
    end

    # Plain `l`: pull + refresh, or while showing the done-only view,
    # return to the normal board. Pull failures (offline, conflicts,
    # no remote) don't block the refresh - just surface as the message.
    def handle_l
      @view = :default if @view == :done_only
      begin
        Github.pull!(@repo.root)
      rescue Github::Error => e
        return show_message("Pull failed: #{e.message}")
      end
      refresh
    end

    def handle_ld
      @view = :done_only
      show_message('Showing done only')
    end

    # Remembers the chosen list after the first pick, so `snc` goes
    # straight to a confirmation from then on rather than the picker.
    # Falls back to asking again if the remembered list no longer exists
    # (renamed/deleted in Reminders).
    def sync_reminders
      lists = Reminders.list_names
      return show_message('No reminder lists found') if lists.empty?

      remembered = @repo.configured_reminders_list
      return confirm_sync(remembered) if remembered && lists.include?(remembered)

      list_name = pick_reminders_list(lists)
      return unless list_name

      @repo.configured_reminders_list = list_name
      confirm_sync(list_name)
    rescue Reminders::Error => e
      show_message("Reminders error: #{e.message}")
    end

    # Hidden - toggles between the real tickets and a seeded demo set,
    # stashing whichever isn't active. Same underlying swap as `tmd demo`.
    def toggle_demo
      case @repo.toggle_demo!
      when :demo then show_message('Switched to demo data - `demo` again to restore your tickets')
      when :restored then show_message('Restored your tickets')
      end
    end

    # Shows the numbered (vertical) picker, or the new-list prompt for
    # `n`. Returns the chosen/created list name, or nil if cancelled.
    def pick_reminders_list(lists)
      list_lines = lists.each_with_index.map { |name, i| "  #{i + 1}) #{name}" }.join("\n")
      @message = "Pick a reminder list (n = new list):\n#{list_lines}"
      draw
      key = blocking_key
      return nil if CANCEL_KEYS.include?(key)

      if key == 'n'
        name = prompt('New list name')
        return nil if name.nil? || name.empty?

        Reminders.create_list(name)
        name
      elsif key.match?(/\A[0-9]\z/)
        buf = read_digits(key, (1..lists.length).to_a, label: 'List #')
        return nil unless buf

        idx = buf.to_i
        return nil unless idx.between?(1, lists.length)

        lists[idx - 1]
      end
    end

    # Names the list and requires an explicit y before doing anything
    # destructive (import_reminders deletes each reminder as it's
    # transferred) - applies whether the list was just picked or is the
    # remembered one from a previous sync. Declining offers a chance to
    # pick a different list instead of just bailing out.
    def confirm_sync(list_name)
      @message = "Sync from \"#{list_name}\"? y/n"
      draw
      return import_reminders(list_name) if blocking_key == 'y'

      @message = 'Connect another list? y/n'
      draw
      return show_message('Cancelled') unless blocking_key == 'y'

      lists = Reminders.list_names
      return show_message('No reminder lists found') if lists.empty?

      new_list = pick_reminders_list(lists)
      return unless new_list

      @repo.configured_reminders_list = new_list
      confirm_sync(new_list)
    rescue Reminders::Error => e
      show_message("Reminders error: #{e.message}")
    end

    def import_reminders(list_name)
      show_message("Syncing from \"#{list_name}\"...")
      draw

      count = 0
      Reminders.reminders_in(list_name).each do |reminder|
        next if reminder[:name].to_s.strip.empty?

        @repo.create_ticket(reminder[:name])
        Reminders.delete_reminder(reminder[:id])
        count += 1
      end
      show_message("Imported #{count} from \"#{list_name}\"")
    rescue Reminders::Error => e
      show_message("Reminders error: #{e.message}")
    end

    def new_ticket
      text = prompt('New ticket')
      return if text.nil? || text.empty?

      ticket = @repo.create_ticket(text)
      show_message("Created #{ticket.filename}")
    rescue RuntimeError => e
      show_message(e.message)
    end

    def move_ticket
      ticket, num = prompt_ticket_number
      move_ticket_action(ticket, num) if ticket
    end

    def delete_ticket
      ticket, num = prompt_ticket_number
      delete_ticket_action(ticket) if ticket
    end

    def edit_ticket
      ticket, = prompt_ticket_number
      open_in_editor(ticket) if ticket
    end

    # Commits+pushes just the selected ticket file, then opens its
    # GitHub edit view in the browser - dropping an image there via
    # cmd-v gets it uploaded and embedded without handling files
    # locally at all.
    def image_ticket
      ticket, = prompt_ticket_number
      return unless ticket

      show_message('Committing and pushing...')
      draw
      Github.commit_and_push!(ticket.path, "Update ticket: #{ticket.title}", @repo.root)
      system('open', Github.edit_url_for(ticket.path, @repo.root), out: File::NULL, err: File::NULL)
      show_message("Opened #{ticket.filename} on GitHub - paste your image there")
    rescue Github::Error => e
      show_message("GitHub error: #{e.message}")
    end

    # Lets a ticket be picked first (type digits), then acted on with a
    # command letter — the reverse of the usual letter-then-number order.
    def select_ticket_by_number(first_digit)
      ticket, num = resolve_ticket_number(first_digit)
      return unless ticket

      show_message("##{num} #{ticket.title} - m=move d=delete e/o=edit")
      draw
      key = blocking_key
      case key
      when 'm' then move_ticket_action(ticket, num)
      when 'd' then delete_ticket_action(ticket)
      when 'e', 'o' then open_in_editor(ticket)
      else show_message('Cancelled') if CANCEL_KEYS.include?(key)
      end
    end

    # Letter-first entry (`m`, `d`): prompts for the first digit, then
    # resolves it the same distinct-prefix way as number-first entry.
    def prompt_ticket_number
      @message = 'Ticket #: '
      draw
      first = blocking_key
      unless first&.match?(/\A[0-9]\z/)
        show_message('Cancelled') if CANCEL_KEYS.include?(first)
        return [nil, nil]
      end

      resolve_ticket_number(first)
    end

    def resolve_ticket_number(first_digit)
      buf = read_digits(first_digit, visible_ticket_numbers, label: 'Ticket #')
      return [nil, nil] unless buf

      ticket = @repo.ticket_by_index(buf.to_i)
      show_message("No ticket ##{buf}") unless ticket
      [ticket, buf]
    end

    # Numbers actually selectable right now. "done" never shows a
    # position number at all (Printer leads done entries with their id
    # instead, not number-interactive - see #43) and every other
    # summarized folder only hides its numbers while collapsed. Without
    # this, typing a digit stays ambiguous against numbers the user
    # can't even see or type toward (eg. "1" waiting on invisible
    # tickets 10-19 in a folder that's summarized or is "done").
    def visible_ticket_numbers
      hidden = (@view == :done_only ? [] : Printer::SUMMARIZED_FOLDERS) + ['done']
      @repo.numbered_entries.reject { |e| hidden.include?(e.folder.name) }.map(&:index)
    end

    # Reads digits one at a time, accepting as soon as the typed prefix
    # distinctly identifies exactly one option in `valid_numbers` (or is
    # provably out of range) - Enter is never required, but forces early
    # submission if pressed. Used for both ticket numbers and picking from
    # a numbered list (eg. Reminders lists in `snc`) - multi-digit choices
    # (10+) must be typeable, not just the first digit, or a mistyped
    # single digit could pick the wrong (possibly destructive) option.
    # Returns the raw digit string, or nil if cancelled.
    def read_digits(first_digit, valid_numbers, label:)
      buf = first_digit
      loop do
        matches = valid_numbers.select { |i| i.to_s.start_with?(buf) }
        break if matches.length <= 1

        @message = "#{label}: #{buf}"
        draw
        key = blocking_key
        break if key == "\r" || key == "\n"
        if CANCEL_KEYS.include?(key)
          show_message('Cancelled')
          return nil
        end

        buf += key if key.match?(/\A[0-9]\z/)
      end
      buf
    end

    def move_ticket_action(ticket, num)
      dest = prompt("Move to [#{folder_hint}], blank = next in line")
      return if dest.nil?

      current_folder = @repo.folder_containing(ticket)
      target = dest.empty? ? @repo.next_folder_after(current_folder) : @repo.folder_matching(dest)

      unless target
        show_message(dest.empty? ? 'Already at the last stage' : "No folder matches \"#{dest}\"")
        return
      end

      @repo.move_ticket(ticket, target)
      show_message("Moved ##{num} to #{target.name}")
    end

    def delete_ticket_action(ticket)
      @repo.delete_ticket(ticket)
      show_message("Moved #{ticket.filename} to trash")
    end

    # Opens with whatever app macOS has registered as the default for
    # .md files - not $EDITOR / a terminal editor.
    def open_in_editor(ticket)
      system('open', ticket.path, out: File::NULL, err: File::NULL)
      show_message("Opened #{ticket.filename}")
    end

    def blocking_key
      return @pending_keys.shift unless @pending_keys.empty?

      $stdin.raw { |io| io.getc }
    end

    def refresh
      show_message('Up to date')
    end

    # Replaces the board with a vertical command list rather than
    # appending a single-line message - a joined "h=help l=list ..."
    # string got hard to scan once there were this many commands. Any
    # keypress dismisses it back to the normal board (see `run`).
    def show_help
      @view = :help
    end

    def help_board
      COMMANDS.map { |letter, name| "  #{letter} - #{name}" }.join("\n")
    end

    # Shows each folder's shortest unique prefix rather than always just
    # the first letter, so eg. "refine" and "ready" (both starting with
    # "re") show as "ref"/"rea" instead of colliding on plain "r" -
    # matching what folder_matching itself actually requires to resolve.
    def folder_hint
      names = @repo.folders.map(&:name)
      names.map do |name|
        len = (1..name.length).find { |n| names.count { |o| o.start_with?(name[0...n]) } == 1 } || name.length
        "#{name[0...len]}=#{name}"
      end.join(' ')
    end

    # Raw per-key text input (not cooked-mode `gets`) so Escape can be
    # caught mid-typing. Returns the typed text, or nil if cancelled via
    # CANCEL_KEYS - distinct from '', which means "submitted empty".
    def prompt(label)
      buf = +''
      print "\r\n\r\n#{label}: "
      $stdout.flush
      loop do
        key = blocking_key
        case key
        when "\r", "\n"
          break
        when *CANCEL_KEYS
          show_message('Cancelled')
          return nil
        when *BACKSPACE_KEYS
          next if buf.empty?

          buf.chop!
          print "\b \b"
          $stdout.flush
        else
          next unless key&.match?(/\A[[:print:]]\z/)

          buf << key
          print key
          $stdout.flush
        end
      end
      buf.strip
    end
  end
end
