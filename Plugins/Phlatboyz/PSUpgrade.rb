# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

#			1.0 (2009-9-1) -  Support for upgrading PhlatscripT 0.918 models to 0.919


module PhlatScript

  class PSUpgrader

    attr_accessor :upgrade

    def PSUpgrader.upgrade
      ps = PSUpgrader.new
      ps.upgrade_918
      UI.messagebox("Upgrade Complete") if ps.upgrade
      return (ps.upgrade ? true : false)
    end

    def initialize
      @upgrade = nil
    end

    def upgrade?(version, raise_on_false=true)
      if (@upgrade.nil?)
        @upgrade = (6 == UI.messagebox("This model appears to be marked up in version #{version} of the PhlatscripT. Upgrading will remove all grouping. Would you like to upgrade it now?", MB_YESNO))
      end
      raise "Upgrade declined" if (!@upgrade && raise_on_false)
      return @upgrade
    end

    def process_edge_918(e)
      ct = e.get_attribute("phlatboyzdictionary", "edge_type", "")
      if ["inside_cut", "outside_cut", "fold_cut", "centerline_cut"].include?(ct)
        cf = e.get_attribute("phlatboyzdictionary", "cut_depth_factor", nil)
        if (cf) && (cf < 2) && (self.upgrade?("0.918"))
          new_cf = (cf*100)
          e.set_attribute("phlatboyzdictionary", "cut_depth_factor", new_cf)
        end
      elsif (ct == "vtab_cut") && (self.upgrade?("0.918"))
        e.set_attribute("phlatboyzdictionary", "vtab", true)
        e.set_attribute("phlatboyzdictionary", "edge_type", "tab_cut")
      end
    end

    def process_group_918(g)
      g.explode.each { |e|
        if e.kind_of?(Sketchup::Group)
          process_group_918(e)
        elsif e.kind_of?(Sketchup::Edge)
          process_edge_918(e)
        end
      }
    end

   def upgrade_918
      groups = []
      aborted = false
      Sketchup.active_model.start_operation "Upgrading 918", true
      items = Sketchup.active_model.active_path
      items.length.downto(0) { Sketchup.active_model.close_active } if items
      begin
         Sketchup.active_model.entities.each { |e|
            if e.kind_of?(Sketchup::Group)
               groups.push(e)
            elsif e.kind_of?(Sketchup::Edge)
               process_edge_918(e)
            end
            }
         groups.each { |g| process_group_918(g) }
      rescue
         Sketchup.active_model.abort_operation
         aborted = true
      end
      if (@upgrade && !aborted)
         Sketchup.active_model.commit_operation 
      else
         Sketchup.active_model.abort_operation
      end
   end

  end
end
