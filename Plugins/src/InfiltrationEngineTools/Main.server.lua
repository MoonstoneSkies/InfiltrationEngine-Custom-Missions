--!nocheck

-- Infiltration Engine Tooling created by Cishshato
-- Modified by GhfjSpero
-- All Rights Reserved

local plugin: Plugin = plugin

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local toolbar: PluginToolbar = plugin:CreateToolbar("Infiltration Engine Tools Test")
local MeadowMapButton: PluginToolbarButton = toolbar:CreateButton("Meadow Map", "Meadow Map", "rbxassetid://13749858361")
local DoorAccessButton: PluginToolbarButton = toolbar:CreateButton("Door Access", "Door Access", "rbxassetid://72317736899762")
local PropBarrierButton: PluginToolbarButton = toolbar:CreateButton("Prop Barrier", "Prop Barrier", "rbxassetid://119815023380659")
local PropPreviewButton: PluginToolbarButton = toolbar:CreateButton("Prop Preview", "Prop Preview", "rbxassetid://129506771895350")
local CombatMapButton: PluginToolbarButton = toolbar:CreateButton("Combat Flow Map", "Combat Flow Map", "rbxassetid://107812298422418")
local ZoneMarkerButton: PluginToolbarButton = toolbar:CreateButton("Cell Marker", "Cell Editor", "rbxassetid://97000446266881")
local AttributeSearchButton: PluginToolbarButton = toolbar:CreateButton("Attribute Search", "Attribute Search", "rbxassetid://18733558044")
local SectionVisibilityButton: PluginToolbarButton = toolbar:CreateButton("Section Visibility", "Section Visibility", "rbxassetid://8753176416")

local MeadowMap = require(script.Parent.MeadowMap.Main)
local DoorAccess = require(script.Parent.DoorAccess.Main)
local PropBarrier = require(script.Parent.PropBarrier.Main)
local PropPreview = require(script.Parent.PropPreview.Main)
local CombatMap = require(script.Parent.CombatMap.Main)
local ZoneMarker = require(script.Parent.ZoneMarker.Main)
local AttributeSearch = require(script.Parent.AttributeSearch.Main)
local SectionVisibility = require(script.Parent.SectionVisibility.Main)

local VisibilityToggle = require(script.Parent.Util.VisibilityToggle)

type PluginModule = {
	Init: (mouse: PluginMouse) -> (),
	Clean: () -> ()
}

local CurrentPlugin: PluginModule? = nil

local RECORDING_SESSION = "InfiltrationEngineTools"

local function tryBeginChange(desc: string): boolean
	local ok, supported = pcall(function()
		return (ChangeHistoryService :: any):TryBeginRecording(RECORDING_SESSION, desc)
	end)
	if ok and supported == true then
		return true
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("Before " .. desc)
	end)
	return false
end

local function finishChange(desc: string)
	local ok, _ = pcall(function()
		(ChangeHistoryService :: any):FinishRecording(RECORDING_SESSION, "Commit")
	end)
	if not ok then
		pcall(function()
			ChangeHistoryService:SetWaypoint("After " .. desc)
		end)
	end
end

local function safeCall(fn: () -> (), ctx: string)
	local ok, err = pcall(fn)
	if not ok then
		warn("Error in " .. ctx .. ": " .. tostring(err))
	end
end

local function switchTo(module: PluginModule)
	local desc = "switch to:" .. tostring(module)
	tryBeginChange(desc)
	if CurrentPlugin and CurrentPlugin ~= module then
		safeCall(function() CurrentPlugin.Clean() end, "CurrentPlugin.Clean")
	end
	CurrentPlugin = module
	plugin:Activate(true)
	safeCall(function() module.Init(plugin:GetMouse()) end, "Module.Init")
	finishChange(desc)
end

local function deactivateCurrent()
	local desc = "deactivate current"
	tryBeginChange(desc)
	if CurrentPlugin then
		safeCall(function() CurrentPlugin.Clean() end, "CurrentPlugin.Clean")
		CurrentPlugin = nil
	end
	
	safeCall(function() MeadowMap.Clean() end, "MeadowMap.Clean")
	safeCall(function() DoorAccess.Clean() end, "DoorAccess.Clean")
	safeCall(function() PropBarrier.Clean() end, "PropBarrier.Clean")
	safeCall(function() PropPreview.Clean() end, "PropPreview.Clean")
	safeCall(function() CombatMap.Clean() end, "CombatMap.Clean")
	safeCall(function() ZoneMarker.Clean() end, "ZoneMarker.Clean")
	safeCall(function() AttributeSearch.Clean() end, "AttributeSearch.Clean")
	local debugMission = workspace:FindFirstChild("DebugMission")
	safeCall(function() VisibilityToggle.HideTempRevealedParts(debugMission) end, "VisibilityToggle.HideTempRevealedParts")
	plugin:Deactivate()
	finishChange(desc)
end

local function toggleOrActivate(module: PluginModule)
	if CurrentPlugin ~= module then
		switchTo(module)
	else
		deactivateCurrent()
	end
end

MeadowMapButton.Click:Connect(function()
	toggleOrActivate(MeadowMap)
end)

DoorAccessButton.Click:Connect(function()
	toggleOrActivate(DoorAccess)
end)

PropBarrierButton.Click:Connect(function()
	toggleOrActivate(PropBarrier)
end)

PropPreviewButton.Click:Connect(function()
	toggleOrActivate(PropPreview)
end)

CombatMapButton.Click:Connect(function()
	toggleOrActivate(CombatMap)
end)

ZoneMarkerButton.Click:Connect(function()
	toggleOrActivate(ZoneMarker)
end)

AttributeSearchButton.Click:Connect(function()
	toggleOrActivate(AttributeSearch)
end)

SectionVisibilityButton.Click:Connect(function()
	local desc = "open section visibility"
	tryBeginChange(desc)
	plugin:Deactivate()
	safeCall(function() SectionVisibility.OpenMenu(plugin) end, "SectionVisibility.OpenMenu")
	plugin:Deactivate()
	finishChange(desc)
end)

plugin.Unloading:Connect(function()
	deactivateCurrent()
end)

if plugin.Deactivation then
	plugin.Deactivation:Connect(function()
		deactivateCurrent()
	end)
end
