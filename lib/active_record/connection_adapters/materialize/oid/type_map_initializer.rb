# frozen_string_literal: true

require "active_support/core_ext/array/extract"

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module OID # :nodoc:
        # This class uses the data from Materialize mz_types table to build
        # the OID -> Type mapping.
        #   - OID is an integer representing the type.
        #   - Type is an OID::Type object.
        # This class has side effects on the +store+ passed during initialization.
        class TypeMapInitializer # :nodoc:
          def initialize(store)
            @store = store
          end

          def run(records)
            nodes = records.reject { |row| @store.key? row["oid"].to_i }
            mapped = nodes.extract! { |row| @store.key? row["name"] }

            mapped.each { |row| register_mapped_type(row) }
          end

          def query_conditions_for_initial_load
            known_type_names = @store.keys.map { |n| "'#{n}'" }
            known_type_types = %w('r' 'e' 'd')
            <<~SQL % [known_type_names.join(", "), known_type_types.join(", ")]
              AND t.name IN (%s)
            SQL
          end

          private
            def register_mapped_type(row)
              alias_type row["oid"], row["name"]
            end

            def register(oid, oid_type = nil, &block)
              oid = assert_valid_registration(oid, oid_type || block)
              if block_given?
                @store.register_type(oid, &block)
              else
                @store.register_type(oid, oid_type)
              end
            end

            def alias_type(oid, target)
              oid = assert_valid_registration(oid, target)
              @store.alias_type(oid, target)
            end

            def register_with_subtype(oid, target_oid)
              if @store.key?(target_oid)
                register(oid) do |_, *args|
                  yield @store.lookup(target_oid, *args)
                end
              end
            end

            def assert_valid_registration(oid, oid_type)
              raise ArgumentError, "can't register nil type for OID #{oid}" if oid_type.nil?
              oid.to_i
            end
        end
      end
    end
  end
end
