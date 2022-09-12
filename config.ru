require 'rubygems'
require 'bundler'
require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require 'dotenv'

Bundler.require(:default, ENV.fetch('RACK_ENV', 'development'))
Dotenv.load('config/.env')

require './app'
run KindleHighlights
