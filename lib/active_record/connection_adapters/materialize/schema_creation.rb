# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class SchemaCreation < AbstractAdapter::SchemaCreation # :nodoc:
        private
          def visit_TableDefinition(o)
            create_sql = +"CREATE#{table_modifier_in_create(o)} TABLE "
            create_sql << "IF NOT EXISTS " if o.if_not_exists
            create_sql << "#{quote_table_name(o.name)} "

            statements = o.columns.map { |c| accept c }

            if supports_indexes_in_create?
              statements.concat(o.indexes.map { |column_name, options| index_in_create(o.name, column_name, options) })
            end

            if supports_foreign_keys?
              statements.concat(o.foreign_keys.map { |to_table, options| foreign_key_in_create(o.name, to_table, options) })
            end

            create_sql << "(#{statements.join(', ')})" if statements.present?
            add_table_options!(create_sql, table_options(o))
            create_sql << " AS #{to_sql(o.as)}" if o.as
            create_sql
          end

          def add_column_options!(sql, options)
            sql << " DEFAULT #{quote_default_expression(options[:default], options[:column])}" if options_include_default?(options)
            # must explicitly check for :null to allow change_column to work on migrations
            if options[:null] == false
              sql << " NOT NULL"
            end
            sql
          end

      end
    end
  end
end
