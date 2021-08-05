require 'spec_helper'

describe "Database" do
  context "sanity checks" do
    it "should create other databases without conflict" do
      with_pg do |config|
        expect(connection.query_value("select version()")).not_to include "materialized"
      end
    end

    it "should initialize adapter without issue" do
      with_materialize do |config|
        expect(ActiveRecord::ConnectionAdapters::MaterializeAdapter).to be_truthy
      end
    end

    it "should handle an available connection" do
      with_materialize do |config|
        response = connection.execute "select now();"
        result = response.first['now'].try :to_s
        expect(result.length).not_to be 0

        expect(connection.query_value("select version()")).to include "materialized"
      end
    end

    it "should handled nested connections" do
      with_materialize do |config|
        expect(connection.query_value("select version()")).to include "materialized"
        with_pg do |config|
          expect(connection.query_value("select version()")).not_to include "materialized"
        end
      end
    end
  end

  context "create and drop database" do
    it "should recreate database without error" do
      with_materialize do |config|
        connection.recreate_database(config['database'])
        res = connection.execute("SHOW DATABASES")
        results = res.values.flatten
        expect(results).to include(config['database'])
      end
    end

    it "should get encoding" do
      with_materialize do |config|
        connection.create_database(config['database'])
        expect(connection.encoding).to eq 'UTF8'
      end
    end

    it "should get ctype" do
      with_materialize do |config|
        connection.create_database(config['database'])
        expect(connection.ctype).to eq 'C'
      end
    end
  end

  context "when unsupported" do
    it "should not get collation" do
      with_materialize do |config|
        connection.create_database(config['database'])
        expect(connection.collation).to be_nil
      end
    end

    it "should get current database from config" do
      with_materialize do |config|
        connection.create_database(config['database'])
        expect(connection.current_database).to eq config['database']
      end
    end
  end
end
