module Formatter
  require 'chronic'
  def format(specimen)
    # Data expected to be in bsi formatted hash format
    specimen.each do |k,v|
      type = k.match(/\.(.+_.+|.+)$/)[1]
      begin
        specimen[k] = send("format_#{type}".to_sym, v)
      rescue NoMethodError => e
        # No formatter defined use passed value as formatted
        specimen[k] = v
      end
    end
    specimen
  end

  def date(date)
    Chronic.parse(date).strftime('%m/%d/%Y 00:00')
  end

  def format_mat_type(type)
    case type.to_s
    when /^H\s*&*\s*E$/
      return 'H&E'
    when /^PLASMA$/i
      return 'PLS'
    when /^serum$/i
      return 'Blood Serum'
    when /^CELLS$/i
      return 'BUFRED'
    when /^Buffy Cells$/i
      return 'BUFRED'
    when /^DNA$/i
      return 'WB'
    when /stained slide/i
      return 'SLDTS'
    when /block/i
      return 'BLK'
    when /tissue/i
      return 'FRZ'
    when /mnc/i
      return 'PBMC'
    else
      return type
    end
  end

  # Format Stain type
  def format_field_268(stain)
    case stain.to_s
    when 'N/A'
      return ''
    else
      return stain
    end
  end

  def format_time_point(timepoint)
    case timepoint.to_s
    when /Baseline/i
      return 'BSL'
    when /Cycle ([0-9]+) Day ([0-9]+)/i
      return "C = #{$1}; D = #{$2}"
    else
      return type
    end
  end

  def format_vacutainer(vacutainer)
    case vacutainer.to_s
    when /N\/A/i
      return ''
    else
      return vacutainer
    end
  end

  def format_sample_modifiers(modifiers)
    bfs = ''
    modifiers.each do |k,v|
      unless v.empty?
        bfs << "#{k.to_s.capitalize} = #{v.to_s}, "
      end
    end
    bfs.chop.chop
  end

  alias format_date_drawn date
  alias format_date_received date

end
