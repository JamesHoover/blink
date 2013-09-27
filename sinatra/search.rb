require 'sax-machine'

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
                    string "#{v}", {:fields => [k.to_s] }
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
                    string "#{v}", {:fields => [k.to_s] }
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
        size PAGE_SEARCH_SIZE
        instance_eval('query(&simple_search_query)')
        facet 'protocols' do
          terms :protocol
        end
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
