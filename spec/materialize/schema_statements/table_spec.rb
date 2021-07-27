require 'spec_helper'

describe "SchemaStatements" do
  context "create and drop table" do
    it "should create-drop table" do
      with_materialize do |config|
        connection.create_table('foo')
        res = connection.execute("SHOW TABLES")
        results = res.values.flatten
        expect(results).to include('foo')

        connection.drop_table('foo')
        res = connection.execute("SHOW TABLES")
        results = res.values.flatten
        expect(results).not_to include('foo')
      end
    end
  end
end
