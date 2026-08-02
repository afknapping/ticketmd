require 'fileutils'
require_relative 'ticket'

module TicketMD
  class Repository
    Folder = Struct.new(:order, :name, :dirname, :path)
    Entry = Struct.new(:index, :folder, :ticket)

    DEFAULT_FOLDERS = [
      [10, 'new'],
      [20, 'refine'],
      [30, 'ready'],
      [40, 'in progress'],
      [50, 'testing'],
      [60, 'done']
    ].freeze

    SYSTEM_TRASH = File.expand_path('~/.Trash')
    LOCAL_TRASH_DIRNAME = '.TRASH'
    REMINDERS_LIST_CONFIG = '.reminders-list'
    ID_COUNTER_FILENAME = '.id-counter'
    # All status folders and app-managed files live under this hidden
    # subfolder of the project root, rather than directly in it - keeps
    # the root clean and makes it obvious what's "the ticket data" if the
    # project is committed to git.
    TICKETS_DIRNAME = '.TICKETMD'
    DEMO_STASH_DIRNAME = '.TICKETMD.stash'

    DEMO_TICKETS = {
      'new' => [
        'try out a rough idea for keyboard-only navigation',
        'jot down thoughts on multi-project dashboards'
      ],
      'refine' => [
        { title: 'explore dark mode support', question: true },
        { title: 'investigate flaky CI on windows runners', ready: true },
        'evaluate switching CI provider to cut build times',
        'sketch out plugin API for custom themes'
      ],
      'ready' => [
        { title: 'add pagination to the search results endpoint', ready: true },
        { title: 'write onboarding docs for new contributors', ready: true },
        { title: 'add keyboard shortcut cheatsheet to onboarding', ready: true },
        { title: 'set up error tracking for the api service', ready: true }
      ],
      'in progress' => [
        { title: 'refactor auth middleware to use new session store', ready: true },
        { title: 'migrate legacy config loader to the new settings module', ready: true }
      ],
      'testing' => [
        { title: 'verify csv export handles unicode filenames', ready: true },
        { title: 'load test the new caching layer', ready: true }
      ],
      'done' => [
        { title: 'fix off-by-one error in date range picker', ready: true },
        { title: 'upgrade postgres client library to v3', ready: true },
        { title: 'ship dark launch flag for the redesigned settings page', ready: true }
      ]
    }.freeze

    attr_reader :root

    def initialize(root)
      @root = root
    end

    def folders
      return [] unless Dir.exist?(tickets_root)

      Dir.children(tickets_root)
        .filter_map { |name| folder_from_dirname(name) }
        .sort_by(&:order)
    end

    # Alphabetical everywhere except "done", which sorts by last
    # modified (most recent first) so the ticket you just finished
    # shows up at the top instead of wherever its filename happens to
    # alphabetize to.
    def tickets_in(folder)
      paths = Dir.children(folder.path)
        .select { |f| f.end_with?('.md') && !f.start_with?('.') }
        .map { |f| File.join(folder.path, f) }
      paths = folder.name == 'done' ? paths.sort_by { |p| -File.mtime(p).to_f } : paths.sort
      paths.map { |p| Ticket.new(p) }
    end

    # Reconciles every ticket's filename with its current content so the
    # filesystem stays the source of truth even after hand edits. Also
    # ensures every ticket has a stable id and merges away duplicates that
    # id reveals (eg. a stale file resurrected by an external editor still
    # holding an old, since-renamed path).
    def reconcile!
      all = folders.flat_map { |folder| tickets_in(folder) }
      all.each { |ticket| ticket.ensure_id! { next_ticket_id! } }
      merge_duplicate_ids!(all)

      folders.each { |folder| tickets_in(folder).each(&:rename_to_match_title!) }
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

    # Matches a folder by prefix of its name, case-insensitive (eg. "d" ->
    # done). Ambiguous or unmatched input returns nil - "refine" and
    # "ready" share the prefix "re", so "r"/"re" won't resolve; "ref" or
    # "rea" will.
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

      first_folder = folders.find { |f| f.name == DEFAULT_FOLDERS.first.last } || created_folders.first
      if first_folder && tickets_in(first_folder).empty?
        create_ticket('example: edit or delete this ticket', first_folder)
        create_ticket('drag me to refine when ready', first_folder)
      end

      created_folders
    end

    # Toggle: first call stashes the real tickets and swaps in a seeded
    # demo set; second call deletes the demo set and restores the stash.
    # Returns :demo or :restored.
    def toggle_demo!
      stash_path = File.join(@root, DEMO_STASH_DIRNAME)

      if Dir.exist?(stash_path)
        FileUtils.rm_rf(tickets_root)
        File.rename(stash_path, tickets_root)
        :restored
      else
        File.rename(tickets_root, stash_path) if Dir.exist?(tickets_root)
        Dir.mkdir(tickets_root)
        seed_demo_data!
        :demo
      end
    end

    private

    # Random three-digit ids (not the usual sequential ones) so the demo
    # board looks like a ticket system with real history behind it,
    # rather than one that obviously just started at #1.
    def seed_demo_data!
      random_ids = (100..999).to_a.sample(DEMO_TICKETS.values.sum(&:length)).each

      DEFAULT_FOLDERS.each do |order, name|
        dirname = format('%02d %s', order, name)
        path = File.join(tickets_root, dirname)
        Dir.mkdir(path)
        folder = Folder.new(order, name, dirname, path)
        DEMO_TICKETS.fetch(name, []).each do |entry|
          title, flags = entry.is_a?(Hash) ? [entry[:title], entry] : [entry, {}]
          ticket = create_ticket(title, folder)
          fm = { 'id' => random_ids.next }
          fm['ready'] = true if flags[:ready]
          fm['question'] = true if flags[:question]
          ticket.send(:write_frontmatter!, fm)
        end
      end
    end

    def tickets_root
      File.join(@root, TICKETS_DIRNAME)
    end

    # Plain consecutive numbers, persisted alongside the tickets so ids
    # stay stable and gap-free across runs (people expect #1, #2, #3...
    # from other ticket systems, not random hex).
    def next_ticket_id!
      path = File.join(tickets_root, ID_COUNTER_FILENAME)
      current = File.exist?(path) ? File.read(path).strip.to_i : 0
      next_id = current + 1
      File.write(path, "#{next_id}\n")
      next_id
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
