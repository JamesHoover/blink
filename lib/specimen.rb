module Specimen

  attr_accessor :protocol, :id, :source

  def initialize( args )
    @id, @protocol, @source, = args[:id], args[:protocol], args[:source]
  end

  def to_hash
    {:protocol => @protocol, :label => @id, :source => @source}
  end
end

class Block
  include Specimen
  attr_accessor :case_id, :block_id, :ian, :anatomic_site

  def initialize( args )
    super(args)
    @case_id, @block_id, @ian, @anatomic_site= args[:case_id], args[:block_id], args[:ian], args[:anatomic_site]
  end

  def id
    if @block_id.nil?
      super
    else
      @block_id
    end
  end

  def to_hash
    super.merge( { :case_number => @case_id, :block_id => @block_id, :label => @block_id, :ian => @ian, :anatomic_site => @anatomic_site } )
  end
end

class Slide < Block
  attr_accessor :marker, :id

  def initialize( args )
    super(args)
    @marker, @id= args[:marker], args[:id]
  end

  def to_hash
    super.merge( { :marker_name => @marker, :label => @id } )
  end
end

class MarkerControl
  include Specimen

end
