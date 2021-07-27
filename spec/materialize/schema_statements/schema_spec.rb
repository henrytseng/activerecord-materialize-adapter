require 'spec_helper'

describe "SchemaStatements - schema" do
  context "schema support" do
    it "should check if public schema exists" do
      with_materialize do |config|
        expect(connection.schema_exists?('public')).to be_truthy
      end
    end

    it "should retrieve default search path" do
      with_materialize do |config|
        binding.pry
      end
    end
  end

  context "schema add/remove" do
    it "should create and drop schema" do
      with_materialize do |config|
        connection.create_schema(:dolor)
        expect(connection.schema_exists?(:dolor)).to be_truthy

        connection.drop_schema(:dolor)
        expect(connection.schema_exists?(:dolor)).to be_falsy
      end
    end
  end
end
