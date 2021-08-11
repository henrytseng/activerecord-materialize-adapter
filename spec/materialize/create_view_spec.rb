require 'spec_helper'
require 'retriable'

describe "Create View" do
  it "should create an adhoc view and select its data" do
    with_materialize do |config|
      connection.execute get_sql('pseudo_source/create_data')
      res = connection.execute get_sql('pseudo_source/select_data')
      values_list = res.values
      expect(values_list).to eq [["a", 1], ["a", 2], ["a", 3], ["a", 4], ["b", 5], ["c", 6], ["c", 7]]
    end
  end

  it "should create an adhoc view and create an aggregated data view" do
    with_materialize do |config|
      connection.execute get_sql('pseudo_source/create_data')

      # Select view
      res = connection.execute get_sql('pseudo_source/select_aggregated_sum')
      key_sums = res.values
      expect(key_sums).to eq [["a", 10], ["b", 5], ["c", 13]]

      # Create view
      connection.execute get_sql('pseudo_source/create_key_sums_aggregated_sum')
      res = connection.execute get_sql('pseudo_source/select_key_sums')
      key_sums_from_view = res.values
      expect(key_sums_from_view).to eq [["28"]]
    end
  end

  it "should create view with joined aggregated key sums" do
    with_materialize do |config|
      connection.execute get_sql('pseudo_source/create_data')
      connection.execute get_sql('pseudo_source/create_data_with_labels')

      # Select view
      res = connection.execute get_sql('pseudo_source/select_data_join_labels')
      key_sums_from_view = res.values
      expect(key_sums_from_view).to eq [["x", 10], ["y", 5], ["z", 13]]
    end
  end
end
