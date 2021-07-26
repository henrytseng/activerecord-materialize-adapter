require 'spec_helper'

describe "SchemaStatements - schema" do
  context "schema support" do
    it "should check if schema exists" do
      with_materialize do |config|
        results = ActiveRecord::Base.connection.schema_exists?('public')
        expect(results).to be_truthy
      end
    end
  end
end
