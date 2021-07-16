require 'spec_helper'
require 'models/factory'
require 'models/product'

describe "Create Source" do
  it "should create a source" do
    with_pg do |config|
      ActiveRecord::Base.connection.execute get_sql "factory/create_factories"
      ActiveRecord::Base.connection.execute get_sql "factory/create_products"
      Factory.establish_connection config
      Product.establish_connection config
    end


    f = Factory.create(name: 'Herbet Schwin')






  end
end
