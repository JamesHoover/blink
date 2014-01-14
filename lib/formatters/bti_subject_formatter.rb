module Formatter
  require 'chronic'

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

  def format_social_security_num(ssn)
    if ssn.match(/(\d{3})-(\d{2})-(\d{4})/)
      ssn = "#{$1}#{$2}#{$3}"
    end
    ssn
  end

  def date(date)
    Chronic.parse(date).strftime('%m/%d/%Y 00:00')
  end

  def format_consent_date(date)
    if date.match(/(\d{4})-(\d{2})-(\d{2})/)
      year, mo, day = $1, $2, $3
      date = "#{mo}/#{day}/#{year} 00:00"
    end
    date
  end

  alias format_date_of_birth date
  alias format_consent_date date

end
