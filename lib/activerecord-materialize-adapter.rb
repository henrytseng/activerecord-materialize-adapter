# frozen_string_literal: true

require 'active_support'
require 'active_record'
require 'active_record/connection_adapters/deduplicable'
require 'active_record/connection_adapters/abstract/quoting'
require 'active_record/connection_adapters/abstract/database_statements'
require 'active_record/connection_adapters/abstract/database_limits'
require 'active_record/connection_adapters/abstract/schema_statements'
require 'active_record/connection_adapters/abstract/query_cache'
require 'active_record/connection_adapters/abstract/savepoints'
require 'active_record/connection_adapters'
require 'active_record/connection_adapters/column'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql/quoting'
require 'active_record/connection_adapters/postgresql/database_statements'
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/connection_adapters/materialize_adapter.rb'


