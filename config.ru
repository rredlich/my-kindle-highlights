require 'rubygems'
require 'bundler'
require 'json'

Bundler.require(:default, ENV.fetch('RACK_ENV', 'development'))

require './app'
run KindleHighlights
