# frozen_string_literal: true

require "active_record/type"
require "active_record/connection_adapters/materialize/oid/array"
require "active_record/connection_adapters/materialize/oid/bit"
require "active_record/connection_adapters/materialize/oid/bit_varying"
require "active_record/connection_adapters/materialize/oid/bytea"
require "active_record/connection_adapters/materialize/oid/date"
require "active_record/connection_adapters/materialize/oid/date_time"
require "active_record/connection_adapters/materialize/oid/decimal"
require "active_record/connection_adapters/materialize/oid/enum"
require "active_record/connection_adapters/materialize/oid/jsonb"
require "active_record/connection_adapters/materialize/oid/oid"

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module OID # :nodoc:
      end
    end
  end
end
