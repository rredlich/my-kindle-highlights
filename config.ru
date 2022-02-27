require 'rubygems'
require 'bundler'
require 'sinatra'
require 'json'
require 'byebug'

Bundler.require

require './app.rb'
run KindleHighlights
