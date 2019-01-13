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
DEBUG = ENV['DEBUG'] == 'true'
DATA = ENV['DATA'] || 'data'
CONVERTER = ENV['CONVERTER'] || 'markdown2confluence'
API = ENV['API'] || throw('API must be defined')
SPACE = ENV['SPACE'] || throw('SPACE must be defined')
USER = ENV['USER'] || throw('USER must be defined')
EMAIL = ENV['EMAIL'] || throw('EMAIL must be defined')
PASSWORD = ENV['PASSWORD'] || throw('PASSWORD must be defined')

# Display environment
puts "DEBUG:    : '#{DEBUG}'"
puts "DATA      : '#{DATA}'"
puts "CONVERTER : '#{CONVERTER}'"
puts "API       : '#{API}'"
puts "SPACE     : '#{SPACE}'"
puts "USER      : '#{USER}'"

HEADERS = {
    'Authorization': "Basic #{Base64.encode64("#{EMAIL}:#{PASSWORD}")}",
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json'
}.freeze

def get_spaces
  url = "#{API}/spaces"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    puts response.inspect
    puts "GET #{url} => OK"
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
end

get_spaces
exit

# List all files present in data directory
files = Dir.children(DATA)
puts "\nFILES: #{files.length}"
files.each do |file|
  next unless /\.md$/.match(file)
  infile = "#{DATA}/#{file}"
  outfile = "#{DATA}/#{file.sub(/\.md$/, '')}.confluence"
  output = `#{CONVERTER} #{infile} >#{outfile}`
  puts output unless output.length === 0
  puts outfile
end
puts "\nDone!"

