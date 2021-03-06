# frozen_string_literal: true

# Make sure we're using pg high enough for type casts and Ruby 2.2+ compatibility
gem "pg", ">= 0.18", "< 2.0"
require "pg"

# Use async_exec instead of exec_params on pg versions before 1.1
class ::PG::Connection # :nodoc:
  unless self.public_method_defined?(:async_exec_params)
    remove_method :exec_params
    alias exec_params async_exec
  end
end

require 'arel'
require 'active_support/all'
require "active_record/schema_dumper"
require "active_record/connection_adapters/abstract_adapter"
require "active_record"

require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/materialize/column"
require "active_record/connection_adapters/materialize/database_statements"
require "active_record/connection_adapters/materialize/explain_pretty_printer"
require "active_record/connection_adapters/materialize/oid"
require "active_record/connection_adapters/materialize/quoting"
require "active_record/connection_adapters/materialize/referential_integrity"
require "active_record/connection_adapters/materialize/schema_creation"
require "active_record/connection_adapters/materialize/schema_definitions"
require "active_record/connection_adapters/materialize/schema_dumper"
require "active_record/connection_adapters/materialize/schema_statements"
require "active_record/connection_adapters/materialize/schema/source_statements"
require "active_record/connection_adapters/materialize/schema/view_statements"
require "active_record/connection_adapters/materialize/type_metadata"
require "active_record/connection_adapters/materialize/utils"
require "active_record/tasks/materialize_database_tasks"
require 'materialize/errors/incomplete_input'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects
    def materialize_connection(config)
      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PG::Connection.connect.
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      conn_params.slice!(*valid_conn_param_keys)

      conn = PG.connect(conn_params)
      ConnectionAdapters::MaterializeAdapter.new(conn, logger, conn_params, config)
    rescue ::PG::Error => error
      if error.message.include?(conn_params[:dbname])
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
  end

  module ConnectionAdapters
    # The Materialize adapter works with the native C (https://bitbucket.org/ged/ruby-pg) driver.
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to a Unix-domain socket in /tmp. On machines without Unix-domain sockets,
    #   the default is to connect to localhost.
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - Defaults to be the same as the operating system name of the user running the application.
    # * <tt>:password</tt> - Password to be used if the server demands password authentication.
    # * <tt>:database</tt> - Defaults to be the same as the user name.
    # * <tt>:schema_search_path</tt> - An optional schema search path for the connection given
    #   as a string of comma-separated schema names. This is backward-compatible with the <tt>:schema_order</tt> option.
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO
    #   <encoding></tt> call on the connection.
    # * <tt>:min_messages</tt> - An optional client min messages that is used in a
    #   <tt>SET client_min_messages TO <min_messages></tt> call on the connection.
    # * <tt>:variables</tt> - An optional hash of additional parameters that
    #   will be used in <tt>SET SESSION key = val</tt> calls on the connection.
    # * <tt>:insert_returning</tt> - An optional boolean to control the use of <tt>RETURNING</tt> for <tt>INSERT</tt> statements
    #   defaults to true.
    #
    # Any further options are used as connection parameters to libpq. See
    # https://www.postgresql.org/docs/current/static/libpq-connect.html for the
    # list of parameters.
    #
    # In addition, default connection parameters of libpq can be set per environment variables.
    # See https://www.postgresql.org/docs/current/static/libpq-envars.html .
    class MaterializeAdapter < AbstractAdapter
      ADAPTER_NAME = "Materialize"

      ##
      # :singleton-method:
      # Materialize allows the creation of "unlogged" tables, which do not record
      # data in the Materialize Write-Ahead Log. This can make the tables faster,
      # but significantly increases the risk of data loss if the database
      # crashes. As a result, this should not be used in production
      # environments. If you would like all created tables to be unlogged in
      # the test environment you can add the following line to your test.rb
      # file:
      #
      #   ActiveRecord::ConnectionAdapters::MaterializeAdapter.create_unlogged_tables = true
      class_attribute :create_unlogged_tables, default: false

      NATIVE_DATABASE_TYPES = {
        primary_key: "bigint",
        string:      { name: "character varying" },
        text:        { name: "text" },
        integer:     { name: "integer" },
        bigint:      { name: "int8" },
        float:       { name: "float4" },
        double:      { name: "float8" },
        decimal:     { name: "decimal" },
        datetime:    { name: "timestamp" },
        timestampz:  { name: "timestamp with time zone" },
        time:        { name: "time" },
        date:        { name: "date" },
        binary:      { name: "bytea" },
        boolean:     { name: "boolean" },
        map:         { name: "map" },
        json:        { name: "jsonb" },
        interval:    { name: "interval" },
        record:      { name: "record" },
        oid:         { name: "oid" },
      }

      OID = Materialize::OID #:nodoc:

      include Materialize::Quoting
      include Materialize::ReferentialIntegrity
      include Materialize::SchemaStatements
      include Materialize::DatabaseStatements
      include Materialize::Schema::SourceStatements
      include Materialize::Schema::ViewStatements

      def supports_bulk_alter?
        true
      end

      # TODO: test transaction isolation
      def supports_transaction_isolation?
        true
      end

      def supports_views?
        true
      end

      def supports_json?
        true
      end

      # TODO: test insert returning
      def supports_insert_returning?
        true
      end

      class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
        def initialize(connection, max)
          super(max)
          @connection = connection
          @counter = 0
        end

        def next_key
          "a#{@counter + 1}"
        end

        def []=(sql, key)
          super.tap { @counter += 1 }
        end

        private
          def dealloc(key)
            @connection.query "DEALLOCATE #{key}" if connection_active?
          rescue PG::Error
          end

          def connection_active?
            @connection.status == PG::CONNECTION_OK
          rescue PG::Error
            false
          end
      end

      # Initializes and connects a Materialize adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger, config)

        @connection_parameters = connection_parameters

        # @local_tz is initialized as nil to avoid warnings when connect tries to use it
        @local_tz = nil
        @max_identifier_length = nil

        configure_connection
        add_pg_encoders
        add_pg_decoders

        @type_map = Type::HashLookupTypeMap.new
        initialize_type_map
        @local_tz = execute("SHOW TIMEZONE", "SCHEMA").first["TimeZone"]
      end

      def self.database_exists?(config)
        !!ActiveRecord::Base.materialize_connection(config)
      rescue ActiveRecord::NoDatabaseError
        false
      end

      # Is this connection alive and ready for queries?
      def active?
        @lock.synchronize do
          @connection.query "SELECT 1"
        end
        true
      rescue PG::Error
        false
      end

      # Close then reopen the connection.
      def reconnect!
        @lock.synchronize do
          super
          @connection.reset
          configure_connection
        rescue PG::ConnectionBad
          connect
        end
      end

      def reset!
        @lock.synchronize do
          clear_cache!
          reset_transaction
          unless @connection.transaction_status == ::PG::PQTRANS_IDLE
            @connection.query "ROLLBACK"
          end
          @connection.query "DISCARD ALL"
          configure_connection
        end
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        @lock.synchronize do
          super
          @connection.close rescue nil
        end
      end

      def discard! # :nodoc:
        super
        @connection.socket_io.reopen(IO::NULL) rescue nil
        @connection = nil
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end

      def supports_ddl_transactions?
        true
      end

      def supports_advisory_locks?
        true
      end

      def supports_explain?
        true
      end

      def supports_ranges?
        true
      end
      deprecate :supports_ranges?

      def supports_materialized_views?
        true
      end

      def supports_optimizer_hints?
        unless defined?(@has_pg_hint_plan)
          @has_pg_hint_plan = extension_available?("pg_hint_plan")
        end
        @has_pg_hint_plan
      end

      def supports_common_table_expressions?
        true
      end

      def supports_lazy_transactions?
        true
      end

      def get_advisory_lock(lock_id) # :nodoc:
        unless lock_id.is_a?(Integer) && lock_id.bit_length <= 63
          raise(ArgumentError, "Materialize requires advisory lock ids to be a signed 64 bit integer")
        end
        query_value("SELECT pg_try_advisory_lock(#{lock_id})")
      end

      def release_advisory_lock(lock_id) # :nodoc:
        unless lock_id.is_a?(Integer) && lock_id.bit_length <= 63
          raise(ArgumentError, "Materialize requires advisory lock ids to be a signed 64 bit integer")
        end
        query_value("SELECT pg_advisory_unlock(#{lock_id})")
      end

      # Returns the configured supported identifier length supported by Materialize
      def max_identifier_length
        @max_identifier_length || 64
      end

      # Set the authorized user for this session
      def session_auth=(user)
        clear_cache!
        execute("SET SESSION AUTHORIZATION #{user}")
      end

      def column_name_for_operation(operation, node) # :nodoc:
        OPERATION_ALIASES.fetch(operation) { operation.downcase }
      end

      OPERATION_ALIASES = { # :nodoc:
        "maximum" => "max",
        "minimum" => "min",
        "average" => "avg",
      }

      # Returns the version of the connected Materialize server.
      def get_database_version # :nodoc:
        @connection.server_version
      end
      alias :materialize_version :database_version

      def default_index_type?(index) # :nodoc:
        index.using == :btree || super
      end

      def build_insert_sql(insert) # :nodoc:
        sql = +"INSERT #{insert.into} #{insert.values_list}"

        if insert.skip_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
        elsif insert.update_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
          sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
        end

        sql << " RETURNING #{insert.returning}" if insert.returning
        sql
      end

      def check_version # :nodoc:
        if database_version < 90300
          raise "Your version of Materialize (#{database_version}) is too old. Active Record supports Materialize >= 9.3."
        end
      end

      private
        # See https://www.postgresql.org/docs/current/static/errcodes-appendix.html
        VALUE_LIMIT_VIOLATION = "22001"
        NUMERIC_VALUE_OUT_OF_RANGE = "22003"
        NOT_NULL_VIOLATION    = "23502"
        FOREIGN_KEY_VIOLATION = "23503"
        UNIQUE_VIOLATION      = "23505"
        SERIALIZATION_FAILURE = "40001"
        DEADLOCK_DETECTED     = "40P01"
        LOCK_NOT_AVAILABLE    = "55P03"
        QUERY_CANCELED        = "57014"

        def translate_exception(exception, message:, sql:, binds:)
          return exception unless exception.respond_to?(:result)

          case exception.result.try(:error_field, PG::PG_DIAG_SQLSTATE)
          when UNIQUE_VIOLATION
            RecordNotUnique.new(message, sql: sql, binds: binds)
          when FOREIGN_KEY_VIOLATION
            InvalidForeignKey.new(message, sql: sql, binds: binds)
          when VALUE_LIMIT_VIOLATION
            ValueTooLong.new(message, sql: sql, binds: binds)
          when NUMERIC_VALUE_OUT_OF_RANGE
            RangeError.new(message, sql: sql, binds: binds)
          when NOT_NULL_VIOLATION
            NotNullViolation.new(message, sql: sql, binds: binds)
          when SERIALIZATION_FAILURE
            SerializationFailure.new(message, sql: sql, binds: binds)
          when DEADLOCK_DETECTED
            Deadlocked.new(message, sql: sql, binds: binds)
          when LOCK_NOT_AVAILABLE
            LockWaitTimeout.new(message, sql: sql, binds: binds)
          when QUERY_CANCELED
            QueryCanceled.new(message, sql: sql, binds: binds)
          else
            super
          end
        end

        def get_oid_type(oid, fmod, column_name, sql_type = "")
          if !type_map.key?(oid)
            load_additional_types([oid])
          end

          type_map.fetch(oid, fmod, sql_type) {
            warn "unknown OID #{oid}: failed to recognize type of '#{column_name}'. It will be treated as String."
            Type.default_value.tap do |cast_type|
              type_map.register_type(oid, cast_type)
            end
          }
        end

        def load_additional_types(oids = nil)
          initializer = OID::TypeMapInitializer.new(type_map)

          query = <<~SQL
            SELECT t.id, t.oid, t.schema_id, t.name
            FROM mz_types as t
            LEFT JOIN mz_schemas s ON t.schema_id = s.id
            LEFT JOIN mz_databases d ON s.database_id = d.id
            WHERE
              (d.name = #{quote(current_database)} OR s.name = 'pg_catalog')
          SQL

          if oids
            query += "AND t.oid IN (%s)" % oids.join(", ")
          else
            query += initializer.query_conditions_for_initial_load
          end

          execute_and_clear(query, "SCHEMA", []) do |records|
            initializer.run(records)
          end
        end

        def initialize_type_map(m = type_map)
          m.register_type "int2", Type::Integer.new(limit: 2)
          m.register_type "int4", Type::Integer.new(limit: 4)
          m.register_type "int8", Type::Integer.new(limit: 8)
          m.alias_type "int", "int4"
          m.alias_type "integer", "int4"
          m.alias_type "bigint", "int8"
          m.register_type "oid", OID::Oid.new
          m.register_type "float4", Type::Float.new
          m.alias_type "float8", "float4"
          m.alias_type "double", "float4"
          m.register_type "text", Type::Text.new
          m.alias_type "varchar", "text"

          m.register_type "boolean", Type::Boolean.new
          register_class_with_limit m, "bytea", OID::BitVarying

          m.alias_type "timestamptz", "timestamp"
          m.register_type "date", OID::Date.new

          m.register_type "bytea", OID::Bytea.new
          m.register_type "jsonb", OID::Jsonb.new
          m.alias_type "json", "jsonb"

          m.register_type "interval" do |_, _, sql_type|
            precision = extract_precision(sql_type)
            OID::SpecializedString.new(:interval, precision: precision)
          end

          register_class_with_precision m, "time", Type::Time
          register_class_with_precision m, "timestamp", OID::DateTime

          load_additional_types
        end

        # Extracts the value from a Materialize column default definition.
        def extract_value_from_default(default)
          case default
            # Quoted types
          when /\A[\(B]?'(.*)'.*::"?([\w. ]+)"?(?:\[\])?\z/m
            # The default 'now'::date is CURRENT_DATE
            if $1 == "now" && $2 == "date"
              nil
            else
              $1.gsub("''", "'")
            end
            # Boolean types
          when "true", "false"
            default
            # Numeric types
          when /\A\(?(-?\d+(\.\d*)?)\)?(::bigint)?\z/
            $1
            # Object identifier types
          when /\A-?\d+\z/
            $1
          else
            # Anything else is blank, some user type, or some function
            # and we can't know the value of that, so return nil.
            nil
          end
        end

        def extract_default_function(default_value, default)
          default if has_default_function?(default_value, default)
        end

        def has_default_function?(default_value, default)
          !default_value && %r{\w+\(.*\)|\(.*\)::\w+|CURRENT_DATE|CURRENT_TIMESTAMP}.match?(default)
        end

        FEATURE_NOT_SUPPORTED = "0A000" #:nodoc:

        def execute_and_clear(sql, name, binds, prepare: false)
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
          end

          if without_prepared_statement?(binds)
            result = exec_no_cache(sql, name, [])
          else
            result = exec_no_cache(sql, name, binds)
          end
          ret = yield result
          result.clear
          ret
        end

        def exec_no_cache(sql, name, binds)
          materialize_transactions

          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          update_typemap_for_default_timezone

          typed_binds = type_casted_binds(binds)
          log(sql, name, binds, typed_binds) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.exec_params(prepare_statement(sql, typed_binds), [])
            end
          end
        rescue ActiveRecord::StatementInvalid,
               PG::InternalError => error
          if error.message.include? "At least one input has no complete timestamps yet"
            raise ::Materialize::Errors::IncompleteInput, error.message
          else
            raise
          end
        end

        # Annoyingly, the code for prepared statements whose return value may
        # have changed is FEATURE_NOT_SUPPORTED.
        #
        # This covers various different error types so we need to do additional
        # work to classify the exception definitively as a
        # ActiveRecord::PreparedStatementCacheExpired
        #
        # Check here for more details:
        # https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/utils/cache/plancache.c#l573
        CACHED_PLAN_HEURISTIC = "cached plan must not change result type"
        def is_cached_plan_failure?(e)
          pgerror = e.cause
          code = pgerror.result.result_error_field(PG::PG_DIAG_SQLSTATE)
          code == FEATURE_NOT_SUPPORTED && pgerror.message.include?(CACHED_PLAN_HEURISTIC)
        rescue
          false
        end

        def in_transaction?
          open_transactions > 0
        end

        # Returns the statement identifier for the client side cache
        # of statements
        def sql_key(sql)
          "#{sql}"
        end

        def prepare_statement(sql, binds)
          parametrized_statement = sql.split(/\s+/)
          binds.each_with_index do |n, i|
            index = i + 1
            part = \
              case n
              when String
                "'#{quote_string(n)}'"
              when Numeric
                n.to_s
              end

            parametrized_statement = parametrized_statement.map do |token|
              token
                .gsub("$#{index}", part)
                .gsub("($#{index}", "(#{part}")
                .gsub("$#{index})", "#{part})")
                .gsub("($#{index})", "(#{part})")
                .gsub(",$#{index}", ",#{part}")
                .gsub("$#{index},", "#{part},")
                .gsub(",$#{index},", ",#{part},")
            end
          end
          parametrized_statement.join ' '
        end

        # Connects to a Materialize server and sets up the adapter depending on the
        # connected server's characteristics.
        def connect
          @connection = PG.connect(@connection_parameters)
          configure_connection
          add_pg_encoders
          add_pg_decoders
        end

        # Configures the encoding, verbosity, schema search path, and time zone of the connection.
        # This is called by #connect and should not be called manually.
        def configure_connection
          if @config[:encoding]
            @connection.set_client_encoding(@config[:encoding])
          end

          variables = @config.fetch(:variables, {}).stringify_keys

          # If using Active Record's time zone support configure the connection to return
          # TIMESTAMP WITH ZONE types in UTC.
          unless variables["timezone"]
            if ActiveRecord::Base.default_timezone == :utc
              variables["timezone"] = "UTC"
            elsif @local_tz
              variables["timezone"] = @local_tz
            end
          end

          # SET statements from :variables config hash
          # https://www.postgresql.org/docs/current/static/sql-set.html
          variables.map do |k, v|
            if v == ":default" || v == :default
              # Sets the value to the global or compile default
              execute("SET SESSION #{k} TO DEFAULT", "SCHEMA")
            elsif !v.nil?
              execute("SET SESSION #{k} TO #{quote(v)}", "SCHEMA")
            end
          end
        end

        # Returns the list of a table's column names, data types, and default values.
        #
        # The underlying query is roughly:
        #  SELECT column.name, column.type, default.value, column.comment
        #    FROM column LEFT JOIN default
        #      ON column.table_id = default.table_id
        #     AND column.num = default.column_num
        #   WHERE column.table_id = get_table_id('table_name')
        #     AND column.num > 0
        #     AND NOT column.is_dropped
        #   ORDER BY column.num
        #
        # If the table name is not prefixed with a schema, the database will
        # take the first match from the schema search path.
        #
        # Query implementation notes:
        #  - format_type includes the column size constraint, e.g. varchar(50)
        #  - ::regclass is a function that gives the id for a table name
        def column_definitions(table_name)
          query(<<~SQL, "SCHEMA")
          SELECT
            c.name,
            c.type AS format_type,
            c.nullable,
            NULL AS default,
            NULL AS comment
          FROM mz_columns c
          LEFT JOIN mz_tables t ON c.id = t.id
          LEFT JOIN mz_schemas s ON t.schema_id = s.id
          LEFT JOIN mz_databases d ON s.database_id = d.id
          WHERE
            t.name = #{quote(table_name)}
            AND d.name = #{quote(current_database)}
            ORDER BY c.position
          SQL
        end

        def extract_table_ref_from_insert_sql(sql)
          sql[/into\s("[A-Za-z0-9_."\[\]\s]+"|[A-Za-z0-9_."\[\]]+)\s*/im]
          $1.strip if $1
        end

        def arel_visitor
          Arel::Visitors::PostgreSQL.new(self)
        end

        def build_statement_pool
          StatementPool.new(@connection, self.class.type_cast_config_to_integer(@config[:statement_limit]))
        end

        def can_perform_case_insensitive_comparison_for?(column)
          @case_insensitive_cache ||= {}
          @case_insensitive_cache[column.sql_type] ||= begin
            sql = <<~SQL
              SELECT exists(
                SELECT * FROM pg_proc
                WHERE proname = 'lower'
                  AND proargtypes = ARRAY[#{quote column.sql_type}::regtype]::oidvector
              ) OR exists(
                SELECT * FROM pg_proc
                INNER JOIN pg_cast
                  ON ARRAY[casttarget]::oidvector = proargtypes
                WHERE proname = 'lower'
                  AND castsource = #{quote column.sql_type}::regtype
              )
            SQL
            execute_and_clear(sql, "SCHEMA", []) do |result|
              result.getvalue(0, 0)
            end
          end
        end

        def add_pg_encoders
          map = PG::TypeMapByClass.new
          map[Integer] = PG::TextEncoder::Integer.new
          map[TrueClass] = PG::TextEncoder::Boolean.new
          map[FalseClass] = PG::TextEncoder::Boolean.new
          @connection.type_map_for_queries = map
        end

        def update_typemap_for_default_timezone
          if @default_timezone != ActiveRecord::Base.default_timezone && @timestamp_decoder
            decoder_class = ActiveRecord::Base.default_timezone == :utc ?
              PG::TextDecoder::TimestampUtc :
              PG::TextDecoder::TimestampWithoutTimeZone

            @timestamp_decoder = decoder_class.new(@timestamp_decoder.to_h)
            @connection.type_map_for_results.add_coder(@timestamp_decoder)
            @default_timezone = ActiveRecord::Base.default_timezone
          end
        end

        def add_pg_decoders
          @default_timezone = nil
          @timestamp_decoder = nil

          coders_by_name = {
            "int2" => PG::TextDecoder::Integer,
            "int4" => PG::TextDecoder::Integer,
            "int8" => PG::TextDecoder::Integer,
            "integer" => PG::TextDecoder::Integer,
            "bigint" => PG::TextDecoder::Integer,
            "oid" => PG::TextDecoder::Integer,
            "float" => PG::TextDecoder::Float,
            "float4" => PG::TextDecoder::Float,
            "float8" => PG::TextDecoder::Float,
            "double" => PG::TextDecoder::Float,
            "bool" => PG::TextDecoder::Boolean,
            "boolean" => PG::TextDecoder::Boolean,
          }

          if defined?(PG::TextDecoder::TimestampUtc)
            # Use native PG encoders available since pg-1.1
            coders_by_name["timestamp"] = PG::TextDecoder::TimestampUtc
            coders_by_name["timestamptz"] = PG::TextDecoder::TimestampWithTimeZone
          end

          known_coder_types = coders_by_name.keys.map { |n| quote(n) }
          query = <<~SQL % known_coder_types.join(", ")
            SELECT t.oid, t.typname
            FROM pg_type as t
            WHERE t.typname IN (%s)
          SQL
          coders = execute_and_clear(query, "SCHEMA", []) do |result|
            result
              .map { |row| construct_coder(row, coders_by_name[row["typname"]]) }
              .compact
          end

          map = PG::TypeMapByOid.new
          coders.each { |coder| map.add_coder(coder) }
          @connection.type_map_for_results = map

          # extract timestamp decoder for use in update_typemap_for_default_timezone
          @timestamp_decoder = coders.find { |coder| coder.name == "timestamp" }
          update_typemap_for_default_timezone
        end

        def construct_coder(row, coder_class)
          return unless coder_class
          coder_class.new(oid: row["oid"].to_i, name: row["typname"])
        end

        ActiveRecord::Type.add_modifier({ array: true }, OID::Array, adapter: :materialize)
        ActiveRecord::Type.register(:binary, OID::Bytea, adapter: :materialize)
        ActiveRecord::Type.register(:date, OID::Date, adapter: :materialize)
        ActiveRecord::Type.register(:datetime, OID::DateTime, adapter: :materialize)
        ActiveRecord::Type.register(:decimal, OID::Decimal, adapter: :materialize)
        ActiveRecord::Type.register(:enum, OID::Enum, adapter: :materialize)
        ActiveRecord::Type.register(:jsonb, OID::Jsonb, adapter: :materialize)
    end
  end
end
