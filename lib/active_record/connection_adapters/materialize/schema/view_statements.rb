# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module Schema
        module ViewStatements

          # Returns an array of view names defined in the database.
          def materialized_views
            query_values(data_source_sql(type: "MATERIALIZED"), "SCHEMA")
          end

          def view_sql(view_name)
            query("SHOW CREATE VIEW #{quote_table_name(view_name)}", "SCHEMA").first.last
          end

        end
      end
    end
  end
end