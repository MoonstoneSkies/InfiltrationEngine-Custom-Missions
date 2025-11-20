-- Infiltration Engine Tooling created by Cishshato
-- Modified by GhfjSpero
-- All Rights Reserved

local toolbar = plugin:CreateToolbar("Infiltration Engine Tools")
local MeadowMapButton = toolbar:CreateButton("Meadow Map", "Meadow Map", "rbxassetid://13749858361")
local DoorAccessButton = toolbar:CreateButton("Door Access", "Door Access", "rbxassetid://72317736899762")
local PropBarrierButton = toolbar:CreateButton("Prop Barrier", "Prop Barrier", "rbxassetid://119815023380659")
local PropPreviewButton = toolbar:CreateButton("Prop Preview", "Prop Preview", "rbxassetid://129506771895350")
local CombatMapButton = toolbar:CreateButton("Combat Flow Map", "Combat Flow Map", "rbxassetid://107812298422418")
local ZoneMarkerButton = toolbar:CreateButton("Cell Marker", "Cell Editor", "rbxassetid://97000446266881")
local AttributeSearchButton = toolbar:CreateButton("Attribute Search", "Attribute Search", "rbxassetid://18733558044")
local SectionVisibilityButton =
	toolbar:CreateButton("Section Visibility", "Section Visibility", "rbxassetid://8753176416")
local TerrainSerializationButton =
	toolbar:CreateButton("Terrain Serialization", "Terrain Serialization", "rbxassetid://115396940325881")

local MeadowMap = require(script.Parent.MeadowMap.Main)
local DoorAccess = require(script.Parent.DoorAccess.Main)
local PropBarrier = require(script.Parent.PropBarrier.Main)
local PropPreview = require(script.Parent.PropPreview.Main)
local CombatMap = require(script.Parent.CombatMap.Main)
local ZoneMarker = require(script.Parent.ZoneMarker.Main)
local AttributeSearch = require(script.Parent.AttributeSearch.Main)
local SectionVisibility = require(script.Parent.SectionVisibility.Main)
local TerrainSerialization = require(script.Parent.TerrainSerialization.Main)
local CurrentPlugin = nil

local VisibilityToggle = require(script.Parent.Util.VisibilityToggle)

local function ConnectPluginToButton(button, pluginModule)
	button.Click:Connect(function()
		if CurrentPlugin ~= pluginModule then
			if CurrentPlugin then
				CurrentPlugin.Clean()
			end
			CurrentPlugin = pluginModule
			plugin:Activate(true)
			pluginModule.Init(plugin:GetMouse())
		else
			plugin:Deactivate()
		end
	end)
end

ConnectPluginToButton(MeadowMapButton, MeadowMap)
ConnectPluginToButton(DoorAccessButton, DoorAccess)
ConnectPluginToButton(PropBarrierButton, PropBarrier)
ConnectPluginToButton(PropPreviewButton, PropPreview)
ConnectPluginToButton(CombatMapButton, CombatMap)
ConnectPluginToButton(ZoneMarkerButton, ZoneMarker)
ConnectPluginToButton(AttributeSearchButton, AttributeSearch)
ConnectPluginToButton(TerrainSerializationButton, TerrainSerialization)

SectionVisibilityButton.Click:Connect(function()
	plugin:Deactivate()
	SectionVisibility.OpenMenu(plugin)
	plugin:Deactivate()
end)

local function disablePlugin()
	MeadowMap.Clean()
	DoorAccess.Clean()
	PropBarrier.Clean()
	PropPreview.Clean()
	CombatMap.Clean()
	ZoneMarker.Clean()
	AttributeSearch.Clean()
	TerrainSerialization.Clean()
	VisibilityToggle.HideTempRevealedParts(workspace:FindFirstChild("DebugMission"))
	CurrentPlugin = nil
end

plugin.Unloading:connect(disablePlugin)
plugin.Deactivation:connect(disablePlugin)
