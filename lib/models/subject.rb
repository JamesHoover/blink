class Subject
  require CONFIGS[:formatter]
  include Formatter
  REQUIRED_ATTRIBUTES = %w(protocol id).map{|v| v.to_sym}
  BFH_MAP = { :id         => 'subject.subject_id',
              :dob        => 'subject.date_of_birth',
              :protocol   => 'subject.study_id',
              :name       => 'subject.subject_name',
              :first_name => 'subject.first_name',
              :last_name  => 'subject.last_name',
              :ssn        => 'subject.social_security_num'
  }

  attr_accessor :name, :mrn, :ssn, :dob, :protocol, :gender, :consent_date, :surgery_number, :id, :first_name, :last_name

  def to_bfh
    bfh = Hash.new
    # Add 1-1 matches/translations
    self.instance_variables.each do |attr|
      a = attr[1..-1].to_sym
      if BFH_MAP.has_key?(a)
        bfh[BFH_MAP[a]] = instance_eval(attr.to_s)
      else
        bfh["subject.#{a}"] = instance_eval(attr.to_s)
      end
    end
    # Add duplications/aliases (e.g. id, and sequence numbers)
    bfh['subject.sequence_num'] = @id unless @id.nil?
    format(bfh)
  end

  def valid?
    REQUIRED_ATTRIBUTES.find{|v| send(v).nil?}.nil?
  end
end
