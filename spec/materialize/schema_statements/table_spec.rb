require 'spec_helper'

describe "Table" do
  around(:each) do |example|
    with_materialize do |config|
      connection.create_table('sed') do |t|
        t.string :name
        t.integer :quantity
      end
      example.run
    end
  end

  context "create and drop table" do
    it "should create-drop table" do
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

  context "create and rename table" do
    it "should rename a table" do
      expect(connection.tables).to eq ['sed']
      connection.rename_table(:sed, :quox)
      res = connection.execute("SHOW TABLES")
      results = res.values.flatten
      expect(results).not_to include('sed')

      res = connection.execute("SHOW INDEXES FROM quox")
      results = res.first
      expect(results['key_name']).to include('quox')
      expect(connection.tables).to eq ['quox']
    end
  end
end
