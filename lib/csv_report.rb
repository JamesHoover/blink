require 'resque'
require './sinatra/search.rb'

class CSVReport
  include Resque::Plugins::Status
  include Search

  def perform

    output_fields   = options['output_fields']
    last_user_query = options['query']
    query_type   = last_user_query["type"]
    query_string = last_user_query["string"]
    filters      = last_user_query['filters']

    # csv_output_fields = output_fields.merge()

    iterations = last_user_query['count'].to_i/PAGE_SEARCH_SIZE
    page = 0
    more_to_write = true
    CSV.open("tmp/downloads/#{last_user_query['search_key']}.csv", 'ab') do |csv|
      headers = output_fields.map{|field| field.to_s.gsub(/_/, ' ').strip.capitalize}
      csv << headers
      while more_to_write
        at(page, iterations, "Writing page #{page} of #{iterations}")
        @current_page = send("#{query_type}_search".to_sym, query_string, filters, :search, page)[:results]
        if @current_page.length < PAGE_SEARCH_SIZE - 1
          more_to_write = false
        end
        # write the page
        @current_page.each do |result|
          # make array of values we want to output
          row = Array.new
          output_fields.each do |field|
            row << result[field].to_s
          end
          csv << row
        end
        page = page + 1
      end
    end
    completed

    # send_file "./tmp/downloads/#{last_user_query['search_key']}.csv", :filename => "blink_report.csv", :type => 'Application/octet-stream'
  end
end
