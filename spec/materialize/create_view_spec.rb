require 'spec_helper'
require 'retriable'

describe "Create View" do
  it "should create an adhoc view" do
    ActiveRecord::Base.connection.execute get_sql('create_pseudo_source')

    res = Retriable.retriable(tries: 3, on: ::Materialize::Errors::IncompleteInput) do
      ActiveRecord::Base.connection.execute get_sql('select_pseudo_source')
    end
    results = res.values
    expect(results).to eq [["a", 1], ["a", 2], ["a", 3], ["a", 4], ["b", 5], ["c", 6], ["c", 7]]
  end
end
