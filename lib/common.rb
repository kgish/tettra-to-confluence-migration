# frozen_string_literal: true

require 'json'
require 'csv'
require 'fileutils'
require 'dotenv/load'
require 'rest-client'
require 'base64'

# Check that the correct ruby version is being used.
version = File.read('.ruby-version').strip
puts "Ruby version: #{RUBY_VERSION}"
unless RUBY_VERSION == version
  puts "Ruby version = '#{version}' is required, run the following command first:"
  puts "rvm use #{version}"
  exit
end

# Load environment
DEBUG = ENV['DEBUG'] == 'true'
DATA = ENV['DATA'] || 'data'
IMAGES = ENV['IMAGES'] || 'images'
CONVERTER = ENV['CONVERTER'] || 'markdown2confluence'
EXT = ENV['EXT'] || 'confluence'
API = ENV['CONFLUENCE_API'] || throw('CONFLUENCE_API must be defined')
SPACE = ENV['CONFLUENCE_SPACE'] || throw('CONFLUENCE_SPACE must be defined')
EMAIL = ENV['CONFLUENCE_EMAIL'] || throw('CONFLUENCE_EMAIL must be defined')
PASSWORD = ENV['CONFLUENCE_PASSWORD'] || throw('CONFLUENCE_PASSWORD must be defined')
LOGFILE = ENV['TETTRA_LOGFILE'] || throw('TETTRA_LOGFILE must be defined')
COMPANY = ENV['TETTRA_COMPANY'] || throw('TETTRA_COMPANY must be defined')

# Display environment
puts
puts "DEBUG:    : '#{DEBUG}'"
puts "DATA      : '#{DATA}'"
puts "IMAGES    : '#{IMAGES}'"
puts "CONVERTER : '#{CONVERTER}'"
puts "EXT       : '#{EXT}'"
puts "API       : '#{API}'"
puts "SPACE     : '#{SPACE}'"
puts "PASSWORD  : '*******'"
puts "LOGFILE   : '#{LOGFILE}'"
puts "COMPANY   : '#{COMPANY}'"
puts

Dir.mkdir(DATA) unless File.exists?(DATA)
Dir.mkdir(IMAGES) unless File.exists?(IMAGES)

HEADERS = {
  'Authorization': "Basic #{Base64.encode64("#{EMAIL}:#{PASSWORD}")}",
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json'
}.freeze

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

def read_csv_file(pathname)
  csv = CSV::parse(File.open(pathname) {|f| f.read})
  fields = csv.shift
  fields = fields.map {|f| f.downcase.tr(' ', '_')}
  csv.map {|record| Hash[*fields.zip(record).flatten]}
end


def rest_client_exception(e, method, url, payload = {})
  message = 'Unknown error'
  begin
    err = JSON.parse(e.response)
    if err['errors'] && !err['errors'].empty?
      message = err['errors'].map {|k, v| "#{k}: #{v}"}.join(' | ')
    elsif err['errorMessages'] && !err['errorMessages'].empty?
      message = err['errorMessages'].join(' | ')
    elsif err['error']
      message = err['error']
      if err['error_description']
        message += ": #{err['error_description']}"
      end
    elsif err['status-code']
      message = "Status code: #{err['status-code']}"
    else
      message = e.to_s
    end
  rescue
    message = e.to_s
  end
  puts "#{method} #{url}#{payload.empty? ? '' : ' ' + payload.inspect} => NOK (#{message})"
  message
end
