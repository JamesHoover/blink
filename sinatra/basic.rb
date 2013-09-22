require 'httparty'

module Basic
  def process_search_request(request)
    search_results = Hash.new
    @results = Array.new

    # Store filter parameters passed.
    filters = request.POST.select{|k,v| !['All',''].include?(v) }

    query_string = request.query_string.chomp('.json').gsub(/%20/, ' ').gsub(/(.+)s$/){|s| $1}.gsub(/\*/, '?').strip

    unless query_string.empty?
      if query_string.split.length > 1
        @results  = nlp_search(query_string, filters, :search)
        @count    = nlp_search(query_string, filters, :count)
        LAST_QUERY[:type]  = :nlp
      else
        search_results  = simple_search(query_string, filters, :search)
        @results        = search_results[:results]
        @facets         = search_results[:facets]
        @count          = @facets['types']['total']
        LAST_QUERY[:type]  = :simple
      end
      LAST_QUERY[:count]  = @count
      LAST_QUERY[:string] = query_string
      LAST_QUERY[:filters]= filters
      if @results.nil?
        @results = []
        @count = 0
      end

      LAST_QUERY.store( :search_key, SecureRandom.urlsafe_base64(6) )
      session[:search_key] = LAST_QUERY.to_json

    end
    puts "process_request for #{request.query_string} search_results"
    ap search_results
    # Go straight to the browse page if your search result only returns one result
    if @results.length == 1
      result = @results.first
      redirect to("/browse/#{result[:type]}/#{result[:id]}")
    end

    unless request.query_string.end_with?('.json')
      haml :search, :locals => {:request => request, :query_string => query_string, :filter_fields => get_filter_fields(search_results), :filters => filters }
    else
      @results.to_json
    end

  end

  def find(options, query, extras={})
    options.merge!(extras)
    if query
      s = Tire.search options[:from] do
        query do
          boolean do
            must do
              term options[:by].to_sym, query.to_s.downcase
            end
            must do
              term :type, options[:what].to_s
            end
          end
        end
      end
      results = s.results.map{|e| e.to_hash}
    else
      []
    end
  end

  def retrieve(options={}, query)
    type = options[:what]
    # get object from ES using HTTParty.  The parsed response keys its hashes with strings, we want symbols so inject copypasta does that
    response = HTTParty.get( "http://localhost:9200/bsi/#{type}/#{query}" ).parsed_response['_source'].inject({}){|item,(k,v)| item[k.to_sym] = v; item}
  end

  def get_slide( id )
    if ON_HEROKU
      # Get the slide using PostGres
      @slide = DB[:slide].join(:marker, :id => :marker_id).filter(:label => id).first
      if @slide
        @slide.store(:_marker_type, @slide[:marker_type])
      end
      @slide
    else
      # Get the slide using ElasticSearch
      find_specimen_by_label( id ).first
    end

  end

  def get_filter_fields(search_results)
    puts "get filter search_results"
    filter_fields = Hash.new{|hash,k| hash.store(k,[])}
    if search_results[:results]
      unless search_results[:results].length > 99
        search_results[:results].each do |result|
          result.select{|k,v| !(ES_FIELDS+result.keys.grep(/^_/)-[:_specimen_type, :_type]).include?(k) }.each do |k,v|
            filter_fields.store(k, filter_fields[k].push(v.to_s).uniq)
          end
        end
      else
        facets = search_results[:facets]
        facets['types']['terms'].each do |term|
          fields = HTTParty.get("http://localhost:9200/bsi/#{term['term']}/_mapping?").parsed_response[term['term']]['properties'].keys
          ap fields
          out_fields = Hash.new{|hash,k| hash.store(k,[])}
          fields.select{|v| !['_pif_name', '_pif_val', '_short_list', '_marker_type'].include?(v)}.each do |v|
            out_fields.store(v, [])
          end
          filter_fields.merge!( out_fields )
          filter_fields.merge!( {'type' => facets['types']['terms'].map{|v| v['term'] } } )
        end
      end
      filter_fields.select{|k,v| v.length != 1}
    end
  end

  def format_slide(slide)
    builder = Nokogiri::XML::Builder.new do |xml|

      slide_metadata = {
        'marker' => slide[:marker_name],
        'protocol' => slide[:protocol],
        'case_number' => slide[:case_number],
        'specimen_id' => slide[:label],
        'block_id' => slide[:block_id]
        # 'control_id' => slide[:control_id]
      }
      xml.SlideDataResponse {
        xml.AdditionalSlideInfo {
        slide_metadata.each do |k,v|
        xml.SlideInfo {
          xml.Name {
          xml.cdata k
        }
        xml.Value {
          xml.cdata v
        }
        }
        end
      }
      }
    end
    [200, {}, builder.to_xml]

  end

  def generate_mail_merge(path, box_number, controls)
    good_path = "./tmp/files/box_#{box_number}.csv"
    bad_path  = "./tmp/files/errors_#{box_number}.csv"
    zip_path  = "./tmp/files/box_#{box_number}.zip"


    blocks = Array.new
    missing_slides = Array.new
    # Get case info
    File.open(path).each do |line|
      slide_label = line.match(/^\d{8}/)
      spec = find_specimen_by_label( slide_label ).first
      unless spec.nil?
        unless controls == {}
          es_update('bsi', 'specimen', spec[:id], {'control_id' => controls[spec[:marker_name]]})
        end
        spec.keep_if {|k,v| [:protocol, :case_number, :block_id].include?(k)}
        blocks << spec
      else
        missing_slides << slide_label
      end
    end

    # Write CSV file for blocks that exist in the db
    CSV.open(good_path, 'w') do |csv|
      csv << ['Protocol', 'Case', 'Block']
      blocks.uniq{|b| b[:block_id]}.each do |b|
        csv << [b[:protocol], b[:case_number], b[:block_id]]
      end
    end

    # Write CSV file for slides that we couldn't find in the db
    CSV.open(bad_path, 'w') do |csv|
      csv << ['Label']
      missing_slides.each do |s|
        csv << [s]
      end
    end
    `zip #{zip_path} #{good_path} #{bad_path}`
    # package all of this into a zip file
    zip_path
  end

  def build_error(code, message='', headers={})

    builder = Nokogiri::XML::Builder.new do |xml|

      xml.Error {
        xml.Message_ message
        xml.HTTPCode_ code
      }

    end
    if code == 204
      [code, headers, ""]
    else
      [code, headers, builder.to_xml]
    end

  end

  def admin?(request)
    # For now allow no slides to be deleted
    return false
  end

  # Method for upserting an elastic search items' attributes
  def es_update(index, type, id, new_attributes={})

    new_attributes.each do |k,v|
      payload = { "script" => "ctx._source.#{k.to_s} = '#{v}'"}
      HTTParty.post( "http://localhost:9200/#{index}/#{type}/#{id}/_update", :body=>payload.to_json )
    end
  end

  def base_url
    @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
  end
end
