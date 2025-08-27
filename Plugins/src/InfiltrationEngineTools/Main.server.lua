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

local MeadowMap = require(script.Parent.MeadowMap.Main)
local DoorAccess = require(script.Parent.DoorAccess.Main)
local PropBarrier = require(script.Parent.PropBarrier.Main)
local PropPreview = require(script.Parent.PropPreview.Main)
local CombatMap = require(script.Parent.CombatMap.Main)
local ZoneMarker = require(script.Parent.ZoneMarker.Main)
local AttributeSearch = require(script.Parent.AttributeSearch.Main)
local SectionVisibility = require(script.Parent.SectionVisibility.Main)
local CurrentPlugin = nil

local VisibilityToggle = require(script.Parent.Util.VisibilityToggle)

MeadowMapButton.Click:connect(function()
	if CurrentPlugin ~= MeadowMap then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = MeadowMap
		plugin:Activate(true)
		MeadowMap.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

DoorAccessButton.Click:connect(function()
	if CurrentPlugin ~= DoorAccess then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = DoorAccess
		plugin:Activate(true)
		CurrentPlugin.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

PropBarrierButton.Click:connect(function()
	if CurrentPlugin ~= PropBarrier then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = PropBarrier
		plugin:Activate(true)
		CurrentPlugin.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

PropPreviewButton.Click:connect(function()
	if CurrentPlugin ~= PropPreview then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = PropPreview
		plugin:Activate(true)
		CurrentPlugin.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

CombatMapButton.Click:connect(function()
	if CurrentPlugin ~= CombatMap then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = CombatMap
		plugin:Activate(true)
		CurrentPlugin.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

ZoneMarkerButton.Click:connect(function()
	if CurrentPlugin ~= ZoneMarker then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = ZoneMarker
		plugin:Activate(true)
		CurrentPlugin.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

AttributeSearchButton.Click:connect(function()
	if CurrentPlugin ~= AttributeSearch then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = AttributeSearch
		plugin:Activate(true)
		CurrentPlugin.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

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
	VisibilityToggle.HideTempRevealedParts(workspace:FindFirstChild("DebugMission"))
	CurrentPlugin = nil
end

plugin.Unloading:connect(disablePlugin)
plugin.Deactivation:connect(disablePlugin)
