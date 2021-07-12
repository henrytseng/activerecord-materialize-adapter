require 'activerecord-materialize-adapter'
require 'pry'

module ActiveRecord
  class Base
    DATABASE_CONFIG_PATH = File.dirname(__FILE__) << "/database.yml"

    def self.test_connection_hash
      YAML.load(ERB.new(File.read(DATABASE_CONFIG_PATH)).result)
    end

    def self.establish_test_connection
      establish_connection test_connection_hash
    end
  end
end

ActiveRecord::Base.establish_test_connection

def new_connection(options = {})
  configuration_options = { "database" => "materialize_tasks_test" }.merge(options)
  configuration_hash = ActiveRecord::Base.test_connection_hash.merge(configuration_options)
  ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", configuration_hash)
end

def drop_db_if_exists
  ActiveRecord::ConnectionAdapters::PostGIS::PostGISDatabaseTasks.new(new_connection).drop
rescue ActiveRecord::DatabaseAlreadyExists
  # ignore
end
