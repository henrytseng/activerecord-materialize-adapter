require 'spec_helper'

describe "Rake tasks" do
  it "should create and drop database without error" do
    with_materialize do |config|
      options = config
      ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
      ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
    end
  end

  it "should create database if exists by default without error" do
    with_materialize do |config|
      options = config
      ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
      ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
      ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
    end
  end
end
