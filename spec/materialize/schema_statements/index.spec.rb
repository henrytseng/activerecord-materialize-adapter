require 'spec_helper'

describe "SchemaStatements" do
  context "index create/drop" do
    it "should add and remove index" do
      with_materialize do |config|
        ActiveRecord::Base.connection.create_table :foo do |t|
          t.string :name
          t.string :category
        end
        ActiveRecord::Base.connection.add_index(:foo, [:id, :name], name: :foobar)
        results = ActiveRecord::Base.connection.index_name_exists?(:foo, :foobar)
        expect(results).to be_truthy

        ActiveRecord::Base.connection.remove_index(:foo, name: :foobar)
        results = ActiveRecord::Base.connection.index_name_exists?(:foo, :foobar)
        expect(results).to be_falsy
      end
    end
  end
end
