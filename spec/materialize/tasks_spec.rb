require 'spec_helper'

describe "Rake tasks" do
  it "should create and drop database without error" do
    options = configuration_options
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
  end

  it "should create database if exists by default without error" do
    options = configuration_options
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
  end

  it "should create database create database only if it does not exist" do
    options = configuration_options
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).drop
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
    ActiveRecord::Tasks::MaterializeDatabaseTasks.new(options).create
  end
end
