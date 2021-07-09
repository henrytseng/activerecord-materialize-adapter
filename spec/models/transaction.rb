# frozen_string_literal: true

class Transaction < ActiveRecord::Base
  belongs_to :product
end
