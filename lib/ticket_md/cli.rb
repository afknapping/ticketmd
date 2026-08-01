require_relative 'repository'
require_relative 'printer'
require_relative 'interactive'

module TicketMD
  class CLI
    def self.run(argv, root: Dir.pwd)
      new(Repository.new(root)).run(argv)
    end

    def initialize(repo)
      @repo = repo
    end

    def run(argv)
      case argv.first
      when 'setup'
        setup
      when 'list'
        list
      when 'demo'
        demo
      when nil
        Interactive.new(@repo).run
      else
        warn "Unknown command: #{argv.first}"
        warn 'Usage: tmd [setup|list]'
        exit 1
      end
    end

    private

    def setup
      created = @repo.setup!
      if created.empty?
        puts 'Already set up.'
      else
        created.each { |f| puts "Created #{f.dirname}/" }
      end
    end

    # Undocumented on purpose - toggles between the real tickets and a
    # seeded demo set (eg. for screenshots), stashing whichever isn't
    # active.
    def demo
      case @repo.toggle_demo!
      when :demo then puts 'Switched to demo data. Run `tmd demo` again to restore your tickets.'
      when :restored then puts 'Restored your tickets.'
      end
    end

    def list
      @repo.reconcile!
      if @repo.folders.empty?
        puts 'No ticket folders found. Run `tmd setup` first.'
      else
        puts Printer.board(@repo)
      end
    end
  end
end
