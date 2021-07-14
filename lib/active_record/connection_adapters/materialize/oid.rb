# frozen_string_literal: true

require "active_record/type"
require "active_record/connection_adapters/materialize/oid/array"
require "active_record/connection_adapters/materialize/oid/bit"
require "active_record/connection_adapters/materialize/oid/bit_varying"
require "active_record/connection_adapters/materialize/oid/bytea"
require "active_record/connection_adapters/materialize/oid/cidr"
require "active_record/connection_adapters/materialize/oid/date"
require "active_record/connection_adapters/materialize/oid/date_time"
require "active_record/connection_adapters/materialize/oid/decimal"
require "active_record/connection_adapters/materialize/oid/enum"
require "active_record/connection_adapters/materialize/oid/hstore"
require "active_record/connection_adapters/materialize/oid/inet"
require "active_record/connection_adapters/materialize/oid/jsonb"
require "active_record/connection_adapters/materialize/oid/money"
require "active_record/connection_adapters/materialize/oid/oid"
require "active_record/connection_adapters/materialize/oid/point"
require "active_record/connection_adapters/materialize/oid/legacy_point"
require "active_record/connection_adapters/materialize/oid/range"
require "active_record/connection_adapters/materialize/oid/specialized_string"
require "active_record/connection_adapters/materialize/oid/uuid"
require "active_record/connection_adapters/materialize/oid/vector"
require "active_record/connection_adapters/materialize/oid/xml"

require "active_record/connection_adapters/materialize/oid/type_map_initializer"

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module OID # :nodoc:
      end
    end
  end
end
