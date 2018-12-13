# frozen_string_literal: true

require 'English'
require 'pathname'
require 'fileutils'
include FileUtils # rubocop:disable Style/MixinUsage

# path to your application root.
APP_ROOT = Pathname.getwd.ascend.find { |path| path.join("Gemfile").exist? } 


def system!(*args)
  system(*args) || abort("\n== Command #{args} failed ==")
end
