require "./lib/active_record/connection_adapters/materialize/version"

Gem::Specification.new do |s|
  s.name        = 'activerecord-materialize-adapter'
  s.version = ActiveRecord::ConnectionAdapters::Materialize::VERSION

  s.licenses = ['MIT']
  s.summary = "Database adapter for materialize.io database."
  s.description = "Materialize is a streaming database for real-time applications. Materialize accepts input data from a variety of streaming sources (e.g. Kafka) and files (e.g. CSVs), and lets you query them using SQL."
  s.authors = ["Henry Tseng"]
  s.email = 'henryiis@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.files = Dir["lib/**/*", "LICENSE"]

  s.homepage = 'https://rubygems.org/gems/example'
  s.metadata = { "source_code_uri" => "https://github.com/example/example" }

  s.add_dependency "activerecord", "~> 6.0.3.7"
  s.add_dependency "activesupport", "~> 6.0.3.7"
  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "rspec", "~> 3.9.0"
end
