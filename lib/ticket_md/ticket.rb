require 'yaml'
require_relative 'slug'

module TicketMD
  class Ticket
    FRONTMATTER_DELIM = '---'

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def filename
      File.basename(path)
    end

    def title
      (body_lines.first || '').strip
    end

    def ready?
      !!frontmatter['ready']
    end

    def question?
      !!frontmatter['question']
    end

    def id
      frontmatter['id']
    end

    # Generates and persists a stable id if this ticket doesn't have one
    # yet (or has a legacy non-numeric one - ids are meant to be plain
    # consecutive numbers, not hex, so those get migrated in place).
    # Lets reconcile! recognize a stale file resurrected by an external
    # editor (still holding an old, since-renamed path) as a duplicate
    # of the same ticket rather than a brand new one.
    def ensure_id!
      fm = frontmatter
      return fm['id'] if numeric_id?(fm['id'])

      new_id = yield
      write_frontmatter!(fm.merge('id' => new_id))
      new_id
    end

    # Renames the file on disk to match the slug of its first line, with
    # the ticket's id appended at the end (keeps filenames and content
    # in sync, and lets the id be spotted straight from `ls`/git status
    # without opening the file). Reconcile! assigns ids before calling
    # this, so `id` is always set here except for the empty-slug bailout
    # below, which skips renaming entirely.
    def rename_to_match_title!
      slug = Slug.call(title)
      return self if slug.empty?

      expected = "#{slug}-#{id}.md"
      return self if expected == filename

      dir = File.dirname(path)
      new_path = self.class.unique_path(dir, expected)
      File.rename(path, new_path)
      @path = new_path
      self
    end

    def move_to!(dir)
      new_path = self.class.unique_path(dir, filename)
      File.rename(path, new_path)
      @path = new_path
      self
    end

    def self.unique_path(dir, filename)
      base = File.basename(filename, '.md')
      candidate = filename
      n = 2
      while File.exist?(File.join(dir, candidate))
        candidate = "#{base}-#{n}.md"
        n += 1
      end
      File.join(dir, candidate)
    end

    private

    def numeric_id?(value)
      case value
      when Integer then true
      when String then value.match?(/\A\d+\z/)
      else false
      end
    end

    # Metadata lives as "backmatter": a ---/--- YAML block at the END of
    # the file, not the top. Any blank lines before it are just visual
    # space for a human reader - not part of the delimiter.
    def matter_bounds(lines)
      closing = lines.rindex { |l| l.chomp == FRONTMATTER_DELIM }
      return nil unless closing

      opening = (closing - 1).downto(0).find { |i| lines[i].chomp == FRONTMATTER_DELIM }
      return nil unless opening

      [opening, closing]
    end

    # { } when there's no backmatter block, or it fails to parse.
    def frontmatter
      lines = File.readlines(path)
      bounds = matter_bounds(lines)
      return {} unless bounds

      opening, closing = bounds
      YAML.safe_load(lines[(opening + 1)...closing].join, permitted_classes: []) || {}
    rescue Psych::SyntaxError
      {}
    end

    # Rewrites the file with a new backmatter block, keeping the existing
    # body untouched.
    def write_frontmatter!(new_frontmatter)
      yaml_body = YAML.dump(new_frontmatter).sub(/\A---\n/, '')
      body = body_lines.join
      body += "\n" unless body.empty? || body.end_with?("\n")
      File.write(path, "#{body}\n\n\n#{FRONTMATTER_DELIM}\n#{yaml_body}#{FRONTMATTER_DELIM}\n")
    end

    # The file's content with any backmatter block (and the blank lines
    # right before it) stripped off.
    def body_lines
      lines = File.readlines(path)
      bounds = matter_bounds(lines)
      return lines unless bounds

      opening, = bounds
      lines[0...opening]
    end
  end
end
