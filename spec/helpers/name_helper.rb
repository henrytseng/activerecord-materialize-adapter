# frozen_string_literal: true

module NameHelper
  def load_names()
    @names ||= File.open("spec/fixtures/names.csv", 'r') do |f|
      f.readlines.map(&:strip)
    end
  end

  def random_name
    load_names.sample
  end
end
