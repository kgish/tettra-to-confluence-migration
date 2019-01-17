# frozen_string_literal: true

require 'json'
require 'csv'
# require 'fileutils'
require 'dotenv/load'
require 'rest-client'
require 'base64'
require 'date'

# Check that the correct ruby version is being used.
version = File.read(".ruby-version")
puts "Ruby version: #{RUBY_VERSION}"
unless RUBY_VERSION == version
  puts "Ruby version = '#{version}' is required, run the following command first:"
  puts "rvm use #{version}"
  exit
end

# Load environment
DEBUG = ENV['DEBUG'] == 'true'
DATA = ENV['DATA'] || 'data'
CONVERTER = ENV['CONVERTER'] || 'markdown2confluence'
EXT = ENV['EXT'] || 'confluence'
API = ENV['API'] || throw('API must be defined')
SPACE = ENV['SPACE'] || throw('SPACE must be defined')
USER = ENV['USER'] || throw('USER must be defined')
EMAIL = ENV['EMAIL'] || throw('EMAIL must be defined')
PASSWORD = ENV['PASSWORD'] || throw('PASSWORD must be defined')

# Display environment
puts
puts "DEBUG:    : '#{DEBUG}'"
puts "DATA      : '#{DATA}'"
puts "CONVERTER : '#{CONVERTER}'"
puts "EXT       : '#{EXT}'"
puts "API       : '#{API}'"
puts "SPACE     : '#{SPACE}'"
puts "USER      : '#{USER}'"
puts "PASSWORD  : '*******'"
puts

HEADERS = {
    'Authorization': "Basic #{Base64.encode64("#{EMAIL}:#{PASSWORD}")}",
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json'
}.freeze

def confluence_get_spaces
  url = "#{API}/space"
  results = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    body = JSON.parse(response.body)
    results = body['results']
    puts "GET #{url} => OK"
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  results
end

# id, key, name, type, status
def confluence_get_space(name)
  return confluence_get_spaces.find {|space| space['name'] == name}
end

def write_csv_file(filename, results)
  puts filename
  CSV.open(filename, 'wb') do |csv|
    # Scan whole file to collect all possible field names so that
    # the list of columns is complete.
    fields = []
    results.each do |result|
      result.keys.each do |field|
        fields << field unless fields.include?(field)
      end
    end
    csv << fields
    results.each do |result|
      row = []
      fields.each do |field|
        row.push(result[field])
      end
      csv << row
    end
  end
end

# POST wiki/rest/api/content
# {
#     "type": "page",
#     "title": <TITLE>,
#     "space": { "key": <KEY> },
#     "body": {
#         "storage": {
#             "value": <CONTENT>,
#             "representation": "storage"
#         }
#     }
# }
#
def confluence_create_page(key, title, content)
  payload = {
      "type": "page",
      "title": title,
      "space": {"key": key},
      "body": {
          "storage": {
              "value": content,
              "representation": "storage"
          }
      }
  }
end

space = confluence_get_space(SPACE)

if space
  puts "Found space='#{SPACE}' => ok"
else
  puts "Cannot find space='#{SPACE}' => exit"
  exit
end

# Convert all markdown (.md) files in data directory to confluence.
# files = Dir["#{DATA}/*.md"]
# puts "\nFILES: #{files.length}"
# files.each do |file|
#   outfile = "#{file.sub(/\.md$/, '')}.#{EXT}"
#   output = `#{CONVERTER} #{file} >#{outfile}`
#   puts output unless output.length === 0
#   puts outfile
# end

# files = Dir["#{DATA}/*.md"]
# files.each do |file|
#   content = File.read(file)
#   content.scan /\[(.+?)\]\((.+?)\)/ do |match|
#     text = match[0]
#     url = match[1]
#     puts "#{file}: #{url}"
#   end
# end

results = []
files = Dir["#{DATA}/*.#{EXT}"]
files.each do |file|
  content = File.read(file)
  title = File.basename(file, ".#{EXT}").gsub('-', ' ').capitalize
  puts "#{title}"
  results << confluence_create_page(space['key'], title, content)
end

write_csv_file('results.csv', results)
puts "\nDone!"

