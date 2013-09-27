module Mutations

  def fetch_lineage_data(related, item={})

    specimen_lineage =
      {:protocol =>
        {:case_number =>
          ["block", "slide"]
        }
      }

    puts "Building lineage for this set of specimens"
    ap related

    ruby_lineage = {
      :level => "",
      :attrs => {:label => "Pathcore"},
      :children => generate_lineage_data(specimen_lineage, related)
    }

    js_lineage = translate_lineage_to_js(ruby_lineage).chop

    js_data = "var data = {}; data.lineage = {\n" +
      js_lineage +
      "\n}; data.num_children = #{related.select{|e| e[:_specimen_type].downcase == "slide"}.length}"

    return js_data


  end

  def generate_lineage_data(lineage_map, items)
    if lineage_map.class == Hash
      k = lineage_map.keys.first

      # Collect all top level params
      range = items.map{|r| r[k]}.uniq
      final = range.map do |parent|
        {
          :level => k.to_s.gsub(/_/, " ").capitalize,
          :attrs => {
            :label => parent.to_s
          },
          :children => generate_lineage_data(lineage_map[k], items.select{|s| s[k] == parent})
        }
      end
    elsif items.length < 1 # Strange but possible end case, return empty array
      []
    else
      # Check if there are blocks, if there are one more iteration
      if items.map{|s| s[:_specimen_type]}.include?("block")
        items.select{|y| y[:_specimen_type] == "block"}.map do |block|
          slides = items.select{|spec| spec[:_specimen_type] == "slide"}.select{|x| x[:block_id].to_s == block[:id].to_s}
          {
            :level => "block",
            :attrs => block,
            :children => generate_lineage_data("slide", slides)
          }
        end
      else # All specimens are slides and more than 1 exists
        items.sort_by!{|e| e[:id]}.map do |slide|
          slide[:marker_name] = slide[:marker_name].center(4)
          slide[:_specimen_type] = slide[:_specimen_type].capitalize
          {
            :level => "slide",
            :attrs => slide,
            :children => []
          }
        end
      end
    end

  end

  def translate_lineage_to_js(lineage, indent="  ", feed="")

    attrs = Array.new
    lineage[:attrs].merge({:level => lineage[:level]}).each{|k,v| attrs << "'#{k.to_s}': '#{v.to_s}'"}
    feed << attrs.join(",\n")

    if lineage[:children].length > 0
      children = lineage[:children]
      feed << ",\n#{indent}'children': [" + children.map{|child| "\n#{indent}  {" + translate_lineage_to_js(child, indent << "  ") + ","}.join("").chop + "\n#{indent}]\n}"
    else
      feed << "}"
    end

  end

end
