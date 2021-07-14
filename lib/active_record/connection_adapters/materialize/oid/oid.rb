# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module OID # :nodoc:
        class Oid < Type::UnsignedInteger # :nodoc:
          def type
            :oid
          end
        end
      end
    end
  end
end
