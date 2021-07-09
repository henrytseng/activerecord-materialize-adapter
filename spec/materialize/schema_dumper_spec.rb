require 'spec_helper'
require 'active_record/migration'
require 'models/factory'
require 'models/product'
require 'models/transaction'
require 'models/product_total'
require 'models/factory_total'

describe "SchemaDumper" do
  context "with tables" do
    around(:each) do |example|
      with_materialize do |config|
        ActiveRecord::InternalMetadata.create_table
        example.run
      end
    end

    it "should create idempotent schema dump" do
      migration = CreateDogMigration.new
      migration.migrate(:up)

      schema = StringIO.new.tap do |s|
        ActiveRecord::SchemaDumper.dump(connection, s)
      end.string

      # Remove
      migration.migrate(:down)

      # Rebuild
      eval schema

      schema_by_schema = StringIO.new.tap do |s|
        ActiveRecord::SchemaDumper.dump(connection, s)
      end.string
      expect(schema_by_schema).to eq(schema)
    end
  end

  context "with materialized views and source tables" do
    around(:each) do |example|
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
        # Create source
        # connection.execute <<~SQL.squish
        #   CREATE MATERIALIZED SOURCE "product_transaction" FROM POSTGRES
        #     CONNECTION 'host=postgresdb port=5432 user=postgres dbname=#{source_database}'
        #     PUBLICATION 'product_transaction'
        # SQL

        connection.create_source "product_transaction", source_type: :postgres, publication: "product_transaction", connection_params: source_config

        # Create a view from source
        connection.execute 'CREATE VIEWS FROM SOURCE "product_transaction" ("products", "factories", "transactions");'

        # Create aggregated view
        [
          "factory/create_product_totals",
          "factory/create_factory_totals",
          "factory/create_tags"
        ].each { |s| connection.execute get_sql(s) }

        example.run

        # Clean up
        ProductTotal.connection.close
        FactoryTotal.connection.close
        [
          "factory/drop_product_totals",
          "factory/drop_factory_totals"
        ].each { |s| connection.execute get_sql(s) }
      end
    end

    it "should create idempotent schema dump" do
      schema = StringIO.new.tap do |s|
        ActiveRecord::SchemaDumper.dump(connection, s)
      end.string

    end
  end
end

class CreateDogMigration < ActiveRecord::Migration::Current
  def up
    create_table("dog_owners") do |t|
    end

    create_table("dogs") do |t|
      t.column :name, :string
      t.column :nickname, :string, nullable: true
      t.datetime :birthdate, nullable: true, default: 'now()'
      t.column :identification_tag, :bytea, nullable: false
      t.integer :owner_id
      t.index [:name]
      t.timestamps
    end
  end
  def down
    drop_table("dogs")
    drop_table("dog_owners")
  end
end
