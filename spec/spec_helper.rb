# frozen_string_literal: true

require 'pry'
require "rspec/expectations"
require 'activerecord-materialize-adapter'
require 'helpers/database_helper'

ActiveRecord::Base.logger = Logger.new(STDOUT)

def clean_queue
  @clean_queue ||= []
end

def after_cleanup(&block)
  clean_queue.push &block
end

def before_cleanup(&block)
  clean_queue.unshift &block
end

RSpec.configure do |config|
  config.include DatabaseHelper

  if ENV['RAILS_ENV'] == 'test'
    at_exit do
      queue = clean_queue
      @clean_queue = nil
      queue.each do |task|
        task.call
      end
    end
  end
end