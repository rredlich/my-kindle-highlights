require 'sinatra'
require 'json'
require 'byebug'

# Copied from the repo https://github.com/georgboe/kindleclippings and changed to work in spanish clippings
class Clipping
    attr_accessor :book_title, :author, :type, :location, :added_on, :content, :page

    def initialize(title, author, type, location, added_on, content, page = "0")
        @book_title = title
        @author = author
        @type = type
        @location = location
        @added_on = added_on
        @content = content
        @page = page.to_i
    end
    def to_hash
        {
            book_title: @book_title,
            author: @author,
            type: @type,
            location: @location,
            added_on: @added_on,
            content: @content,
            page: @page
        }
    end
    
    def to_json
        to_hash.to_json
    end
    
end

class ClippingResult < Array
    def by_author(author)
      filter_by_property(:author, author)
    end
    
    def by_book(book)
      filter_by_property(:book_title, book)
    end    

    private
    
    def filter_by_property(property, value)
        return self unless value

        if value.is_a?(Regexp)
            select_blk = lambda {|annotation| annotation.send(property) =~ value }
        else
            select_blk = lambda {|annotation| annotation.send(property).casecmp(value) == 0 }
        end
        self.select(&select_blk)
    end
end

get '/' do
    erb :index
end

post '/result' do
    @path = params['file']['tempfile']
    file_content = open(@path, 'r:bom|utf-8').read

    
    @clippings = ClippingResult.new

    file_content.split("=" * 10).each do |clipping|
        clipping.lstrip!

        lines = clipping.lines.to_a

        break if lines.empty?

        first_line = lines[0].strip.scan(/^(.+) \((.+)\)$/i).first
        second_line = lines[1].strip.scan(/^-\s(?:Mi\s|Tu\s)?(\w+) (?:en la página ([0-9-]*?) \| )?(?:(?:Posición|Location)? ([0-9-]*?) +\| )?Añadido el (.*)$/i).first

        if first_line.nil?
            title = lines[0].strip
            author = ""
        else
            title, author = *first_line
        end
        
        type, page, location, date = *second_line

        content = lines[3..-1].join("")
        @clippings << Clipping.new(title.gsub("\uFEFF", ""), author, type, location, date, content.strip, page)
    end

    @bookTitles = @clippings.map{|t| t.book_title}.uniq
    @clippingContent = @clippings.by_book(@title)
    
    erb :result
end