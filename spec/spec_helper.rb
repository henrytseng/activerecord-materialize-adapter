require 'activerecord-materialize-adapter'
require 'pry'

require 'helpers/database_helper'

RSpec.configure do |c|
  c.include DatabaseHelper
end
