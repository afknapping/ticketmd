require_relative 'lib/ticket_md/version'

Gem::Specification.new do |spec|
  spec.name = 'ticket_md'
  spec.version = TicketMD::VERSION
  spec.authors = ['Fabian']
  spec.email = ['fabian@afknapping.de']
  spec.summary = 'Plain-markdown ticket system - the filesystem is the database.'
  spec.description = 'A terminal ticket tracker where each ticket is a markdown file and its status is the folder it lives in.'
  spec.required_ruby_version = '>= 3.0'

  spec.files = Dir['lib/**/*.rb', 'bin/*']
  spec.bindir = 'bin'
  spec.executables = ['tmd']
  spec.require_paths = ['lib']
end
