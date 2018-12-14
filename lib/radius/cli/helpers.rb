# frozen_string_literal: true

require 'English'
require 'fileutils'
require 'pathname'

module Radius
  module Cli
    module Helpers
      APP_ROOT = Pathname.getwd.ascend.find { |path| path.join("Gemfile").exist? }

      def self.included(klass)
        klass.include FileUtils
      end

    module_function

      def app_root
        APP_ROOT
      end

      def system!(*args)
        system(*args) || abort("\n== Command #{args} failed ==")
      end
    end
  end
end
