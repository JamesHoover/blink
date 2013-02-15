require 'sinatra/sequel'

pg_url = ENV['HEROKU_POSTGRESQL_YELLOW_URL']



DB = Sequel.connect(pg_url)

`ruby db/migrations/setup_db.rb`

DB.transaction do
end

slide  = DB[:slide]
marker = DB[:marker]

DB.transaction do

  seed_id = 10000
  50000.upto(50005) do |caseid|
    10.times do
      slide.insert(:label => seed_id, :case_number => caseid, :marker_id => 1, :protocol => 'NUX003')
      slide.insert(:label => seed_id+1, :case_number => caseid, :marker_id => 2, :protocol => 'NUX003')
      seed_id = seed_id+2
    end
  end

  marker.insert(:marker_name => 'H&E', :marker_type => 'stain')
  marker.insert(:marker_name => 'KI67',  :marker_type => 'biomarker')
  marker.insert(:marker_name => 'HER-2',  :marker_type => 'biomarker')
  marker.insert(:marker_name => 'ER',  :marker_type => 'biomarker')
  marker.insert(:marker_name => 'PR',  :marker_type => 'biomarker')


end
