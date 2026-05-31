require_relative "lib/acts_as_fifo_lifo/version"

Gem::Specification.new do |spec|
  spec.name        = "acts_as_fifo_lifo"
  spec.version     = ActsAsFifoLifo::VERSION
  spec.authors     = [ "Rem" ]
  spec.email       = [ "r3mnik@gmail.com" ]
  spec.homepage    = "https://github.com/fatshinobi/acts_as_fifo_lifo/tree/main"
  spec.summary     = "Gem to process FIFO & LIFO operations in inventory management."
  spec.description = "A Rails gem for handling FIFO (First-In, First-Out) and LIFO (Last-In, First-Out) inventory management operations."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fatshinobi/acts_as_fifo_lifo/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/fatshinobi/acts_as_fifo_lifo/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.3"
end
