# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class SchemaDumper < ActiveRecord::ConnectionAdapters::SchemaDumper # :nodoc:
        def dump(stream)
          header(stream)
          extensions(stream)
          tables(stream)
          views_and_sources(stream)
          trailer(stream)
          stream
        end

        def views_and_sources(stream)
          sorted_sources = @connection.sources.sort
          sorted_sources.each do |source_name|
            source(source_name, stream)
          end

          # TODO sort views by dependencies
          sorted_views = @connection.views.sort
          sorted_views.each do |view_name|
            view(view_name, stream)
          end
        end

        # Create source
        def source(source_name, stream)
          options = @connection.source_options(source_name)
          begin
            src_stream = StringIO.new

            src_stream.print "  create_source #{remove_prefix_and_suffix(source_name).inspect}"
            src_stream.print ", source_type: :#{options[:source_type]}" unless options[:source_type].nil?
            src_stream.puts ", publication: #{options[:publication].inspect}" unless options[:publication].nil?
            src_stream.puts ", materialize: #{options[:materialize]}" unless options[:materialize].nil?
            src_stream.puts

            src_stream.rewind
            stream.print src_stream.read

          rescue StandardError => e
            stream.puts "# Could not dump source #{source_name.inspect} because of following #{e.class}"
            stream.puts "#   #{e.message}"
            stream.puts
          end
        end

        # Create view
        def view(view_name, stream)
          creation_query = @connection.view_sql(view_name)
          begin
            src_stream = StringIO.new
            src_stream.puts "  create_view #{remove_prefix_and_suffix(view_name).inspect} do"

            src_stream.puts "    <<-SQL.squish"
            src_stream.puts "      #{creation_query}"
            src_stream.puts "    SQL"

            src_stream.puts "  end"
            src_stream.puts

            # TODO indexes

            src_stream.rewind
            stream.print src_stream.read

          rescue StandardError => e
            stream.puts "# Could not dump source #{source_name.inspect} because of following #{e.class}"
            stream.puts "#   #{e.message}"
            stream.puts
          end
        end

        def indexes_in_create(table, stream)
          if (indexes = @connection.indexes(table)).any?
            index_statements = indexes
              .select { |index| !index.name.include?("_primary_idx") }
              .map do |index|
                "    t.index #{index_parts(index).join(', ')}"
              end
            stream.puts index_statements.sort.join("\n") if index_statements.present?
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
