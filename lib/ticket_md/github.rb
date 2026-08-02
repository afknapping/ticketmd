require 'open3'
require 'pathname'
require 'uri'

module TicketMD
  # Commits+pushes a single ticket file, then builds its GitHub "edit
  # this file" web URL - opening it lets you paste an image straight
  # into the browser editor, which GitHub auto-uploads and links for
  # you, without handling image files locally at all (see the `i`
  # command's originating ticket).
  module Github
    class Error < StandardError; end

    def self.edit_url_for(path, root)
      "#{repo_url(root)}/edit/#{branch(root)}/#{relative_path(path, root)}"
    end

    def self.commit_and_push!(path, message, root)
      run(root, 'git', 'add', '--', path)
      commit(path, message, root)
      run(root, 'git', 'push')
    end

    def self.pull!(root)
      run(root, 'git', 'pull')
    end

    def self.commit(path, message, root)
      out, err, status = Open3.capture3('git', '-C', root, 'commit', '-m', message, '--', path)
      return if status.success? || out.include?('nothing to commit')

      raise Error, err.strip
    end
    private_class_method :commit

    # Percent-encodes each path segment (folder names here contain
    # spaces, eg. "10 new") while keeping "/" separators literal. Not
    # encode_www_form_component - that's "+" for space (form encoding),
    # not "%20" (the correct escape for a URL path segment).
    def self.relative_path(path, root)
      relative = Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(File.expand_path(root))).to_s
      relative.split('/').map { |segment| URI::DEFAULT_PARSER.escape(segment, /[^A-Za-z0-9\-._~]/) }.join('/')
    end
    private_class_method :relative_path

    def self.repo_url(root)
      remote = capture(root, 'git', 'remote', 'get-url', 'origin')
      remote.sub(/\.git\z/, '').sub(%r{\Agit@github\.com:}, 'https://github.com/')
    end
    private_class_method :repo_url

    def self.branch(root)
      capture(root, 'git', 'rev-parse', '--abbrev-ref', 'HEAD')
    end
    private_class_method :branch

    def self.run(root, *cmd)
      _, err, status = Open3.capture3(*cmd, chdir: root)
      raise Error, err.strip unless status.success?
    end
    private_class_method :run

    def self.capture(root, *cmd)
      out, err, status = Open3.capture3(*cmd, chdir: root)
      raise Error, err.strip unless status.success?

      out.strip
    end
    private_class_method :capture
  end
end
