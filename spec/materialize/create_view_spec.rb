require 'spec_helper'

describe "Create View" do
  it "should handle an available connection" do
    begin
      ActiveRecord::Base.connection.execute <<-SQL.squish
        CREATE MATERIALIZED VIEW pseudo_source (key, value) AS
          VALUES ('a', 1), ('a', 2), ('a', 3), ('a', 4),
          ('b', 5), ('c', 6), ('c', 7)
      SQL

      res = ActiveRecord::Base.connection.execute <<-SQL.squish
      SELECT * FROM pseudo_source
      SQL

    # TODO: figure out issues with performance issue https://github.com/MaterializeInc/materialize/issues/3122
    rescue ::ActiveRecord::StatementInvalid => e
      binding.pry
    end

    binding.pry
  end
end
