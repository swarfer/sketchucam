# Copyright 2004, Rick Wilson 

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

# Name :          attributes.rb 1.0
# Description :   Set and Get Attributes
# Author :        Rick Wilson
# Usage :         1. Install into the plugins directory or into the 
#           Plugins/examples directory and manually load from the
#           ruby console "load 'examples/attributes.rb'" 
#                 2. Select "Attributes" from the context menu
# Date :          25.Aug.2004
# Type :          Tool
# History:
#        1.0 (25.Aug.2004) - first version
#        DAF small fix for SketchupMake2014 which doesn't like global variables in loops
#        more fixes for errors when you cancel or do not enter values
#  $Id$
require 'sketchup.rb'

def att_set                               #DEFINE A NEW FUNCTION TO SET ATTRIBUTES
   model=Sketchup.active_model            #RETRIEVE THE ACTIVE MODEL
   view=model.active_view                 #SET THE ACTIVE VIEW
   ents=model.active_entities             #GET ALL THE ENTITIES FROM THE MODEL
   ss=[]                                  #INITIALIZE A NEW ARRAY TO HOLD SELECTED ENTITIES
   model.selection.each {|e| ss.push(e)}  #ADD EACH SELECTED ENTITY TO THE ARRAY
   ss.freeze                              #FREEZE THIS ARRAY TO AVOID CHANGES
   for e in ss                            #FOR EACH ITEM IN THE ARRAY, DO THE FOLLOWING...
      prompts=["Dictionary                                             ","Key","Value"]            #SET THE PROMPTS FOR THE DIALOG BOX
      values=["","",""]                   #SET THE VALUES (BLANK) FOR THE DIALOG BOX
      results = inputbox prompts, values  #DIALOG BOX PROMPTING FOR ATTRIBUTE INFO
      if results != false
         dict_name=results[0]             #THESE 3 LINES SET THE RESULTS
         dict_key=results[1]
         dict_value=results[2]
         if dict_name != ""
            e.attribute_dictionary(dict_name, true)         #CREATE THE ATTRIBUTE DICTIONARY (AD) FOR THIS OBJECT
            if (dict_value != "") && (dict_key != "")
               e.set_attribute(dict_name,dict_key,dict_value)  #ADD THE ATTRIBUTES TO THE AD FOR THIS OBJECT
            end
         end
      end
   end                           #END THE 'FOR' LOOP
end                           #END THE FUNCTION DEFINITION

def att_get                                  #DEFINE NEW FUNCTION TO RETRIEVE ATTRIBUTES
   model=Sketchup.active_model               #RETRIEVE THE ACTIVE MODEL
#  view=model.active_view                    #SET THE ACTIVE VIEW
#  ents=model.active_entities                #GET ALL THE ENTITIES FROM THE MODEL
   $ss=[]                                    #INITIALIZE A NEW ARRAY TO HOLD SELECTED ENTITIES
   model.selection.each {|e| $ss.push(e)}    #ADD EACH SELECTED ENTITY TO THE ARRAY
   $ss.freeze                                #FREEZE THIS ARRAY TO AVOID CHANGES
   model.selection.clear                     #CLEAR THE SELECTION SET
   for $e in $ss                             #FOR EACH ITEM IN THE ARRAY, DO THE FOLLOWING...
      $dict_names=[]                         #INITIALIZE AN ARRAY TO HOLD DICTIONARY NAMES
      model.selection.add($e)                #HIGHLIGHT THIS ENTITY FROM THE ARRAY SO USER KNOWS WHAT IS SELECTED
      $dicts=$e.attribute_dictionaries       #GET THE ATTRIBUTE DICTIONARIES FOR THIS ENTITY
      if $dicts != nil                       #IF THERE WERE AD'S FOR THIS ENTITY, DO THE FOLLOWING...
         $dicts.each {|f| $dict_names.push(f.name)}      #ADD EACH ATTRIBUTE DICTIONARY TO THE ARRAY $dict_names
         for $ad in $dict_names                          #FOR EACH ITEM IN $dict_names, DO THE FOLLOWING...
            $prompts=$e.attribute_dictionary($ad).keys   #SET THE PROMPTS FOR THE DIALOG BOX
            $values=$e.attribute_dictionary($ad).values  #SET THE VALUES FOR THE DIALOG BOX
            $results = inputbox $prompts, $values, $ad   #DO THE DIALOG BOX (ONLY FOR DISPLAY OF VALUES)
            if $results != $values && $results != false  # [ADD SECTION TO UPDATE CHANGED VALUES]
               0.upto($prompts.length-1) do |xx|
                  if $results[xx] != ""
                     $e.set_attribute($ad,$prompts[xx],$results[xx])
                  end
               end
            end
         end                                 #END THE 'FOR' LOOP
      model.selection.clear                  #CLEAR THE SELECTION SET AND GET READY FOR THE NEXT ONE
      end                                    #END THE 'IF' STATEMENT
   end                                       #END THE 'FOR' LOOP
end                                          #END THE FUNCTION DEFINITION

# def att_apply                                #BEGIN FUNCTION 'ATT_APPLY'
   # model=Sketchup.active_model               #RETRIEVE THE ACTIVE MODEL
   # view=model.active_view                    #SET THE ACTIVE VIEW
   # ents=model.active_entities                #GET ALL THE ENTITIES FROM THE MODEL
   # sel=model.selection                       #GET THE SELECTED ENTITIES
   # for ent in sel                            #FOR EACH SELECTED ITEM, DO THE FOLLOWING...
      # if (($dicts != nil) && ($prompts != nil) && ($values != nil))  #MAKE SURE EVERYTHING IS SET BEFORE CONTINUING
         # for dicts in $dicts                 #ANOTHER 'FOR' LOOP...
            # dict_name=dicts.name             #GET THE DICT. NAME
            # ent.attribute_dictionary(dict_name, true)    #CREATE THE ATTRIBUTE DICTIONARY (AD) FOR THIS OBJECT
            # 0.upto($values.length-1) do |x|  #NUMBER LOOP TO SET ALL THE KEY-VALUE PAIRS
               # ent.set_attribute(dict_name,$prompts[x],$values[x])      #ADD THE ATTRIBUTES TO THE AD FOR THIS OBJECT
            # end                              #END NUMBER LOOP
         # end                                 #END 'FOR' LOOP
      # end                                    #END 'IF' BLOCK
   # end                                       #END 'FOR' LOOP
# end                                          #END THE FUNCTION DEFINITION


if( not file_loaded?("attributes.rb") )                  #IF THE RUBY FILE HASN'T ALREADY BEEN LOADED, DO THE FOLLOWING...
   UI.add_context_menu_handler do |menu|                 #GET THE CONTEXT MENU
      menu.add_separator                                 #ADD A SEPARATOR TO THE CONTEXT MENU
      submenu=menu.add_submenu("Edit Attributes")        #ADD A CONTEXT MENU ITEM CALLED 'ATTRIBUTES'
         submenu.add_item("Set Attributes") { att_set }  #ADD THIS SUBITEM TO THE ATTRIBUTES MENU ITEM
         submenu.add_item("Get Attributes") { att_get }  #ADD THIS SUBITEM TO THE ATTRIBUTES MENU ITEM
#         submenu.add_item("Apply Attributes") { att_apply }    #ADD THIS SUBITEM TO THE ATTRIBUTES MENU ITEM
   end                                                   #END THE CONTEXT MENU ADDITION
end                                                      #END THE 'IF' STATEMENT

#-----------------------------------------------------------------------------
file_loaded("attributes.rb")                 #TELL SKETCHUP THAT THIS RUBY FILE HAS BEEN LOADED
