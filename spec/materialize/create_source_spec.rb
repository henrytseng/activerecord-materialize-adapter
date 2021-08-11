# frozen_string_literal: true

require 'spec_helper'
require 'models/factory'
require 'models/product'
require 'models/transaction'
require 'models/product_total'
require 'models/factory_total'

describe "Create source" do
  it "should create a source" do
    source_config = nil
    with_pg do |config|
      source_config = config
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
          CONNECTION 'host=postgresdb port=5432 user=postgres password=#{source_config["password"]} dbname=#{source_config["database"]}'
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

      binding.pry

      product_id = ProductTotal.last.product_id
      transaction_total = Transaction.where(product_id: product_id).map { |t| t.quantity * t.price }.sum
      expect(transaction_total).to eq ProductTotal.find_by(product_id: product_id).total

      binding.pry


      transaction = Transaction.create(product_id: product_id, quantity: 1, price: 5, buyer: 'additional_txn')
      transaction_total2 = Transaction.where(product_id: product_id).map { |t| t.quantity * t.price }.sum
      expect(Transaction.connection.class).to eq ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      expect(ProductTotal.connection.class).to eq ActiveRecord::ConnectionAdapters::MaterializeAdapter
      expect(transaction_total2).to eq ProductTotal.find_by(product_id: product_id).total
      expect(transaction_total2).to be(transaction_total + 5)

      # Clean up
      ProductTotal.connection.close
      FactoryTotal.connection.close
      [
        "factory/drop_product_totals",
        "factory/drop_factory_totals"
      ].each { |s| connection.execute get_sql(s) }
    end
  end
end
