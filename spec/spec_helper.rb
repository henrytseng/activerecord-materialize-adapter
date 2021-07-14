require 'pry'
require "rspec/expectations"
require 'activerecord-materialize-adapter'
require 'helpers/database_helper'

RSpec.configure do |config|
  config.include DatabaseHelper

end
