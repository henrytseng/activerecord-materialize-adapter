# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Materialize
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load "active_record/connection_adapters/materialize/databases.rake"
        end
      end
    end
  end
end
