# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class Column < ActiveRecord::ConnectionAdapters::Column # :nodoc:
        delegate :oid, :fmod, to: :sql_type_metadata

        def array
          sql_type_metadata.sql_type.end_with?("[]")
        end
        alias :array? :array

        def sql_type
          super.sub(/\[\]\z/, "")
        end
      end
    end
    MaterializeColumn = Materialize::Column # :nodoc:
  end
end
