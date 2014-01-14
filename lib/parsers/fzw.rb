
module Parser
  require 'roo'
  require CONFIGS[:model]

  def parse(file_path)
    xls = Excelx.new(file_path)
    @specimens = Array.new
    xls.default_sheet = xls.sheets[0]

    17.upto(18) do |row|
      # Create a new Specimen
      s = Specimen.new
      print "Reading row: #{row}                 \r"

      s.date_received     = xls.cell( row, 'A' )
      s.date_drawn        = xls.cell( row, 'B' )
      s.protocol          = xls.cell( row, 'C' )
      s.subject_id        = xls.cell( row, 'D' ).to_i.to_s
      s.ian               = xls.cell( row, 'E' ).to_s

      # If value in institutional accesssion number looks like a vacutainer move to vacutainer field.
      if s.ian =~ /(EDTA|ACD|SST|CPT)/
        s.vacutainer = s.ian
        s.ian = ""
      end

      s.id                = xls.cell( row, 'F' ).to_i.to_s
      s.type              = xls.cell( row, 'G' )
      num_aliquots        = xls.cell( row, 'H' ).to_i
      s.specimen_code     = xls.cell( row, 'I' ).to_i.to_s

      s.timepoint       = xls.cell( row, 'K' )
      # s.sample_modifiers  = {:comment => xls.cell( row, 'M' ).to_s}

      # Unaccounted BSI Required Fields
      s.label_status    = 'O'
      s.billing_method  = 'Purchase Order'

      num_aliquots.times do |i|
        aliquot = s.dup
        aliquot.sample_id = '@nextbsiid("Laa000000")'
        aliquot.seq_num = '0000'
        @specimens << aliquot
      end
      nil
    end

    @specimens

  end

end
