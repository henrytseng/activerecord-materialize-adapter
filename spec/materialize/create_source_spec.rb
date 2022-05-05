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
      connection.create_source "product_transaction", source_type: :postgres, publication: "product_transaction", connection_params: source_config

      # Create a view from source
      connection.execute 'CREATE VIEWS FROM SOURCE "product_transaction" ("products", "factories", "transactions");'

      # Create aggregated view
      [
        "factory/create_product_totals",
        "factory/create_factory_totals"
      ].each { |s| connection.execute get_sql(s) }
      ProductTotal.establish_connection config
      FactoryTotal.establish_connection config

      # Check data has propagated
      product_id = Product.last.id
      total = Transaction.where(product_id: product_id).map { |t| t.quantity * t.price }.sum
      # expect(total).to eq ProductTotal.find_by(product_id: product_id).total

      # Create new data item
      Transaction.transaction do
        1000.times do |n|
          Transaction.create(product_id: product_id, quantity: 1, price: 5, buyer: 'additional_txn')
        end
      end

      # Sanity self check (caching-timing)
      total_after = Transaction.where(product_id: product_id).map { |t| t.quantity * t.price }.sum
      expect(total_after).to be(total + 5000)
      expect(Transaction.connection.class).to eq ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      expect(ProductTotal.connection.class).to eq ActiveRecord::ConnectionAdapters::MaterializeAdapter

      # Check materialized after
      await_replication(source_config)
      expect(ProductTotal.find_by(product_id: product_id).total).to eq total_after

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
