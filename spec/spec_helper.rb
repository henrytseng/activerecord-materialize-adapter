require 'pry'
require "rspec/expectations"
require 'activerecord-materialize-adapter'
require 'helpers/database_helper'

RSpec.configure do |config|
  config.include DatabaseHelper

  config.before(:each) do
    create_db
  end

  config.after(:each) do
    drop_db_if_exists
    use_different_database
  end
end
