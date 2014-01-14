
module Parser
  require 'roo'
  require CONFIGS[:model]

  def parse(file_path)
    xls = Excelx.new(file_path)
    @specimens = Array.new
    xls.default_sheet = xls.sheets[0]

    2.upto(7) do |row|
      s = Subject.new
      print "Reading row: #{row}                 \r"

      s.id              = xls.cell( row, 'A' ).to_i.to_s
      s.mrn             = xls.cell( row, 'B' ).to_i.to_s
      s.last_name       = xls.cell( row, 'C' ).to_s
      s.first_name      = xls.cell( row, 'D' ).to_s
      s.dob             = xls.cell( row, 'G' )
      s.gender          = xls.cell( row, 'K' ).to_s

      s.protocol        = 'NU00X3'

      @specimens << s

    end

    @specimens.uniq{|s| s.id}
  end

end
