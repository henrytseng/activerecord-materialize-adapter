# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      module Schema
        module SourceStatements

          def sources
            query_values(data_source_sql(type: "SOURCE"), "SCHEMA")
          end

          # Get source options from an existing source
          def source_options(source_name)
            name_ref, statement = query("SHOW CREATE SOURCE #{quote_table_name(source_name)}", "SCHEMA").first
            database_name, schema_name, publication_name = name_ref.split(".")
            materialized = !!/CREATE\sMATERIALIZED/.match(statement)
             _, source_type, _ = /FROM\s(POSTGRES|KAFKA\sBROKER)\sCONNECTION/.match(statement).to_s.split " "
             source_type = source_type.to_s.downcase.to_sym

            {
              database_name: database_name,
              schema_name: schema_name,
              source_name: source_name,
              source_type: source_type,
              publication: publication_name,
              materialized: materialized || source_type == :postgres
            }
          end

          # "host=postgresdb port=5432 user=postgres dbname=source_database"
          def select_database_config(connection_params)
            {
              host: connection_params['host'],
              port: connection_params['port'],
              user: connection_params['username'],
              dbname: connection_params['database'],
              password: connection_params['password']
            }.compact
          end

          def create_source(source_name, publication:, source_type: :postgres, materialized: true, connection_params: nil)
            materialized_statement = materialized ? 'MATERIALIZED ' : ''
            connection_string = select_database_config(connection_params).map { |k, v| [k, v].join("=") }.join(" ")
            case source_type
            when :postgres
              execute <<-SQL.squish
                CREATE #{materialized_statement}SOURCE #{quote_schema_name(source_name)} FROM POSTGRES
                  CONNECTION #{quote(connection_string)}
                  PUBLICATION #{quote(publication)}
              SQL
            else
              raise "Source type #{source_type} is currently unsupported for Materialized sources", NotImplementedError
            end
          end

          def drop_source(source_name)
          end

          def source_exists?(source_name)
          end
        end
      end
    end
  end
end
