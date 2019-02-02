#! /usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'dotenv/load'

# Load environment
DEBUG = ENV['DEBUG'] == 'true'
HOST = ENV['TETTRA_HOST'] || throw('TETTRA_HOST must be defined')
COMPANY = ENV['TETTRA_COMPANY'] || throw('TETTRA_COMPANY must be defined')
EMAIL = ENV['TETTRA_EMAIL'] || throw('TETTRA_EMAIL must be defined')
PASSWORD = ENV['TETTRA_PASSWORD'] || throw('TETTRA_PASSWORD must be defined')

# Display environment
puts
puts "DEBUG:    : '#{DEBUG}'"
puts "HOST      : '#{HOST}'"
puts "COMPANY   : '#{COMPANY}'"
puts "EMAIL     : '#{EMAIL}'"
puts "PASSWORD  : '*******'"
puts

# Fetch and parse HTML document
doc = Nokogiri::HTML(open(HOST))

# Login
h1 = doc.css('h1')
if h1.text != 'Sign in to your team'
  puts "Cannot find login page"
  exit
end

puts "Login"



#
    #        .get('h1').contains('Sign in to your team')
    #         .get('#email').type(Cypress.env('EMAIL'))
    #         .get('#password').type(Cypress.env('PASSWORD'))
    #         .get('input[type=submit]').click()
    #         .url().should('contain', Cypress.env('SPACE'))
    #         .get('.category-title a').each($el => {
    #             cy.log($el.text());
    #             cy.log($el.attr('href'));
    #         })
    # })