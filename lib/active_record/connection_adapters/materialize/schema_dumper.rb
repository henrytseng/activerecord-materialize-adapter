# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class SchemaDumper < ActiveRecord::ConnectionAdapters::SchemaDumper # :nodoc:

        def table(table, stream)
          columns = @connection.columns(table)
          begin
            self.table_name = table

            tbl = StringIO.new

            # first dump primary key column
            pk = @connection.primary_key(table)

            tbl.print "  create_table #{remove_prefix_and_suffix(table).inspect}"

            case pk
            when String
              tbl.print ", primary_key: #{pk.inspect}" unless pk == "id"
              pkcol = columns.detect { |c| c.name == pk }
              pkcolspec = column_spec_for_primary_key(pkcol)
              if pkcolspec.present?
                tbl.print ", #{format_colspec(pkcolspec)}"
              end
            when Array
              tbl.print ""
            else
              tbl.print ", id: false"
            end

            table_options = @connection.table_options(table)
            if table_options.present?
              tbl.print ", #{format_options(table_options)}"
            end

            tbl.puts ", force: :cascade do |t|"

            # then dump all non-primary key columns
            columns.each do |column|
              raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" unless @connection.valid_type?(column.type)
              next if column.name == pk || (pk.is_a?(Array) && pk.include?(column.name) && column.name == 'id')

              type, colspec = column_spec(column)
              if type.is_a?(Symbol)
                tbl.print "    t.#{type} #{column.name.inspect}"
              else
                tbl.print "    t.column #{column.name.inspect}, #{type.inspect}"
              end
              tbl.print ", #{format_colspec(colspec)}" if colspec.present?
              tbl.puts
            end

            indexes_in_create(table, tbl)

            tbl.puts "  end"
            tbl.puts

            tbl.rewind
            stream.print tbl.read
          rescue StandardError => e
            stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
            stream.puts "#   #{e.message}"
            stream.puts
          ensure
            self.table_name = nil
          end
        end

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
              :integer
            end
          end
      end
    end
  end
end
