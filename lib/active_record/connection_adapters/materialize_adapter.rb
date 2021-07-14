# frozen_string_literal: true

require "active_record"

# autoload AbstractAdapter to avoid circular require and void context warnings
module ActiveRecord
  module ConnectionAdapters
    AbstractAdapter
  end
end

require "active_record/connection_adapters/abstract_adapter"
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/connection_adapters/materialize/version'
require 'active_record/connection_adapters/materialize/setup'
require 'active_record/connection_adapters/materialize/create_connection'
require 'active_record/connection_adapters/materialize/materialize_database_tasks'
require "active_record/connection_adapters/materialize/oid"
require "active_record/connection_adapters/materialize/quoting"
require "active_record/connection_adapters/materialize/referential_integrity"
require "active_record/connection_adapters/materialize/schema_statements"
require 'active_record/connection_adapters/materialize/database_statements'
require "active_record/connection_adapters/materialize/utils"


puts "read materialize_adapter"
ActiveRecord::ConnectionAdapters::Materialize.initial_setup

if defined?(Rails::Railtie)
  require "active_record/connection_adapters/materialize/railtie"
end

module ActiveRecord
  module ConnectionAdapters

    # The Materialize adapter works through pgwire and utilizes the same PostgreSQL adapter logic
    class MaterializeAdapter < AbstractAdapter
      ADAPTER_NAME = "Materialize"

      # TODO: build statements

      # TODO: types NATIVE_DATABASE_TYPES

      # TODO: types oid
      OID = Materialize::OID #:nodoc:

      include Materialize::Quoting
      include Materialize::ReferentialIntegrity
      include Materialize::SchemaStatements
      include Materialize::DatabaseStatements

      # TODO: define functionality checks (e.g. - supports_bulk_alter? ...)

      # TODO: statement pool?

      # Initializes and connects an adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger, config)

        # @local_tz is initialized as nil to avoid warnings when connect tries to use it
        @local_tz = nil
        @max_identifier_length = nil





        configure_connection
        add_pg_encoders
        add_pg_decoders

        @type_map = Type::HashLookupTypeMap.new
        initialize_type_map
        @local_tz = execute("SHOW TIMEZONE", "SCHEMA").first["TimeZone"]
        @use_insert_returning = @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
      end

      def adapter_name
        ADAPTER_NAME
      end

      private

        def configure_connection
          if @config[:encoding]
            @connection.set_client_encoding(@config[:encoding])
          end

          # Use standard-conforming strings so we don't have to do the E'...' dance.
          # set_standard_conforming_strings

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

        def add_pg_encoders
          map = PG::TypeMapByClass.new
          map[Integer] = PG::TextEncoder::Integer.new
          map[TrueClass] = PG::TextEncoder::Boolean.new
          map[FalseClass] = PG::TextEncoder::Boolean.new
          @connection.type_map_for_queries = map
        end

        def add_pg_decoders
          @default_timezone = nil
          @timestamp_decoder = nil

          coders_by_name = {
            "int2" => PG::TextDecoder::Integer,
            "int4" => PG::TextDecoder::Integer,
            "int8" => PG::TextDecoder::Integer,
            "oid" => PG::TextDecoder::Integer,
            "float4" => PG::TextDecoder::Float,
            "float8" => PG::TextDecoder::Float,
            "bool" => PG::TextDecoder::Boolean,
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

        # https://materialize.com/docs/sql/types/
        def initialize_type_map(m = type_map)
          m.register_type "bigint", Type::Integer.new(limit: 8)
          m.alias_type "int8", "bigint"

          m.register_type "boolean", Type::Boolean.new
          m.alias_type "bool", "boolean"

          m.register_type "bytea", OID::Bytea.new

          m.register_type "date", OID::Date.new

          m.register_type "double", Type::Float.new
          m.alias_type "float", "double"
          m.alias_type "float8", "double"

          m.register_type "int4", Type::Integer.new(limit: 8)
          m.alias_type "int", "int4"

          m.register_type "interval" do |_, _, sql_type|
            precision = extract_precision(sql_type)
            OID::SpecializedString.new(:interval, precision: precision)
          end

          m.register_type "jsonb", OID::Jsonb.new
          m.alias_type "json", "jsonb"

          # TODO: map
          # TODO: list

          m.register_type "numeric" do |_, fmod, sql_type|
            precision = extract_precision(sql_type)
            scale = extract_scale(sql_type)

            # The type for the numeric depends on the width of the field,
            # so we'll do something special here.
            #
            # When dealing with decimal columns:
            #
            # places after decimal  = fmod - 4 & 0xffff
            # places before decimal = (fmod - 4) >> 16 & 0xffff
            if fmod && (fmod - 4 & 0xffff).zero?
              # FIXME: Remove this class, and the second argument to
              # lookups on PG
              Type::DecimalWithoutScale.new(precision: precision)
            else
              OID::Decimal.new(precision: precision, scale: scale)
            end
          end

          # TODO: numeric, decimal

          m.register_type "oid", OID::Oid.new

          m.alias_type "real", "double"
          m.alias_type "float4", "double"

          # TODO: record

          m.register_type "text", Type::Text.new

          register_class_with_precision m, "time", Type::Time
          register_class_with_precision m, "timestamp", OID::DateTime
        end
    end
  end
end
