# frozen_string_literal: true

class Product < ActiveRecord::Base
  belongs_to :factory
  has_many :transactions
end
