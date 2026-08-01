require_relative 'ticket'

module TicketMD
  class Repository
    Folder = Struct.new(:order, :name, :dirname, :path)
    Entry = Struct.new(:index, :folder, :ticket)

    DEFAULT_FOLDERS = [
      [10, 'backlog'],
      [20, 'next'],
      [30, 'in progress'],
      [40, 'testing'],
      [50, 'done']
    ].freeze

    SYSTEM_TRASH = File.expand_path('~/.Trash')
    LOCAL_TRASH_DIRNAME = '.TRASH'
    REMINDERS_LIST_CONFIG = '.reminders-list'
    # All status folders and app-managed files live under this hidden
    # subfolder of the project root, rather than directly in it - keeps
    # the root clean and makes it obvious what's "the ticket data" if the
    # project is committed to git.
    TICKETS_DIRNAME = '.TICKETMD'

    def initialize(root)
      @root = root
    end

    def folders
      return [] unless Dir.exist?(tickets_root)

      Dir.children(tickets_root)
        .filter_map { |name| folder_from_dirname(name) }
        .sort_by(&:order)
    end

    def tickets_in(folder)
      Dir.children(folder.path)
        .select { |f| f.end_with?('.md') && !f.start_with?('.') }
        .sort
        .map { |f| Ticket.new(File.join(folder.path, f)) }
    end

    # Reconciles every ticket's filename with its current content so the
    # filesystem stays the source of truth even after hand edits. Also
    # ensures every ticket has a stable id and merges away duplicates that
    # id reveals (eg. a stale file resurrected by an external editor still
    # holding an old, since-renamed path).
    def reconcile!
      folders.each { |folder| tickets_in(folder).each(&:rename_to_match_title!) }

      all = folders.flat_map { |folder| tickets_in(folder) }
      all.each(&:ensure_id!)
      merge_duplicate_ids!(all)
    end

    def default_folder
      folders.min_by(&:order)
    end

    # Every ticket across all folders, numbered in a fixed global order —
    # the numbers shown on screen and the handle used to reference a
    # ticket from a command like `m`. Always covers every folder, even
    # ones a given view doesn't currently display, so a ticket's number
    # never changes depending on what's visible.
    def numbered_entries
      index = 0
      folders.each_with_object([]) do |folder, acc|
        tickets_in(folder).each do |ticket|
          index += 1
          acc << Entry.new(index, folder, ticket)
        end
      end
    end

    def ticket_by_index(index)
      numbered_entries.find { |e| e.index == index }&.ticket
    end

    def folder_containing(ticket)
      folders.find { |f| File.dirname(ticket.path) == f.path }
    end

    def next_folder_after(folder)
      ordered = folders
      idx = ordered.index(folder)
      return nil unless idx

      ordered[idx + 1]
    end

    # Matches a folder by prefix of its name, case-insensitive (eg. "b" ->
    # backlog). Ambiguous or unmatched input returns nil.
    def folder_matching(input)
      needle = input.downcase
      matches = folders.select { |f| f.name.downcase.start_with?(needle) }
      matches.length == 1 ? matches.first : nil
    end

    def move_ticket(ticket, folder)
      ticket.move_to!(folder.path)
    end

    # Never hard-deletes: moves to the real macOS Trash when it's on the
    # same volume, otherwise falls back to a local .TRASH folder.
    def delete_ticket(ticket)
      if Dir.exist?(SYSTEM_TRASH)
        begin
          return ticket.move_to!(SYSTEM_TRASH)
        rescue SystemCallError
          # different volume, permissions, etc. - fall back to local trash
        end
      end

      local_trash = File.join(tickets_root, LOCAL_TRASH_DIRNAME)
      Dir.mkdir(local_trash) unless Dir.exist?(local_trash)
      ticket.move_to!(local_trash)
    end

    # The Reminders list to sync with, remembered from the last `snc`
    # choice - nil if never set.
    def configured_reminders_list
      path = File.join(tickets_root, REMINDERS_LIST_CONFIG)
      return nil unless File.exist?(path)

      value = File.read(path).strip
      value.empty? ? nil : value
    end

    def configured_reminders_list=(name)
      Dir.mkdir(tickets_root) unless Dir.exist?(tickets_root)
      File.write(File.join(tickets_root, REMINDERS_LIST_CONFIG), "#{name}\n")
    end

    def create_ticket(text, folder = default_folder)
      raise 'no folders found - run `tmd setup` first' unless folder

      slug = Slug.call(text)
      filename = slug.empty? ? "ticket-#{Time.now.to_i}.md" : "#{slug}.md"
      path = Ticket.unique_path(folder.path, filename)
      File.write(path, "#{text.strip}\n")
      Ticket.new(path)
    end

    def setup!
      Dir.mkdir(tickets_root) unless Dir.exist?(tickets_root)

      created_folders = []

      DEFAULT_FOLDERS.each do |order, name|
        next if folders.any? { |f| f.name == name }

        dirname = format('%02d %s', order, name)
        path = File.join(tickets_root, dirname)
        Dir.mkdir(path)
        created_folders << folder_from_dirname(dirname)
      end

      backlog = folders.find { |f| f.name == DEFAULT_FOLDERS.first.last } || created_folders.first
      if backlog && tickets_in(backlog).empty?
        create_ticket('example: edit or delete this ticket', backlog)
        create_ticket('drag me to next when ready', backlog)
      end

      created_folders
    end

    private

    def tickets_root
      File.join(@root, TICKETS_DIRNAME)
    end

    # When two tickets share an id, one is a stale resurrection - keep
    # whichever was written to most recently (the user's latest actual
    # save) and trash the rest.
    def merge_duplicate_ids!(tickets)
      tickets.group_by(&:id).each_value do |group|
        next if group.length <= 1

        _keep, *rest = group.sort_by { |t| -File.mtime(t.path).to_f }
        rest.each { |ticket| delete_ticket(ticket) }
      end
    end

    def folder_from_dirname(name)
      match = name.match(/\A(\d+)\s+(.+)\z/)
      return nil unless match

      path = File.join(tickets_root, name)
      return nil unless File.directory?(path)

      Folder.new(match[1].to_i, match[2], name, path)
    end
  end
end
