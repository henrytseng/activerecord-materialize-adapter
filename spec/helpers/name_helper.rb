require 'securerandom'
require "active_record/tasks/database_tasks"
require "active_record/connection_adapters/materialize_adapter"
require "active_record/tasks/postgresql_database_tasks"

module NameHelper
  def get_names(fixture_filename)
    File.open("spec/fixtures/names.csv", 'r') do |f|
      f.readlines
    end
  end
end
