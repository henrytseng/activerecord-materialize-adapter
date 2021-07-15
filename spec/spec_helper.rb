require 'pry'
require "rspec/expectations"
require 'activerecord-materialize-adapter'
require 'helpers/database_helper'

ActiveRecord::Base.logger = Logger.new(STDOUT)

RSpec.configure do |config|
  config.include DatabaseHelper

  config.before(:each) do
    create_materialize
  end

  config.after(:each) do
    drop_materialize
    use_different_database
  end
end
