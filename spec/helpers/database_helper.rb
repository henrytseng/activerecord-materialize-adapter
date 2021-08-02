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
    ActiveRecord::Base.connection
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
    materialize_id = "materialize_test#{database_id}"
    create_materialize({ 'database' => materialize_id })
    config = configuration_options['materialize']
      .merge('database' => materialize_id)
      .merge(options)
    ActiveRecord::Base.establish_connection config
    result = yield config
    use_different_database
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

  # Establish connection with Postgres
  def with_pg(options = {})
    pg_id = "pg_test#{database_id}"
    create_pg({ 'database' => pg_id })
    config = configuration_options['pg']
      .merge('database' => pg_id)
      .merge(options)
    ActiveRecord::Base.establish_connection config
    result = yield config
    use_different_database
    at_exit { drop_pg({ 'database' => pg_id }) }
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
