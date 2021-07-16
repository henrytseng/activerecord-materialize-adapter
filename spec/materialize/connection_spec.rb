require 'spec_helper'

describe "Connection" do
  it "should initialize adapter without issue" do
    with_materialize do |config|
      expect(ActiveRecord::ConnectionAdapters::MaterializeAdapter).to be_truthy
    end
  end

  it "should handle an available connection" do
    with_materialize do |config|
      response = ActiveRecord::Base.connection.execute "select now();"
      result = response.first['now'].try :to_s
      expect(result.length).not_to be 0
    end
  end
end
