require 'spec_helper'

describe "Insert" do
  around(:each) do |example|
    with_materialize do |config|
      connection.create_table('sed') do |t|
        t.string :name
        t.integer :quantity
      end
      example.run
    end
  end

  context 'when building insert' do
    it "should build insert with types" do
      binding.pry
    end
  end
end
