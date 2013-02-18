require 'sinatra/base'
require 'sax-machine'
require 'httparty'
require 'set'

module Sinatra

  module Search

    class QueryRecord
      def initalize(query, type, count, csv_generated=false)
        @query, @type, @count, @csv_generated = query, type, count, csv_generated
      end

      attr_accessor :query, :type, :count

      def csv?
        @csv_generated
      end
    end

    class CollibioSlide
      include SAXMachine
      element :ImageLink, :as => :id
      element :Thumbnail, :as => :thumb
    end

    def simple_search(query_string, filters, search_type, page=0)
      simple_search_query = Proc.new do
        boosting(:negative_boost => 0.2) do

          positive do
            dis_max({:boost => 1.2, :tie_breaker => 0.5}) do
              query do
                boolean do
                  must do
                    string "*#{query_string}*", {:fields => [:_pif_val]}
                  end
                  filters.each do |k,v|
                    must do
                      string "*#{v}*", {:fields => [k.to_s] }
                    end
                  end
                end
              end
              query do
                boolean do
                  must do
                    string "*#{query_string}*"
                  end
                  filters.each do |k,v|
                    must do
                      string "*#{v}*", {:fields => [k.to_s] }
                    end
                  end
                end
              end
            end
          end

          negative do
            string "*#{query_string}*", {:fields => [:source]}
          end

        end
      end

      simple_search_proc = Proc.new do
        if search_type == :search
          from page*PAGE_SEARCH_SIZE
          size (page*PAGE_SEARCH_SIZE)+PAGE_SEARCH_SIZE-1
          instance_eval('query(&simple_search_query)')
          facet 'types' do
            terms :type
          end
        else
          instance_eval(&simple_search_query)
        end
      end

      s = instance_eval("Tire.#{search_type.to_s}('bsi', &simple_search_proc)")

        case search_type
        when :search
          # return results in hash form
          return { :results => s.results.map{|e| e.to_hash}, :facets=> s.results.facets }
        when :count
          return s
        end
    end

    def nlp_search(query_string, filters, search_type, page=0)
      query_string.downcase!
      case query_string
      when /^(specimen|subject|block|slide)s where( the)? (label|marker name|case number|protocol|block id) (is|has|starts with|ends with) ([a-zA-Z0-9?]+)( in it)?$/
        # Build block for the query, this is necessary to allow the same search criteria for both counts and searches based on a parameter
        type, field, plenarity, query = $1, $3, $4, $5
        nlp_query = Proc.new do
          boolean do
            must do
              case type
              when /(specimen|subject)/
                term :type, type
              when /(block|slide)/
                term :_specimen_type, type
              end
            end
            must do
              case plenarity
              when 'has'
                string "*#{query}*", {:fields => [field.gsub(/ /, '_').to_sym]}
              when 'starts with'
                string "#{query}*", {:fields => [field.gsub(/ /, '_').to_sym]}
              when 'ends with'
                string "*#{query}", {:fields => [field.gsub(/ /, '_').to_sym]}
              when 'is'
                string "#{query}", {:fields => [field.gsub(/ /, '_').to_sym]}
              end
            end
          end
        end

        search_block = Proc.new do
          if search_type == :search
            from page*PAGE_SEARCH_SIZE
            size (page*PAGE_SEARCH_SIZE)+PAGE_SEARCH_SIZE-1
            instance_eval("query(&nlp_query)")
          else
            instance_eval(&nlp_query)
          end
        end

        # Execute search with predefined block
        s = eval("Tire.#{search_type}('bsi', &search_block)")

        case search_type
        when :search
          # return results in hash form
          return s.results.map{|e| e.to_hash}
        when :count
          return s
        end

      end
    end


  end

  module Basic
    def process_search_request(request)
      search_results = Hash.new
      @results = Array.new

      # Store filter parameters passed.
      filters = request.POST.select{|k,v| !['All',''].include?(v) }

      query_string =  request.query_string.chomp('.json').gsub(/%20/, ' ').gsub(/(.+)s$/){|s| $1}.gsub(/\*/, '?').strip

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
      puts "process_request search_results"
      ap search_results
      # Go straight to the browse page if your search result only returns one result
      if @results.length == 1
        result = @results.first
        redirect to("/browse/#{result[:type]}/#{result[:id]}")
      end
      respond_to do |wants|
        wants.html { haml :search, :locals => {:request => request, :query_string => query_string, :filter_fields => get_filter_fields(search_results), :filters => filters } }
        wants.json { @results.to_json }
      end

    end

    def find(options={}, query)
      if query
        s = Tire.search 'bsi' do
          query do
            boolean do
              must do
                term options[:by].to_sym, query.to_s
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
        unless search_results[:results].length == 99
          search_results[:results].each do |result|
            result.select{|k,v| !(ES_FIELDS+result.keys.grep(/^_/)-[:_specimen_type, :_type]).include?(k) }.each do |k,v|
              filter_fields.store(k, filter_fields[k].push(v.to_s).uniq)
            end
          end
        else
          facets = search_results[:facets]
          facets['types']['terms'].each do |term|
            fields = HTTParty.get("http://localhost:9200/bsi/#{term['term']}/_mapping?").parsed_response[term['term']]['properties'].keys
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
  end

  helpers Search, Basic
end
