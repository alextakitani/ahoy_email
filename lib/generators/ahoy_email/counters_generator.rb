require "rails/generators/active_record"

module AhoyEmail
  module Generators
    class  CountersGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      source_root File.join(__dir__, "templates")

      def copy_migration
        migration_template "counters.rb", "db/migrate/create_ahoy_counters.rb", migration_version: migration_version
      end

      def append_initializer
        file = "config/initializers/ahoy_email.rb"
        contents = File.exist?(file) ? File.read(file) : ""
        ["AhoyEmail.api = true", "AhoyEmail.subscribers << AhoyEmail::CountSubscriber"].each do |line|
          append_to_file file, "#{line}\n" unless contents.include?(line)
        end
      end

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
