# frozen_string_literal: true

namespace :db do
  namespace :materialize do
    desc 'Setup Materialize database'
    task setup: [:load_config] do
      environments = [Rails.env]
      environments << 'test' if Rails.env.development?
      environments.each do |environment|
        puts environment
        ActiveRecord::Base.configurations
                          .configs_for(env_name: environment)
                          .reject { |env| env.configuration_hash[:database].blank? }
                          .each do |env|
          ActiveRecord::ConnectionAdapters::Materialize::MaterializeDatabaseTasks.new(env).setup_materialize
        end
      end
    end
  end
end
