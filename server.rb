require 'sinatra'
require 'sinatra/sequel'
require 'sinatra/respond_to'
require 'sinatra/static_assets'
require './sinatra/helpers'
require 'securerandom'
require 'fileutils'
require 'httparty'
require 'awesome_print'
require 'nokogiri'
require 'json'
require 'haml'
require 'tire'
require 'log4r'
require 'csv'

############################
#### Boilerplate setup  ####
############################

LAST_QUERY = Hash.new
ES_FIELDS = [:id, :sort, :highlight, :type]
PAGE_SEARCH_SIZE = 100
CSV_OUTPUT_FIELDS = [:label, :type, :_specimen_type, :protocol, :case_number]
COLLIBIO_SLIDE_PARTIAL = "https://collibio.cancer.northwestern.edu/collibio/CollibioViewer.html?sharelinkid="

# Check if we are on heroku
if !ENV['HEROKU_POSTGRESQL_YELLOW_URL'].nil?
  pg_url = ENV['HEROKU_POSTGRESQL_YELLOW_URL']
  ON_HEROKU = true
else
  pg_url = ENV['PG_URL']
  ON_HEROKU = false
end

enable :sessions
Sinatra::Application.register Sinatra::RespondTo

if ON_HEROKU
  DB = Sequel.connect(pg_url)
end

############################
### Webservice endpoints ###
############################

# Page root
get '/' do
  respond_to do |wants|
    wants.html { haml :index }
  end
end

post '/search' do

  process_search_request(request)

end

get '/search' do
  process_search_request(request)
end

get '/download' do

  last_user_query = JSON.parse session[:search_key]
  query_type   = last_user_query["type"]
  query_string = last_user_query["string"]
  filters      = last_user_query['filters']

  page = 0
  more_to_write = true
  CSV.open("tmp/downloads/#{last_user_query['search_key']}.csv", 'ab') do |csv|
    headers = CSV_OUTPUT_FIELDS.map{|field| field.to_s.gsub(/_/, ' ').strip.capitalize}
    csv << headers
    while more_to_write
      @current_page = send("#{query_type}_search".to_sym, query_string, filters, :search, page)
      if @current_page.length < PAGE_SEARCH_SIZE - 1
        more_to_write = false
      end
      # write the page
      @current_page.each do |result|
        # make array of values we want to output
        row = Array.new
        CSV_OUTPUT_FIELDS.each do |field|
          row << result[field].to_s
        end
        csv << row
      end
      page = page + 1
    end
  end
  send_file "./tmp/downloads/#{last_user_query['search_key']}.csv", :filename => "blink_report.csv", :type => 'Application/octet-stream'

end

get '/browse/?:type?/?:id?/?' do
  type = params[:type]
  id   = params[:id]
  if params[:id]
    @item = send("retrieve_#{type}_by_id".to_sym, id)
    ap @item
    @related = find_specimen_by_case_number( @item[:case_number] )
    haml "#{params[:type]}_profile".to_sym
  elsif params[:type]
    @children = HTTParty.get( "http://localhost:9200/bsi/#{params[:type]}/_search?type:#{params[:type]}").parsed_response["hits"]["hits"].map do |hit|
      child = Hash.new
      child[:path] = "/browse/#{params[:type]}/#{hit['_id']}"
      child[:label] = "#{hit['_source']['_pif_val']}"
      child
    end
    haml :browse
  else
    @children = HTTParty.get( 'http://localhost:9200/bsi/_mapping' ).parsed_response['bsi'].keys.map do |type|
      child = Hash.new
      child[:path] = "/browse/#{type}"
      child[:label] = "#{type.capitalize}s"
      child
    end
    haml :browse
  end

end

post '/controls' do
  controls = Hash.new
  tempfile    = params['fileupload'][:tempfile]
  filename    = params['fileupload'][:filename]
  box_number  = params['box_number']
  FileUtils.cp(tempfile.path, "./tmp/files/#{filename}")

  # Check if all three controls passed
  # TODO: make this and the form generate fields and checks dynamically based on protocol selection
  unless params['ER_control_id'].nil? || params['PR_control_id'].nil? || params['HER2_control_id'].nil?
    # Associate controls
    controls['ER'] = params['ER_control_id']
    controls['PR'] = params['PR_control_id']
    controls['HER2'] = params['HER2_control_id']
  end

  # write mailmerge file
  xls_path = generate_mail_merge("./tmp/files/#{filename}", box_number, controls)
  # send mailmerge file
  send_file xls_path, :filename => "box_#{box_number}_labels.csv", :type => 'Application/octet-stream'

end

get '/controls' do

  haml :mail_merge

end

# Get slide from db
get '/slide/:id' do
  # DON'T CHANGE THIS. COLLIBIO DEPENDS ON IT.
  # return slide info
  @slide = get_slide( params[:id] )

  unless @slide.nil?
    # Slide exists update ES
    if request.body.read != ""
      request.body.rewind
      # Parse Data collibio sends us
      @collibio_data = CollibioSlide.new
      @collibio_data.parse request.body.read
      # Update slide record
      es_update('bsi', 'specimen',  @slide[:id], {:collibio_url => COLLIBIO_SLIDE_PARTIAL+@collibio_data.id.to_s, :_thumbnail => @collibio_data.thumb})
    end

    # Finally, give them what they want
    respond_to do |wants|
      wants.xml  { return format_slide(@slide) }
      wants.html { return format_slide(@slide) }
      wants.json { @slide.to_json }
    end
  else
    return build_error(204)
  end

end

post '/slide/new' do
  # add new slide
end

delete '/slide/:id' do
  if admin?(request)
    @slide = DB[:slide].filter(:label => params[:id]).first
    @slide.delete
  else
    build_error(404, 'You do not have permission to do this')
  end
end

def method_missing(method_id, *arguments, &block)
  if method_id.to_s =~ /^(find|retrieve)_(subject|specimen|protocol)_by_(id|label|case_number)$/
    finder, type, matcher = method_id.to_s.scan(/^(find|retrieve)_(subject|specimen|protocol)_by_(id|label|case_number)$/).flatten
    send(finder, {:what => type, :by => matcher}, *arguments)
  else
    super
  end
end
