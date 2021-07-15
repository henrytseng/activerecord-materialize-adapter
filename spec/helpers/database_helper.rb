require 'securerandom'
require "active_record/connection_adapters/materialize_adapter"

module DatabaseHelper
  def default_config_path
    File.dirname(__FILE__) << "/../database.yml"
  end

  def database_id
    @database_id ||= "materialize_adapter_test#{SecureRandom.hex(4)}"
  end

  def use_different_database
    @database_id = nil
  end

  def configuration_options(config_path = default_config_path, database: nil)
    config = YAML.load(ERB.new(File.read(config_path)).result)
    config = config.merge({ "database" => database }) unless database.nil?
    config
  end

  def create_db(options = {})
    options = configuration_options
      .merge('database' => database_id)
      .merge(options)
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
  end

  def drop_db_if_exists(options = {})
    options = configuration_options
      .merge('database' => database_id)
      .merge(options)
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
  rescue ActiveRecord::DatabaseAlreadyExists
    # ignore
  end

  def get_sql(fixture_filename)
    fixture_filename = fixture_filename.to_s
    fixture_filename = "#{fixture_filename}.sql" unless fixture_filename.include? '.sql'
    File.open("spec/fixtures/sql/#{fixture_filename}", 'r') do |f|
      f.read
    end
  end
end
