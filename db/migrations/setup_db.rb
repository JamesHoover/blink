require 'sequel'

pg_url = ENV['HEROKU_POSTGRESQL_YELLOW_URL']

DB = Sequel.connect(pg_url)

DB.tables.each do |table|
   DB.drop_table table if DB.table_exists?(table)
end

DB.create_table :slide do
  primary_key :id
  String :label, :unique => true, :null => false
  Integer :case_number, :null => false
  Integer :marker_id, :null => false
  Integer :block_id
  String :protocol, :null => false
  String :source_file
end

DB.create_table :marker do
  primary_key :id
  String :marker_name, :null => false
  String :marker_type, :null => false
end

marker = DB[:marker]

DB.transaction do
  marker.insert(:marker_name => 'H&E', :marker_type => 'stain')
  marker.insert(:marker_name => 'KI67',  :marker_type => 'biomarker')
  marker.insert(:marker_name => 'HER-2',  :marker_type => 'biomarker')
  marker.insert(:marker_name => 'ER',  :marker_type => 'biomarker')
  marker.insert(:marker_name => 'PR',  :marker_type => 'biomarker')
end
