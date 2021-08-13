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

  let(:columns) { connection.columns(:sed) }

  context "column names" do
    it "should list" do
      expect(columns.map { |c| c.name }).to eq ['id', 'name', 'quantity']
      expect(columns.map { |c| c.type }).to eq [:integer, :integer, :text]
    end
  end
end
