class Specimen
  require CONFIGS[:formatter]
  include Formatter

  attr_accessor :seminal_parent
  REQUIRED_ATTRIBUTES = %w(type billing_method date_received date_drawn label_status thaws protocol subject_id).map{|v| v.to_sym}
  BFH_MAP = {
    :protocol         => 'vial.study_id',
    :type             => 'vial.mat_type',
    :measurement      => 'vial.volume',
    :measurement_unit => 'vial.volume_unit',
    :stain_type       => 'vial.field_268',
    :room             => 'location.room',
    :building         => 'location.building',
    :freezer          => 'location.freezer',
    :shelf            => 'location.shelf',
    :rack             => 'location.rack',
    :box              => 'location.box',
    :row              => 'vial_location.row',
    :col              => 'vial_location.col',
    :sample_id        => 'sample.sample_id',
    :appointment_time => 'sample.appointment_time',
    :center           => 'sample.center',
    :data_manager     => 'sample.data_manager',
    :date_drawn       => 'sample.date_drawn',
    :cra              => 'sample.cra',
    :kit_id           => 'sample.kit_id',
    :pickup_location  => 'sample.pickup_location',
    :subject_id       => 'sample.subject_id',
    :surgeon          => 'sample.surgeon',
    :ian              => 'sample.surgical_accession_number',
    :ian_part         => 'sample.field_267',
    :telephone        => 'sample.telephone',
    :timepoint        => 'sample.time_point',
    :sample_modifiers => 'sample.sample_modifiers'
  }

  vial_props = YAML::load(File.open('./config/vial_props.yaml')).map{|v| v.to_sym}
  (vial_props-BFH_MAP.keys+[:specimen_code]).each{|attr_string| attr_accessor attr_string.to_sym}
  BFH_MAP.keys.each{ |attr| attr_accessor attr }

  # Define Defaults
  def initialize(bfh={})

    unless bfh.empty?
      self.seminal_parent = true
      bfh.keys.each do |bfh_key|
        if BFH_MAP.has_value?(bfh_key)
          instance_eval("self.#{BFH_MAP.key(bfh_key)} = #{bfh[bfh_key]}")
        else
          instance_eval("self.#{bfh_key.gsub(/vial\./, '')} = #{bfh[bfh_key]}")
        end
      end

    else
      self.thaws = '0'
    end

  end

  def bsi_id()
    "#{self.sample_id} #{self.seq_num}"
  end

  def seminal_parent?
    return seminal_parent
  end

  def to_bfh
    bfh = Hash.new
    # Add 1-1 matches/translations
    self.instance_variables.each do |attr|
      a = attr[1..-1].to_sym
      if BFH_MAP.has_key?(a)
        bfh[BFH_MAP[a]] = instance_eval(attr.to_s)
      else
        bfh["vial.#{a}"] = instance_eval(attr.to_s)
      end
    end
    format(bfh)
  end

  def to_hash
    out = Hash.new
    self.instance_variables.each do |attr|
      a = attr[1..-1].to_sym
      out[a] = instance_eval(attr.to_s)
    end
    out
  end

  def valid?
    incomplete_attrs = REQUIRED_ATTRIBUTES.find{|v| send(v).nil?}.nil?
  end

  def seminal_parent?
  end

  def missing_attrs
    REQUIRED_ATTRIBUTES.find_all{|a| send(a).nil?}
  end

end
