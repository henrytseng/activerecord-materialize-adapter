# frozen_string_literal: true

require 'spec_helper'
require 'models/factory'
require 'models/product'
require 'models/transaction'
require 'models/product_total'
require 'models/factory_total'

describe "Create source" do
  it "should create a source" do
    source_database = nil
    with_pg do |config|
      source_database = config["database"]
      [
        "factory/create_factories",
        "factory/create_products",
        "factory/create_transactions",
        "factory/create_publication",
        "factory/insert_factories",
        "factory/insert_products",
        "factory/insert_transactions"
      ].each { |s| connection.execute get_sql(s) }
      Factory.establish_connection config
      Product.establish_connection config
      Transaction.establish_connection config
    end

    with_materialize do |config|
      # Create sourced
      connection.execute <<~SQL.squish
        CREATE MATERIALIZED SOURCE "product_transaction" FROM POSTGRES
          CONNECTION 'host=postgresdb port=5432 user=postgres dbname=#{source_database}'
          PUBLICATION 'product_transaction'
      SQL

      # Create a view from source
      connection.execute 'CREATE VIEWS FROM SOURCE "product_transaction" ("products", "factories", "transactions");'

      # Create aggregated view
      [
        "factory/create_product_totals",
        "factory/create_factory_totals"
      ].each { |s| connection.execute get_sql(s) }
      ProductTotal.establish_connection config
      FactoryTotal.establish_connection config

      # Clean up
      ProductTotal.connection.close
      FactoryTotal.connection.close
      [
        "factory/drop_product_totals",
        "factory/drop_factory_totals"
      ].each { |s| connection.execute get_sql(s) }
    end

    with_pg({ 'database' => source_database }) do |config|
      connection.execute get_sql("factory/drop_publication")
    end
  end
end
