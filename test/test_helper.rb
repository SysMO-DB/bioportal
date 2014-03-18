require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'active_record'
require_relative '../lib/bioportal'

class Test::Unit::TestCase
  def read_bioportal_api_key
    path = File.join(File.dirname(__FILE__),"bioportal_api_key")

    if File.exist?(path)
      @@bioportal_api_key ||= File.new(path).read
      @@bioportal_api_key
    else
      raise "You need a file test/bioportal_api_key which contains a string containing your api key. Without this, tests cannot run"
    end
  end
end