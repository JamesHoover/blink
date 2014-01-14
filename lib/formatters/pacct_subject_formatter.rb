module Formatter
  def format(subject)
    # Data expected to be in bsi formatted hash format
    subject.each do |k,v|
      type = k.match(/\.(.+_.+|.+)$/)[1]
      begin
        subject[k] = send("format_#{type}".to_sym, v)
      rescue NoMethodError => e
        # No formatter defined use passed value as formatted
        subject[k] = v
      end
    end
    subject
  end

  def format_study_id(id)
    case id
    when 'PACCT'
      id='PACT1'
    end
    id
  end
end
