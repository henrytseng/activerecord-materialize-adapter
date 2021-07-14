require 'spec_helper'

describe "Create View" do
  it "should handle an available connection" do
    ActiveRecord::Base.connection.execute <<-SQL.squish
      CREATE MATERIALIZED VIEW pseudo_source (key, value) AS
        VALUES ('a', 1), ('a', 2), ('a', 3), ('a', 4),
        ('b', 5), ('c', 6), ('c', 7)
    SQL

    # TODO: figure out issues with performance issue
    res = ActiveRecord::Base.connection.execute <<-SQL.squish
      SELECT * FROM pseudo_source
    SQL

    binding.pry
  end
end
