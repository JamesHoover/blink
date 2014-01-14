require 'resque'
class MailMerge
  include Resque::Plugins::Status
  include Basic

  def perform
    complete
  end

end
