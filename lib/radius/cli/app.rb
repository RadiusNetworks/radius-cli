# frozen_string_literal: true

require 'thor'
require "radius/cli/puma_dev"

module Radius
  module Cli
    class App < Thor
      def self.exit_on_failure?
        true
      end

      register ::Radius::Cli::PumaDev, "puma_dev", "puma_dev", PumaDev::DESCRIPTION
    end
  end
end
