# frozen_string_literal: true

require 'thor'

module Radius
  module Cli
    class App < Thor
      def self.exit_on_failure?
        true
      end
    end
  end
end
