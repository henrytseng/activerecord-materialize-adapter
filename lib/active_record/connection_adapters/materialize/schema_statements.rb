# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module SchemaStatements
        # Drops the database specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {}) #:nodoc:
          drop_database(name)
          create_database(name, options)
        end

        # Create a new Materialize database. Options include <tt>:owner</tt>, <tt>:template</tt>,
        # <tt>:encoding</tt> (defaults to utf8), <tt>:collation</tt>, <tt>:ctype</tt>,
        # <tt>:tablespace</tt>, and <tt>:connection_limit</tt> (note that MySQL uses
        # <tt>:charset</tt> while Materialize uses <tt>:encoding</tt>).
        #
        # Example:
        #   create_database config[:database], config
        #   create_database 'foo_development', encoding: 'unicode'
        def create_database(name, options = {})
          options = {}.merge(options.symbolize_keys)
          if_exists = "IF NOT EXISTS " unless [false, 'false', '0', 0].include? options[:if_exists]

          execute "CREATE DATABASE #{if_exists}#{quote_table_name(name)}"
        end

        # Drops a Materialize database.
        #
        # Example:
        #   drop_database 'matt_development'
        def drop_database(name) #:nodoc:
          execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
        end

        def drop_table(table_name, options = {}) # :nodoc:
          execute "DROP TABLE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(table_name)}#{' CASCADE' if options[:force] == :cascade}"
        end

        # Returns true if schema exists.
        def schema_exists?(name)
          schema_names.include? name.to_s
        end

        # Verifies existence of an index with a given name.
        def index_name_exists?(table_name, index_name)
          available_indexes = execute(<<~SQL, "SCHEMA")
            SHOW INDEXES FROM #{quote_table_name(table_name)}
          SQL
          available_indexes.map { |c| c['key_name'] }.include? index_name.to_s
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name) # :nodoc:
          available_indexes = execute(<<~SQL, "SCHEMA")
            SHOW INDEXES FROM #{quote_table_name(table_name)}
          SQL
          available_indexes.group_by { |c| c['key_name'] }.map do |k, v|
            index_name = k
            IndexDefinition.new(
              table_name,
              index_name,
              unique = false,
              columns = v.map { |c| c['column_name'] },
              lengths: {},
              orders: {},
              opclasses: {},
              where: nil,
              type: nil,
              using: nil,
              comment: nil
            )
          end
        end

        def table_options(table_name) # :nodoc:
          if comment = table_comment(table_name)
            { comment: comment }
          end
        end

        # Returns a comment stored in database for given table
        def table_comment(table_name) # :nodoc:
          scope = quoted_scope(table_name, type: "BASE TABLE")
          if scope[:name]
            query_value(<<~SQL, "SCHEMA")
              SELECT pg_catalog.obj_description(c.oid, 'pg_class')
              FROM pg_catalog.pg_class c
                LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE c.relname = #{scope[:name]}
                AND c.relkind IN (#{scope[:type]})
                AND n.nspname = #{scope[:schema]}
            SQL
          end
        end

        # Unsupported current_database() use default config
        def current_database
          @config[:database]
        end

        # Returns the current schema name.
        def current_schema
          query_value("SELECT current_schema", "SCHEMA")
        end

        # Get encoding of database
        def encoding
          query_value("SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = #{quote(current_database)}", "SCHEMA")
        end

        # Unsupported collation
        def collation
          nil
        end

        # Get ctype
        def ctype
          query_value("SELECT datctype FROM pg_database WHERE datname = #{quote(current_database)}", "SCHEMA")
        end

        # Returns an array of schema names.
        def schema_names
          query_values(<<~SQL, "SCHEMA")
            SELECT
              s.name
            FROM mz_schemas s
            LEFT JOIN mz_databases d ON s.database_id = d.id
            WHERE
              d.name = #{quote(current_database)}
          SQL
        end

        # Creates a schema for the given schema name.
        def create_schema(schema_name)
          execute "CREATE SCHEMA #{quote_schema_name(schema_name.to_s)}"
        end

        # Drops the schema for the given schema name.
        def drop_schema(schema_name, options = {})
          execute "DROP SCHEMA#{' IF EXISTS' if options[:if_exists]} #{quote_schema_name(schema_name.to_s)} CASCADE"
        end

        # Returns the active schema search path.
        def schema_search_path
          @schema_search_path ||= query_value("SHOW search_path", "SCHEMA")
        end

        # Returns the sequence name for compatability
        def default_sequence_name(table_name, pk = "id") #:nodoc:
          Materialize::Name.new(nil, "#{table_name}_#{pk}_seq").to_s
        end

        # Primary keys -  approximation
        def primary_keys(table_name) # :nodoc:
          available_indexes = execute(<<~SQL, "SCHEMA").group_by { |c| c['key_name'] }
            SHOW INDEXES FROM #{quote_table_name(table_name)}
          SQL
          possible_primary = available_indexes.keys.select { |c| c.include? "primary_idx" }
          if possible_primary.size == 1
            available_indexes[possible_primary.first].map { |c| c['column_name'] }
          else
            []
          end
        end

        # Renames a table with index references
        def rename_table(table_name, new_name)
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
          if index_name_exists?(new_name, "#{table_name}_primary_idx")
            rename_index(new_name, "#{table_name}_primary_idx", "#{new_name}_primary_idx")
          end
          rename_table_indexes(table_name, new_name)
        end

        # https://materialize.com/docs/sql/alter-rename/
        def add_column(table_name, column_name, type, **options) #:nodoc:
          clear_cache!
          super
        end

        # https://materialize.com/docs/sql/alter-rename/
        def change_column(table_name, column_name, type, options = {}) #:nodoc:
          clear_cache!
          sqls, procs = Array(change_column_for_alter(table_name, column_name, type, options)).partition { |v| v.is_a?(String) }
          execute "ALTER TABLE #{quote_table_name(table_name)} #{sqls.join(", ")}"
          procs.each(&:call)
        end

        # https://materialize.com/docs/sql/alter-rename/
        def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
          execute "ALTER TABLE #{quote_table_name(table_name)} #{change_column_default_for_alter(table_name, column_name, default_or_changes)}"
        end

        # https://materialize.com/docs/sql/alter-rename/
        def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
          clear_cache!
          unless null || default.nil?
            column = column_for(table_name, column_name)
            execute "UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_expression(default, column)} WHERE #{quote_column_name(column_name)} IS NULL" if column
          end
          execute "ALTER TABLE #{quote_table_name(table_name)} #{change_column_null_for_alter(table_name, column_name, null, default)}"
        end

        # https://materialize.com/docs/sql/alter-rename/
        def rename_column(table_name, column_name, new_column_name) #:nodoc:
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def add_index(table_name, column_name, options = {}) #:nodoc:
          index_name, index_type, index_columns_and_opclasses, index_options, index_algorithm, index_using, comment = add_index_options(table_name, column_name, **options)
          execute("CREATE INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{index_columns_and_opclasses})")
        end

        def remove_index(table_name, options = {}) #:nodoc:
          table = Utils.extract_schema_qualified_name(table_name.to_s)

          if options.is_a?(Hash) && options.key?(:name)
            provided_index = Utils.extract_schema_qualified_name(options[:name].to_s)

            options[:name] = provided_index.identifier
            table = Materialize::Name.new(provided_index.schema, table.identifier) unless table.schema.present?

            if provided_index.schema.present? && table.schema != provided_index.schema
              raise ArgumentError.new("Index schema '#{provided_index.schema}' does not match table schema '#{table.schema}'")
            end
          end

          index_to_remove = Materialize::Name.new(table.schema, index_name_for_remove(table.to_s, options))
          algorithm =
            if options.is_a?(Hash) && options.key?(:algorithm)
              index_algorithms.fetch(options[:algorithm]) do
                raise ArgumentError.new("Algorithm must be one of the following: #{index_algorithms.keys.map(&:inspect).join(', ')}")
              end
            end
          execute "DROP INDEX #{algorithm} #{quote_table_name(index_to_remove)}"
        end

        # Renames an index of a table. Raises error if length of new
        # index name is greater than allowed limit.
        def rename_index(table_name, old_name, new_name)
          validate_index_length!(table_name, new_name)

          execute "ALTER INDEX #{quote_column_name(old_name)} RENAME TO #{quote_table_name(new_name)}"
        end

        # Maps logical Rails types to Materialize-specific data types.
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **) # :nodoc:
          type = type.to_sym if type
          if native = native_database_types[type]
            (native.is_a?(Hash) ? native[:name] : native).dup
          else
            type.to_s
          end
        end

        # TODO: verify same functionality as postgres
        # Materialize requires the ORDER BY columns in the select list for distinct queries, and
        # requires that the ORDER BY include the distinct column.
        def columns_for_distinct(columns, orders) #:nodoc:
          order_columns = orders.reject(&:blank?).map { |s|
            # Convert Arel node to string
            s = visitor.compile(s) unless s.is_a?(String)
            # Remove any ASC/DESC modifiers
            s
              .gsub(/\s+(?:ASC|DESC)\b/i, "")
              .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, "")
          }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          (order_columns << super).join(", ")
        end

        def update_table_definition(table_name, base) # :nodoc:
          Materialize::Table.new(table_name, base)
        end

        def create_schema_dumper(options) # :nodoc:
          Materialize::SchemaDumper.create(self, options)
        end

        # Validates the given constraint.
        #
        # Validates the constraint named +constraint_name+ on +accounts+.
        #
        #   validate_constraint :accounts, :constraint_name
        def validate_constraint(table_name, constraint_name)
          return unless supports_validate_constraints?

          at = create_alter_table table_name
          at.validate_constraint constraint_name

          execute schema_creation.accept(at)
        end

        # Validates the given foreign key.
        #
        # Validates the foreign key on +accounts.branch_id+.
        #
        #   validate_foreign_key :accounts, :branches
        #
        # Validates the foreign key on +accounts.owner_id+.
        #
        #   validate_foreign_key :accounts, column: :owner_id
        #
        # Validates the foreign key named +special_fk_name+ on the +accounts+ table.
        #
        #   validate_foreign_key :accounts, name: :special_fk_name
        #
        # The +options+ hash accepts the same keys as SchemaStatements#add_foreign_key.
        def validate_foreign_key(from_table, to_table = nil, **options)
          return unless supports_validate_constraints?

          fk_name_to_validate = foreign_key_for!(from_table, to_table: to_table, **options).name

          validate_constraint from_table, fk_name_to_validate
        end

        private
          def schema_creation
            Materialize::SchemaCreation.new(self)
          end

          def create_table_definition(*args, **options)
            Materialize::TableDefinition.new(self, *args, **options)
          end

          def create_alter_table(name)
            Materialize::AlterTable.new create_table_definition(name)
          end

          def new_column_from_field(table_name, field)
            column_name, type, nullable, default, comment = field
            type_metadata = fetch_type_metadata(column_name, type)
            default_value = extract_value_from_default(default)
            default_function = extract_default_function(default_value, default)
            Materialize::Column.new(
              column_name,
              default_value,
              type_metadata,
              nullable,
              default_function,
              comment: comment.presence
            )
          end

          def fetch_type_metadata(column_name, sql_type)
            cast_type = lookup_cast_type(sql_type)
            simple_type = SqlTypeMetadata.new(
              sql_type: sql_type,
              type: cast_type.type,
              limit: cast_type.limit,
              precision: cast_type.precision,
              scale: cast_type.scale,
            )
            Materialize::TypeMetadata.new(simple_type)
          end

          def sequence_name_from_parts(table_name, column_name, suffix)
            over_length = [table_name, column_name, suffix].sum(&:length) + 2 - max_identifier_length

            if over_length > 0
              column_name_length = [(max_identifier_length - suffix.length - 2) / 2, column_name.length].min
              over_length -= column_name.length - column_name_length
              column_name = column_name[0, column_name_length - [over_length, 0].min]
            end

            if over_length > 0
              table_name = table_name[0, table_name.length - over_length]
            end

            "#{table_name}_#{column_name}_#{suffix}"
          end

          def extract_foreign_key_action(specifier)
            case specifier
            when "c"; :cascade
            when "n"; :nullify
            when "r"; :restrict
            end
          end

          def add_column_for_alter(table_name, column_name, type, **options)
            return super unless options.key?(:comment)
            [super, Proc.new { change_column_comment(table_name, column_name, options[:comment]) }]
          end

          def change_column_for_alter(table_name, column_name, type, options = {})
            td = create_table_definition(table_name)
            cd = td.new_column_definition(column_name, type, **options)
            sqls = [schema_creation.accept(ChangeColumnDefinition.new(cd, column_name))]
            sqls << Proc.new { change_column_comment(table_name, column_name, options[:comment]) } if options.key?(:comment)
            sqls
          end

          def change_column_default_for_alter(table_name, column_name, default_or_changes)
            column = column_for(table_name, column_name)
            return unless column

            default = extract_new_default_value(default_or_changes)
            alter_column_query = "ALTER COLUMN #{quote_column_name(column_name)} %s"
            if default.nil?
              # <tt>DEFAULT NULL</tt> results in the same behavior as <tt>DROP DEFAULT</tt>. However, Materialize will
              # cast the default to the columns type, which leaves us with a default like "default NULL::character varying".
              alter_column_query % "DROP DEFAULT"
            else
              alter_column_query % "SET DEFAULT #{quote_default_expression(default, column)}"
            end
          end

          def change_column_null_for_alter(table_name, column_name, null, default = nil)
            "ALTER COLUMN #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL"
          end

          def add_index_opclass(quoted_columns, **options)
            opclasses = options_for_index_columns(options[:opclass])
            quoted_columns.each do |name, column|
              column << " #{opclasses[name]}" if opclasses[name].present?
            end
          end

          def add_options_for_index_columns(quoted_columns, **options)
            quoted_columns = add_index_opclass(quoted_columns, **options)
            super
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)
            scope[:type] ||= "'table','view'"
            sql = <<~SQL
              SELECT
                o.name
              FROM mz_objects o
              LEFT JOIN mz_schemas s ON o.schema_id = s.id
              LEFT JOIN mz_databases d ON s.database_id = d.id
              LEFT JOIN mz_sources src ON src.id = o.id
              LEFT JOIN mz_indexes i ON i.on_id = o.id
              WHERE
                d.name = #{quote(current_database)}
                AND s.name =  #{scope[:schema]}
                AND o.type IN (#{scope[:type]})
            SQL

            # Sources
            sql += " AND src.id is NULL" unless scope[:type].include? 'source'

            # Find with name
            sql += " AND o.name = #{scope[:name]}" if scope[:name]

            sql += " GROUP BY o.id, o.name"
            if type == "MATERIALIZED"
              sql += " HAVING COUNT(i.id) > 0"
            elsif scope[:type].include?('view')
              sql += " HAVING COUNT(i.id) = 0"
            end

            sql
          end

          def quoted_scope(name = nil, type: nil)
            schema, name = extract_schema_qualified_name(name)
            type = \
              case type
              when "BASE TABLE"
                "'table'"
              when "MATERIALIZED"
                "'view'"
              when "SOURCE"
                "'source'"
              when "VIEW"
                "'view'"
              end
            scope = {}
            scope[:schema] = schema ? quote(schema) : "ANY (current_schemas(false))"
            scope[:name] = quote(name) if name
            scope[:type] = type if type
            scope
          end

          def extract_schema_qualified_name(string)
            name = Utils.extract_schema_qualified_name(string.to_s)
            [name.schema, name.identifier]
          end
      end
    end
  end
end
