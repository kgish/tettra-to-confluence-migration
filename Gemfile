# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.4.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'dotenv'
gem 'rest-client'
# gem 'i18n'

gem 'rubocop', require: false

gem 'markdown2confluence'