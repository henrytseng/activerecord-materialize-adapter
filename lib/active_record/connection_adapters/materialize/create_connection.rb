# frozen_string_literal: true

require "pg"

module ActiveRecord  # :nodoc:
  module ConnectionHandling  # :nodoc:

    def materialize_connection(config)
      conn_params = config.symbolize_keys.compact

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PG.connect
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      conn_params.slice!(*valid_conn_param_keys)

      binding.pry
      ConnectionAdapters::MaterializeAdapter.new(
        ConnectionAdapters::MaterializeAdapter.new_client(conn_params),
        logger,
        conn_params,
        config
      )
    end

  end
end
