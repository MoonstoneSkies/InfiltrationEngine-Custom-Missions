--!strict

-- Infiltration Engine Tooling created by Cishshato
-- Modified by GhfjSpero
-- All Rights Reserved

local plugin: Plugin = plugin
local Workspace = workspace

local toolbar: PluginToolbar = plugin:CreateToolbar("Infiltration Engine Tools")
local MeadowMapButton: PluginToolbarButton = toolbar:CreateButton("Meadow Map", "Meadow Map", "rbxassetid://13749858361")
local DoorAccessButton: PluginToolbarButton = toolbar:CreateButton("Door Access", "Door Access", "rbxassetid://72317736899762")
local PropBarrierButton: PluginToolbarButton = toolbar:CreateButton("Prop Barrier", "Prop Barrier", "rbxassetid://119815023380659")
local PropPreviewButton: PluginToolbarButton = toolbar:CreateButton("Prop Preview", "Prop Preview", "rbxassetid://129506771895350")
local CombatMapButton: PluginToolbarButton = toolbar:CreateButton("Combat Flow Map", "Combat Flow Map", "rbxassetid://107812298422418")
local ZoneMarkerButton: PluginToolbarButton = toolbar:CreateButton("Cell Marker", "Cell Editor", "rbxassetid://97000446266881")
local AttributeSearchButton: PluginToolbarButton = toolbar:CreateButton("Attribute Search", "Attribute Search", "rbxassetid://18733558044")
local SectionVisibilityButton: PluginToolbarButton =
	toolbar:CreateButton("Section Visibility", "Section Visibility", "rbxassetid://8753176416")

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
	Init: (PluginMouse) -> (),
	Clean: () -> (),
}

local CurrentPlugin: PluginModule? = nil

-- Helper

local function safeCall(fn: () -> (), ctx: string?)
	local ok, err = pcall(fn) :: boolean, string
	if not ok then
		warn("Plugin error" .. (ctx and (" in " .. ctx) or "") .. ": " .. tostring(err))
	end
end

local function activateModule(mod: PluginModule)
	if not mod then return end
	-- deactivate current if different
	if CurrentPlugin and CurrentPlugin ~= mod then
		safeCall(CurrentPlugin.Clean, "CurrentPlugin.Clean")
	end
	CurrentPlugin = mod
	-- ensure plugin is active and mouse provided
	plugin:Activate(true)
	local ok, mouseOrErr = pcall(function() return plugin:GetMouse() end)
	if ok and mouseOrErr then
		safeCall(function() mod.Init(mouseOrErr :: PluginMouse) end, "Module.Init")
	else
		-- fallback: try calling Init without mouse if module supports it
		safeCall(function() mod.Init(nil :: any) end, "Module.Init(no-mouse)")
	end
end

local function deactivateAll()
	local modules: { PluginModule } = {
		MeadowMap, DoorAccess, PropBarrier, PropPreview, CombatMap, ZoneMarker, AttributeSearch,
	}
	for _, m in ipairs(modules) do
		safeCall(m.Clean, tostring(m))
	end
	-- hide any revealed mission parts
	safeCall(function()
		local dbg = Workspace:FindFirstChild("DebugMission")
		VisibilityToggle.HideTempRevealedParts(dbg)
	end, "HideTempRevealedParts")
	CurrentPlugin = nil
	plugin:Deactivate()
end

local function makeToggle(button: PluginToolbarButton, moduleObj: PluginModule)
	button.Click:Connect(function()
		-- toggle activation when clicking the toolbar button
		if CurrentPlugin ~= moduleObj then
			activateModule(moduleObj)
		else
			-- deactivate current plugin only (leave other modules cleaned)
			deactivateAll()
		end
	end)
end

-- Connection

makeToggle(MeadowMapButton, MeadowMap)
makeToggle(DoorAccessButton, DoorAccess)
makeToggle(PropBarrierButton, PropBarrier)
makeToggle(PropPreviewButton, PropPreview)
makeToggle(CombatMapButton, CombatMap)
makeToggle(ZoneMarkerButton, ZoneMarker)
makeToggle(AttributeSearchButton, AttributeSearch)

SectionVisibilityButton.Click:Connect(function()
	-- ensure no plugin is active while opening the menu
	plugin:Deactivate()
	SectionVisibility.OpenMenu(plugin)
	plugin:Deactivate()
end)

-- Unloading / Deactivation handlers

local unloadingConn: RBXScriptConnection? = nil
local deactivationConn: RBXScriptConnection? = nil

unloadingConn = plugin.Unloading:Connect(function()
	deactivateAll()
	if unloadingConn then
		unloadingConn:Disconnect()
		unloadingConn = nil
	end
	if deactivationConn then
		deactivationConn:Disconnect()
		deactivationConn = nil
	end
end)

deactivationConn = plugin.Deactivation:Connect(function()
	deactivateAll()
end)
