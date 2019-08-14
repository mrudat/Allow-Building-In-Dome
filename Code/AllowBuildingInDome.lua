local orig_print = print
if Mods.mrudat_TestingMods then
  print = orig_print
else
  print = empty_func
end

local CurrentModId = rawget(_G, 'CurrentModId') or rawget(_G, 'CurrentModId_X')
local CurrentModDef = rawget(_G, 'CurrentModDef') or rawget(_G, 'CurrentModDef_X')
if not CurrentModId then

  -- copied shamelessly from Expanded Cheat Menu
  local Mods, rawset = Mods, rawset
  for id, mod in pairs(Mods) do
    rawset(mod.env, "CurrentModId_X", id)
    rawset(mod.env, "CurrentModDef_X", mod)
  end

  CurrentModId = CurrentModId_X
  CurrentModDef = CurrentModDef_X
end

orig_print("loading", CurrentModId, "-", CurrentModDef.title)

DefineClass.mrudat_AllowBuildingInDome = {
}

function mrudat_AllowBuildingInDome.find_method(class_name, method_name, seen)
  seen = seen or {}
  local class = _G[class_name]
  local method = class[method_name]
  if method then return method end
  local find_method = mrudat_AllowBuildingInDome.find_method
  for _, parent_class_name in ipairs(class.__parents or empty_table) do
    if not seen[parent_class_name] then
      method = find_method(parent_class_name, method_name, seen)
      if method then return method end
      seen[parent_class_name] = true
    end
  end
end
local find_method = mrudat_AllowBuildingInDome.find_method

function mrudat_AllowBuildingInDome.wrap_method(class_name, method_name, wrapper)
  local orig_method = _G[class_name][method_name]
  if not orig_method then
    if RecursiveCallOrder[method_name] ~= nil or AutoResolveMethods[method_name] then
      orig_method = empty_func
    else
      orig_method = find_method(class_name, method_name)
    end
  end
  if not orig_method then orig_print("Error: couldn't find method to wrap for", class_name, method_name, "refusing to proceed") return end
  _G[class_name][method_name] = function(self, ...)
    return wrapper(self, orig_method, ...)
  end
end
local wrap_method = mrudat_AllowBuildingInDome.wrap_method

local function starts_with(str, start)
  return str:sub(1, #start) == start
end

mrudat_AllowBuildingInDome.forbidden_template_classes = {
  -- can't launch shuttles through glass
  ShuttleHub = true,
  -- can't land a rocket through the dome.
  TradePad = true,
  LandingPad = true,

  -- can already build an indoor version.
  OpenFarm = true,
  OpenPasture = true,

  -- technically redundant, given you can only build a ramp over a passage...
  PassageRamp = true,

  -- stuff assoicated with mysteries.
  BlackCubeMonolith = true,
  LightTrap = true,
  MirrorSphereBuilding = true,
  PowerDecoy = true,

  -- can't shoot through the dome.
  DefenceTower = true,
  MDSLaser = true,

  -- can't pass through the dome.
  SpaceElevator = true,

  -- Apparently it turns 2CO2 -> 2CO + O2; still can't run it indoors; CO binds to haemoglobin better than O does.
  MOXIE = true,

  -- a rover inside a dome isn't particularly useful.
  Tunnel = true,

  -- other.
  LandscapeRampBuilding = true,
  LandscapeTerraceBuilding = true,
  LandscapeTextureBuilding = true,

  -- perhaps smallest lake might fit?
  LandscapeLake = true,

  -- requires behaviour change
  DroneHub = true, -- See Indoor drone controller
  TriboelectricScrubber = true,
  SubsurfaceHeater = true, -- see Indome Subsurface Heater
  ForestationPlant = true, -- see Indome Forestation Plant
  MoistureVaporator = true -- see Moisture Reclamation System
}
local forbidden_template_classes = mrudat_AllowBuildingInDome.forbidden_template_classes

-- sort in ascending order of number of building templates.
mrudat_AllowBuildingInDome.forbidden_classnames = {
  Dome = true,
  BaseRoverBuilding = true, -- not BaseRover!
  SupplyRocket = true,
  SupplyPod = true,
  DustGenerator = true, -- requires behaviour change, see Dusty Indome Buildings
  Drone = true,
  WindTurbine = true,
}
local forbidden_classnames = mrudat_AllowBuildingInDome.forbidden_classnames

-- buildings that are in OutsideBuildings, but can already be built inside a dome.
mrudat_AllowBuildingInDome.allowed_buildings = {
  StirlingGenerator = true,
  AdvancedStirlingGenerator = true,
  RechargeStation = true,
  SolarPanel = true,
  SolarPanelBig = true,
}
local allowed_buildings = mrudat_AllowBuildingInDome.allowed_buildings

function mrudat_AllowBuildingInDome.AddPropertyToClass(class, new_property)
  local new_property_id = new_property.id
  local properties = class.properties
  for _, property in ipairs(properties) do
    if property.id == new_property_id then return end
  end
  properties[#properties + 1] = new_property
end
local AddPropertyToClass = mrudat_AllowBuildingInDome.AddPropertyToClass

function mrudat_AllowBuildingInDome.InjectParent(class, parent_class)
  if IsKindOf(class, parent_class) then return end
  local parents = class.__parents
  parents[#parents + 1] = parent_class
end
local InjectParent = mrudat_AllowBuildingInDome.InjectParent

function mrudat_AllowBuildingInDome.AllowBuildingInDome(building_template)
  if building_template.mrudat_AllowBuildingInDome then return end

  local id = building_template.id

  local class_template = ClassTemplates.Building[id]

  orig_print("Allowing building_template", id, "to be built indoors")

  local templates = {
    building_template,
    class_template
  }

  local data = {}

  for _, template in ipairs(templates) do
    template.mrudat_AllowBuildingInDome = data
    template.dome_forbidden = false
  end

  local labels = {}

  for _, template in ipairs(templates) do
    for k,v in pairs(template) do
      if starts_with(k, 'label') then
        labels[v] = true
        template[k] = nil
      end
    end
  end

  local outside_labels = {}
  local inside_labels = {}
  data.outside_labels = outside_labels
  data.inside_labels = inside_labels

  if labels['OutsideBuildings'] then
    outside_labels['OutsideBuildings'] = true
    inside_labels['InsideBuildings'] = true
    labels['OutsideBuildings'] = nil
  end

  if labels['OutsideBuildingsTargets'] then
    outside_labels['OutsideBuildingsTargets'] = true
    labels['OutsideBuildingsTargets'] = nil
  end

  local label_index = 1

  for label in pairs(labels) do
    local label_name = 'label' .. label_index
    for _, template in ipairs(templates) do
      template[label_name] = label
    end
    label_index = label_index + 1
  end

  -- for some reaosn, class_template.mrudat_AllowBuildingInDome is removed later?
end
local AllowBuildingInDome = mrudat_AllowBuildingInDome.AllowBuildingInDome

function PatchBuildingTemplate(building_template)
  local id = building_template.id

  if allowed_buildings[id] then
    return AllowBuildingInDome(building_template)
  end

  if not building_template.dome_forbidden then return end

  if building_template.mrudat_AllowBuildingInDome then return end

  local template_class = building_template.template_class

  if not template_class then return end

  if forbidden_template_classes[template_class] then return end

  local class = g_Classes[template_class]

  if not class then return end

  for _, classname in pairs(forbidden_classnames) do
    if class:IsKindOf(classname) then return end
  end

  for classname in pairs(forbidden_template_classes) do
    if class:IsKindOf(classname) then return end
  end

  if class:IsKindOf("TerraformingBuildingBase") then
    if template_class ~= 'ForestationPlant' then
      return
    end
  end

  AllowBuildingInDome(building_template)
end

-- TODO fix range visualisation, instead of fiddling with GetPos
function mrudat_AllowBuildingInDome.DomePosOrMyPos(class_name)
  wrap_method(class_name, 'GetPos', function(self, orig_method)
    local dome = self.parent_dome
    if dome then
      return dome:GetPos()
    end
    local pos = orig_method(self)
    dome = GetDomeAtPoint(pos)
    if dome then
      return dome:GetPos()
    end
    self.GetPos = orig_method
    return pos
  end)
end

-----------
-- Building

local orig_Building_SetCustomLables = Building.SetCustomLabels
function Building:SetCustomLabels(obj, add)
  orig_Building_SetCustomLables(self, obj, add)

  local template_name = self.template_name
  if not template_name then return end

  local template = BuildingTemplates[template_name]
  if not template then return end

  local data = template.mrudat_AllowBuildingInDome
  if not data then return end

  local dome = self.parent_dome
  if not dome then
    dome = GetDomeAtPoint(self:GetPos())
  end

  local labels = dome and data.inside_labels or data.outside_labels

  local func = add and obj.AddToLabel or obj.RemoveFromLabel

  for label in pairs(labels) do
    func(obj, label, self)
  end
end

local orig_ConstructionSite_SetCustomLables = ConstructionSite.SetCustomLabels
function ConstructionSite:SetCustomLabels(obj, add)
  orig_ConstructionSite_SetCustomLables(self, obj, add)

  local proto = self.building_class_proto
  if not proto then return end

  local template_name = proto.template_name
  if not template_name then return end

  local template = BuildingTemplates[template_name]
  if not template then return end

  local data = template.mrudat_AllowBuildingInDome
  if not data then return end

  local dome = self.parent_dome
  if not dome then
    dome = GetDomeAtPoint(self:GetPos())
  end

  local labels = dome and data.inside_labels or data.outside_labels

  local func = add and obj.AddToLabel or obj.RemoveFromLabel

  for label in pairs(labels) do
    func(obj, label .. g_ConstructionSiteLabelSuffix, self)
  end
end

-------
-- Msgs

function OnMsg.ModsReloaded()
  print("allowed_buildings",mrudat_AllowBuildingInDome.allowed_buildings)
  print("forbidden_template_classes",mrudat_AllowBuildingInDome.forbidden_template_classes)
  print("forbidden_classnames",mrudat_AllowBuildingInDome.forbidden_classnames)
  local BuildingTemplates = BuildingTemplates
  for id, building_template in pairs(BuildingTemplates) do
    PatchBuildingTemplate(building_template)
  end
end

-- On the off chance that we remove _all_ inside/outside labels.
function OnMsg.GatherLabels(labels)
  labels.OutsideBuildings = true
  labels.OutsideBuildingsTargets = true
  labels.InsideBuildings = true
end

orig_print("loaded", CurrentModId, "-", CurrentModDef.title)
