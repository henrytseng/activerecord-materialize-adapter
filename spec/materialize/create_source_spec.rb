# frozen_string_literal: true

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

    20.times do
      factory = Factory.create(name: random_name)
      5.times do
        Product.create(name: random_name, factory: factory)
      end
    end

    with_materialize do

    end

    binding.pry





  end
end
