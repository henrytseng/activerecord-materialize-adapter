require 'spec_helper'

describe "Connection" do
  before do
    create_db
  end

  after do
    drop_db_if_exists
  end

  it "should initialize adapter without issue" do
    expect(ActiveRecord::ConnectionAdapters::MaterializeAdapter).to be_truthy
  end

  it "should handle an available connection" do
    response = ActiveRecord::Base.connection.execute "select now();"
    rows = response.first
    result = rows.first
    expect(result).to be_truthy
  end
end

