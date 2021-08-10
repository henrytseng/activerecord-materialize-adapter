# frozen_string_literal: true

require 'securerandom'
require "active_record/tasks/database_tasks"
require "active_record/connection_adapters/materialize_adapter"
require "active_record/tasks/postgresql_database_tasks"

module DatabaseHelper
  def default_config_path
    File.dirname(__FILE__) << "/../database.yml"
  end

  # Get random database id
  def database_id
    @database_id ||= "#{SecureRandom.hex(4)}"
  end

  # Reset random database id
  def use_different_database
    @database_id = nil
  end

  # Configuration hash
  def configuration_options(config_path = default_config_path, database: nil)
    config = YAML.load(ERB.new(File.read(config_path)).result)
    unless database.nil?
      config = config.merge({
        "database" => database,
        "log_level" => :debug
      })
    end
    config[ENV['RAILS_ENV']]
  end

  # Get established connection
  def connection
    @connection
  end

  # Uses a stack to store multiple connections
  def with_configuration(config)
    @configuration_stack ||= []
    @configuration_stack.push config
    ActiveRecord::Base.establish_connection config
    @connection = ActiveRecord::Base.connection
    yield config
    @configuration_stack.pop
    unless @configuration_stack.empty?
      ActiveRecord::Base.establish_connection @configuration_stack.last
      @connection = ActiveRecord::Base.connection
    end
  end

  # Create Materailzie database
  def create_materialize(options = {})
    options = configuration_options['materialize']
      .merge('database' => database_id)
      .merge(options)
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("log/debug.log")
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
  end

  # Drop Materialize database
  def drop_materialize(options = {})
    options = configuration_options['materialize']
      .merge('database' => database_id)
      .merge(options)
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
  rescue PG::ObjectInUse
    # ignore
  end

  # Establish connection with Materialzie database
  def with_materialize(options = {})
    result = nil
    materialize_id = "materialize_test#{database_id}"
    create_materialize({ 'database' => materialize_id })
    config = configuration_options['materialize']
      .merge('database' => materialize_id)
      .merge(options)
    use_different_database
    with_configuration(config) do
      result = yield config
    end
    at_exit { drop_materialize({ 'database' => materialize_id }) }
    result
  rescue PG::ObjectInUse
    # ignore
  end

  # Create Postgres database
  def create_pg(options = {})
    options = configuration_options['pg']
      .merge('database' => database_id)
      .merge(options)
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("log/debug.log")
    ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(options).create
  end

  # Drop Postgres database
  def drop_pg(options = {})
    options = configuration_options['pg']
      .merge('database' => database_id)
      .merge(options)
    ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(options).drop
  rescue PG::ObjectInUse
    # ignore
  end

  # Removes all publications
  def drop_publications
    publications = connection.query_values('SELECT pubname FROM pg_publication')
    publications.each do |publication_name|
      connection.execute("DROP PUBLICATION IF EXISTS #{publication_name}")
    end
  end

  # Establish connection with Postgres
  def with_pg(options = {})
    result = nil
    pg_id = "pg_test#{database_id}"
    create_pg({ 'database' => pg_id })
    config = configuration_options['pg']
      .merge('database' => pg_id)
      .merge(options)
    use_different_database
    with_configuration(config) do
      result = yield config
    end
    at_exit do
      with_configuration(config) do
        drop_publications
      end
      drop_pg({ 'database' => pg_id })
    end
    result
  rescue PG::ObjectInUse
    # ignore
  end

  # Get SQL fixture
  def get_sql(fixture_filename)
    fixture_filename = fixture_filename.to_s
    fixture_filename = "#{fixture_filename}.sql" unless fixture_filename.include? '.sql'
    File.open("spec/fixtures/sql/#{fixture_filename}", 'r') do |f|
      f.read
    end
  end
end
