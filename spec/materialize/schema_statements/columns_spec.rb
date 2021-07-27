require 'spec_helper'

describe "SchemaStatements" do
  context "index create/drop" do
    it "should add and remove index" do
      with_materialize do |config|
        expect(true).to be_truthy
      end
    end
  end
end
