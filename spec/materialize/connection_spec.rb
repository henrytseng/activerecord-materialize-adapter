require 'spec_helper'

describe "Connection" do
  it "should initialize adapter without issue" do
    expect(ActiveRecord::ConnectionAdapters::MaterializeAdapter).to be_truthy
  end

  it "should handle an available connection" do
    response = ActiveRecord::Base.connection.execute "select now();"
    result = response.first['now'].try :to_s
    expect(result.length).not_to be 0
  end
end
