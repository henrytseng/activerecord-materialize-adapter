require 'spec_helper'

describe "SchemaStatements" do
  around(:each) do |example|
    with_materialize do |config|
      connection.create_table :foo do |t|
        t.string :name
        t.string :category
      end
      example.run
    end
  end

  context "index create/drop" do
    it "should add and remove index" do
      connection.add_index(:foo, [:id, :name], name: :foobar)
      expect(connection.index_name_exists?(:foo, :foobar)).to be_truthy

      connection.remove_index(:foo, name: :foobar)
      expect(connection.index_name_exists?(:foo, :foobar)).to be_falsy
    end
  end

  context "index rename" do
    it "should add and rename index" do
      connection.add_index(:foo, [:id, :name], name: :foobar)
      expect(connection.index_name_exists?(:foo, :foobar)).to be_truthy

      connection.rename_index(:foo, :foobar, :quox)
      expect(connection.index_name_exists?(:foo, :quox)).to be_truthy
      expect(connection.index_name_exists?(:foo, :foobar)).to be_falsy
    end
  end

  context "when supporting primary key" do
    it "should return a valid primary key sequence name minimally" do
      expect(connection.default_sequence_name(:foo)).to eq "foo_id_seq"
    end
  end
end
