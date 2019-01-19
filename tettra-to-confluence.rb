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

def confluence_get_content(id)
  url = "#{API}/content/#{id}?expand=body.storage"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "GET #{url} => OK"
  rescue => error
    if error.response
      response = JSON.parse(error.response)
      statusCode = response['statusCode']
      message = response['message']
      puts "GET #{url} title='#{title}' => NOK statusCode='#{statusCode}', message='#{message}'"
    else
      puts "GET #{url} => NOK error='#{error}'"
    end
  end
  result
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
  result = nil
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
  }.to_json
  url = "#{API}/content"
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "POST #{url} title='#{title}' => OK"
  rescue => error
    if error.response
      response = JSON.parse(error.response)
      statusCode = response['statusCode']
      message = response['message']
      puts "POST #{url} title='#{title}' => NOK statusCode='#{statusCode}', message='#{message}'"
    else
      puts "POST #{url} => NOK error='#{error}'"
    end
  end
  result
end

space = confluence_get_space(SPACE)

if space
  puts "Found space='#{SPACE}' => OK"
else
  puts "Cannot find space='#{SPACE}' => exit"
  exit
end


#
#
links = []
files = Dir["#{DATA}/*.html"]
files.each do |file|
  counter = 0
  content = File.read(file)
  m = /^<html><head><title>(.*?)<\/title><\/head><body>(.*)<\/body><\/html>$/.match(content)
  title = m[1]
  filename = file.sub(/^#{DATA}\//, '')

  # <img src="https://tettra-production.s3.us-west-2.amazonaws.com/teams/37251/users/88716/y5TaEh2lPo7ui3vIR0r3znFYQ2JqgYXqvLd9ZDIO.png" alt="..." />
  content.scan(/<img src="(.*?)"/).each do |match|
    counter = counter + 1
    links << {
        counter: counter,
        filename: filename,
        title: title,
        tag: 'image',
        value: match[0]
    }
  end

  # <a href="https://app.tettra.co/teams/measurabl/pages/baseline-account-set-up-for-manual">
  content.scan(/<a href="(.*?)"/).each do |match|
    counter = counter + 1
    links << {
        counter: counter,
        filename: filename,
        title: title,
        tag: 'anchor',
        value: match[0]
    }
  end
end

write_csv_file('links.csv', links)
exit

results = []
files = Dir["#{DATA}/*.html"]
files.each do |file|
  content = File.read(file)
  m = /^<html><head><title>(.*?)<\/title><\/head><body>(.*)<\/body><\/html>$/.match(content)
  title = m[1]
  body = m[2]
  filename = file.sub(/^#{DATA}\//, '')
  if title && body
    puts "#{file} title='#{title}' => OK"
    result = confluence_create_page(space['key'], title, body)
    if (result)
      results << {
          result: 'OK',
          filename: filename,
          title: title,
          id: result['id']
      }
    else
      results << {
          result: 'NOK',
          filename: filename,
          title: title,
          id: 0
      }
    end
  else
    puts "#{file} title='#{title}' => NOK"
    results << {
        result: 'BAD',
        filename: filename,
        title: title,
        id: 0
    }
  end
end

write_csv_file('results.csv', results)

puts "\nDone!"
