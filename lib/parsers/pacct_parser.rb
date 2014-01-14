require 'awesome_print'
require 'csv'
require CONFIGS[:model]

module Parser

  def parse(file_path)
    @subjects = Array.new

    CSV.foreach(file_path, :headers => true) do |row|

      s = Subject.new
      row = row.to_hash
      s.id            = row["Case number"]
      s.protocol      = row["Protocol"]

      @subjects << s

    end

    @subjects.uniq{|s| s.id}
  end

end
