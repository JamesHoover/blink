
module Parser
  require 'roo'
  require CONFIGS[:model]

  def parse(file_path)
    xls = Excelx.new(file_path)
    @specimens = Array.new
    xls.default_sheet = xls.sheets[0]

    3.upto(xls.last_row) do |row|
      s = Specimen.new
      print "Reading row: #{row}                 \r"

      s.id              = xls.cell( row, 'N' ).to_i.to_s
      s.date_drawn      = xls.cell( row, 'G' )
      s.date_received   = xls.cell( row, 'H' )
      s.subject_id      = xls.cell( row, 'F' ).to_i.to_s
      s.protocol        = 'PGRX'
      s.billing_method  = 'Chartstring'
      s.type            = 'CELLS'
      s.label_status    = 'B'

      @specimens << s

    end

    @specimens.uniq!{|s| s.id}

  end

end
