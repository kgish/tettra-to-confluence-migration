# frozen_string_literal: true

require 'json'
require 'csv'
require 'fileutils'
require 'dotenv/load'
require 'rest-client'
require 'base64'
require 'date'

# Check that the correct ruby version is being used.
version = File.read(".ruby-version")
unless RUBY_VERSION == version
  puts "Ruby version = '#{version}' is required, run the following command first:"
  puts "rvm use #{version}"
  exit
end

# Load environment
@debug = ENV['DEBUG'] == 'true'
@data_dir = ENV['DATA_DIR'] || 'data'

# Display environment
puts
puts "--- ENVIRONMENT ---"
puts "DEBUG=#{@debug}"
puts "DATA_DIR=#{@data_dir}"
puts "-------------------"

# List all files present in data directory
puts
files = Dir.children(@data_dir)
puts "--- FILES (#{files.length}) ---"
files.each do |file|
  puts file
end
puts "--- FILES ---"
