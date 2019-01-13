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
@converter = ENV['CONVERTER'] || 'markdown2confluence'

# Display environment
puts "\n--- ENVIRONMENT ---"
puts "DEBUG:     '#{@debug}'"
puts "DATA_DIR:  '#{@data_dir}'"
puts "CONVERTER: '#{@converter}'"
puts "-------------------"

# List all files present in data directory
files = Dir.children(@data_dir)
puts "\nFILES: #{files.length}"
files.each do |file|
  next unless /\.md$/.match(file)
  infile = "#{@data_dir}/#{file}"
  text = File.read(infile)
  puts "#{file} => #{text.length}"
  outfile = "#{@data_dir}/#{file.sub(/\.md$/, '')}.confluence"
  output = `#{@converter} #{infile} >#{outfile} 2>&1`
  puts outfile
end
puts "\nDone!"
