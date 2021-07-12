require 'spec_helper'

describe "Rake" do
  it "should load rake tasks" do
    ActiveRecord::Base.connection.execute "select now();"


  end
end
