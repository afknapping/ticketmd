module TicketMD
  module Slug
    def self.call(text)
      text.to_s
        .downcase
        .gsub(/[^a-z0-9]+/, '-')
        .gsub(/\A-+|-+\z/, '')
    end
  end
end
