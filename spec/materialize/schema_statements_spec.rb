require 'spec_helper'

describe "SchemaStatements" do
  context "sanity checks" do
    it "should create other databases without conflict" do
      with_pg do |config|
        response = ActiveRecord::Base.connection.execute "select version();"
        result = response.values.first
        expect(result.first).not_to include "materialized"
      end
    end

    it "should initialize adapter without issue" do
      with_materialize do |config|
        expect(ActiveRecord::ConnectionAdapters::MaterializeAdapter).to be_truthy
      end
    end

    it "should handle an available connection" do
      with_materialize do |config|
        response = ActiveRecord::Base.connection.execute "select now();"
        result = response.first['now'].try :to_s
        expect(result.length).not_to be 0

        response = ActiveRecord::Base.connection.execute "select version();"
        result = response.values.first
        expect(result.first).to include "materialized"
      end
    end
  end

  context "create and drop database" do
    it "should recreate database without error" do
      with_materialize do |config|
        ActiveRecord::Base.connection.recreate_database(config['database'])
        res = ActiveRecord::Base.connection.execute("SHOW DATABASES")
        results = res.values.flatten
        expect(results).to include(config['database'])
      end
    end
  end

  context "create and drop table" do
    it "should create-drop table" do
      with_materialize do |config|
        ActiveRecord::Base.connection.create_table('foo')
        res = ActiveRecord::Base.connection.execute("SHOW TABLES")
        results = res.values.flatten
        expect(results).to include('foo')

        ActiveRecord::Base.connection.drop_table('foo')
        res = ActiveRecord::Base.connection.execute("SHOW TABLES")
        results = res.values.flatten
        expect(results).not_to include('foo')
      end
    end
  end
end
