require 'spec_helper'

describe "Schema" do
  around(:each) do |example|
    with_materialize do |config|
      example.run
    end
  end

  context "with schema support" do
    it "should check if public schema exists" do
      expect(connection.schema_exists?('public')).to be_truthy
    end

    it "should retrieve default search path" do
      expect(connection.schema_search_path).to be_truthy
    end

    it "should get current schema" do
      expect(connection.current_schema).to eq 'public'
    end

    it "should get schema names" do
      expect(connection.schema_names).to eq ['public']
    end
  end

  context "when schema added/removed" do
    it "should create and drop schema" do
      connection.create_schema(:dolor)
      expect(connection.schema_exists?(:dolor)).to be_truthy

      connection.drop_schema(:dolor)
      expect(connection.schema_exists?(:dolor)).to be_falsy
    end
  end
end
