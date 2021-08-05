# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class SchemaDumper < ActiveRecord::ConnectionAdapters::SchemaDumper # :nodoc:
        def indexes_in_create(table, stream)
          if (indexes = @connection.indexes(table)).any?
            index_statements = indexes
              .select { |index| !index.name.include?("_primary_idx") }
              .map do |index|
                "    t.index #{index_parts(index).join(', ')}"
              end
            stream.puts index_statements.sort.join("\n")
          end
        end

        private
          def prepare_column_options(column)
            spec = super
            spec[:array] = "true" if column.array?
            spec
          end

          def default_primary_key?(column)
            schema_type(column) == :bigint
          end

          def schema_type(column)
            if column.bigint?
              :bigint
            else
              super
            end
          end
      end
    end
  end
end
