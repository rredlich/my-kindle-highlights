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
    def loc_to_i
        return location.split('-').map(&:to_i)
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

def write_notion_object(type, val)
    if type == 'content'
        object = {
            'object': 'block',
            'type': 'paragraph',
            'paragraph': {
                'rich_text': [{
                    'type': 'text',
                    'text': {
                      'content': val
                    }
                }]
            }
        }
    elsif type == 'location'
        object = {
            'object': 'block',
            'type': 'paragraph',
            'paragraph': {
                'rich_text': [{
                    'type': 'text',
                    'text': {
                        'content': val
                    },
                    'annotations': {
                        'italic': true,
                        'color': 'gray'
                    }
                }]
            }
        }
    end
    return object
end

def notion_login_validation()
    if session[:notion_id] == nil or session[:notion_db_id] == nil
        return false
    else
        client = Notion::Client.new(token: session[:notion_id])
        result = client.search(filter: { property: 'object', value: 'database' })

        if result.results[0].id == session[:notion_db_id]
            return true
        else
            return false
        end
    end
end

class KindleHighlights < Sinatra::Base
    configure :development do
        register Sinatra::Reloader
    end

    use Rack::Session::EncryptedCookie, :secret => ENV['ENC_SECRET_KEY']

    get '/' do
        @notion_login = notion_login_validation()
        @notion_workspace_name = session[:notion_ws_name]
        @notion_workspace_icon = session[:notion_ws_icon]
        erb :index
    end

    get '/notion' do
        code = params[:code]
        client_id = ENV['NOTION_CLIENT_ID']
        client_secret = ENV['NOTION_CLIENT_SECRET']
        uri = URI('https://api.notion.com/v1/oauth/token')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Post.new(uri.request_uri)

        request.body = {grant_type: 'authorization_code', code: code, redirect_uri: 'https://0.0.0.0:9292/notion'}.to_json
        request.add_field('Authorization', 'Basic '+Base64.strict_encode64(client_id + ':' + client_secret))
        request.content_type = 'application/json'
        response = http.request(request)
        
        data = JSON.parse response.body
        # data['access_token']

        if response.code == '200'
            client = Notion::Client.new(token: data['access_token'])
            result = client.search(filter: { property: 'object', value: 'database' })

            session[:notion_id] = data['access_token']
            session[:notion_db_id] = result.results[0].id
            session[:notion_ws_name] = data['workspace_name']
            session[:notion_ws_icon] = data['workspace_icon']
        end
        
        byebug

        erb :index
    end

    post '/send-to-notion' do
        client = Notion::Client.new(token: session[:notion_id])
        
        children = []
        content_aux = ''
        content_cnt = 0

        params.each do |key, val|
          if key[0..2] == 'con'
            content_aux = val
            content_cnt = content_cnt+1
          elsif key[0..2] == 'loc'
            children << write_notion_object('content', content_aux + "\n" + val + "\n")
          end
        end
        
        properties = {
            'Titulo': {
              'title': [{
                    'text': {
                        'content': params[:title]
                    }
                }]
            },
            'Autor': {
              'rich_text': [{
                    'text': {
                        'content': params[:author]
                    }
                }]
            },
            'Destacados': {
                'number': content_cnt
            }
        }
        
        client.create_page(
             parent: { database_id: session[:notion_db_id]},
             properties: properties,
             children: children
        )
        
        redirect 'https://www.notion.so/' + session[:notion_db_id].tr('-','')
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
            second_line = lines[1].strip.scan(/^-\s(?:Mi\s|Tu\s|La\s)?(\w+)(?: en la página ([0-9-]*?) \| )?(?:(?: en la posición|Posición|Location)? ([0-9-]*?) +\| )?Añadido el (.*)/i).first

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

        @bookTitles = @clippings.map{|t| t.book_title}.uniq.sort

        @notion_login = notion_login_validation()
        
        erb :result
    end
end