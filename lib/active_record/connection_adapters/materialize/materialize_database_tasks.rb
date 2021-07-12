# frozen_string_literal: true

puts "read database tasks"

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class MaterializeDatabaseTasks < ::ActiveRecord::Tasks::PostgreSQLDatabaseTasks
        def initialize(db_config)
          super
          ensure_installation_configs
        end

        def setup_materialize
          puts "setup_materialize"
          establish_su_connection
          if extension_names
            setup_materialize_from_extension
          end
          establish_connection(db_config)
        end

        # Override to set the database owner and call setup_materialize
        def create(master_established = false)
          establish_master_connection unless master_established
          extra_configs = { encoding: encoding }
          extra_configs[:owner] = username if has_su?
          connection.create_database(db_config.database, configuration_hash.merge(extra_configs))
          setup_materialize
        rescue ::ActiveRecord::StatementInvalid => error
          if /database .* already exists/ === error.message
            raise ::ActiveRecord::DatabaseAlreadyExists
          else
            raise
          end
        end

        private

        # Override to use su_username and su_password
        def establish_master_connection
          establish_connection(configuration_hash.merge(
            database:           "postgres",
            password:           su_password,
            schema_search_path: "public",
            username:           su_username
          ))
        end

        def establish_su_connection
          establish_connection(configuration_hash.merge(
            password:           su_password,
            schema_search_path: "public",
            username:           su_username
          ))
        end

        def username
          @username ||= configuration_hash[:username]
        end

        def quoted_username
          @quoted_username ||= ::ActiveRecord::Base.connection.quote_column_name(username)
        end

        def password
          @password ||= configuration_hash[:password]
        end

        def su_username
          @su_username ||= configuration_hash.fetch(:su_username, username)
        end

        def su_password
          @su_password ||= configuration_hash.fetch(:su_password, password)
        end

        def has_su?
          return @has_su if defined?(@has_su)

          @has_su = configuration_hash.include?(:su_username)
        end

        def search_path
          @search_path ||= configuration_hash[:schema_search_path].to_s.strip.split(",").map(&:strip)
        end

        def extension_names
          @extension_names ||= begin
            extensions = configuration_hash[:materialize_extension]
            case extensions
            when ::String
              extensions.split(",")
            when ::Array
              extensions
            else
              ["materialize"]
            end
          end
        end

        def ensure_installation_configs
          if configuration_hash[:setup] == "default" && !configuration_hash[:materialize_extension]
            share_dir = `pg_config --sharedir`.strip rescue "/usr/share"
            control_file = ::File.expand_path("extension/materialize.control", share_dir)
            if ::File.readable?(control_file)
              @configuration_hash = configuration_hash.merge(materialize_extension: "materialize").freeze
            end
          end
        end

        def setup_materialize_from_extension
          extension_names.each do |extname|
            if extname == "materialize_topology"
              unless search_path.include?("topology")
                raise ArgumentError, "'topology' must be in schema_search_path for materialize_topology"
              end
              connection.execute("CREATE EXTENSION IF NOT EXISTS #{extname} SCHEMA topology")
            else
              if (materialize_schema = configuration_hash[:materialize_schema])
                schema_clause = "WITH SCHEMA #{materialize_schema}"
                unless schema_exists?(materialize_schema)
                  connection.execute("CREATE SCHEMA #{materialize_schema}")
                  connection.execute("GRANT ALL ON SCHEMA #{materialize_schema} TO PUBLIC")
                end
              else
                schema_clause = ""
              end

              connection.execute("CREATE EXTENSION IF NOT EXISTS #{extname} #{schema_clause}")
            end
          end
        end

        def schema_exists?(schema_name)
          connection.execute(
            "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{schema_name}'"
          ).any?
        end
      end

      ::ActiveRecord::Tasks::DatabaseTasks.register_task(/materialize/, MaterializeDatabaseTasks)
    end
  end
end
