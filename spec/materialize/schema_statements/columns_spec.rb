require 'spec_helper'

describe "Column" do
  around(:each) do |example|
    with_materialize do |config|
      connection.create_table('sed') do |t|
        t.string :name
        t.integer :quantity
      end
      example.run
    end
  end

  context "column names" do
    it "should list" do
      binding.pry
    end
  end
end
