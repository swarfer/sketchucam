
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/PSUpgrade.rb'

module PhlatScript

  class AppChangeObserver < Sketchup::AppObserver

    def onNewModel(model)
      PhlatScript.setModelOptions(model)
      model.add_observer(PhlatScript.modelChangeObserver)
    end

    def onOpenModel(model)
      if PhlatScript.tryUpgrade?   # defaults to false as of V1.4a
         PSUpgrader.upgrade
      end
      PhlatScript.setModelOptions(model)
      model.add_observer(PhlatScript.modelChangeObserver)
    end

  end

  class ModelChangeObserver < Sketchup::ModelObserver

    def onSaveModel(model)
      PhlatScript.doSave(model)
    end

  end

end
