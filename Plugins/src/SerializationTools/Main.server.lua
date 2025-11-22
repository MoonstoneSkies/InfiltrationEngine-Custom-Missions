local toolbar = plugin:CreateToolbar("Mission Exporter")
local ExportButton = toolbar:CreateButton("Exporter", "Exporter", "rbxassetid://86828934223336")

local Api = require(script.Parent.API.Main)
local Exporter = require(script.Parent.Writing.Main)

local CurrentPlugin = nil

ExportButton.Click:Connect(function()
	if CurrentPlugin ~= Exporter then
		if CurrentPlugin then
			CurrentPlugin.Clean()
		end
		CurrentPlugin = Exporter
		plugin:Activate(true)
		Exporter.Init(plugin:GetMouse())
	else
		plugin:Deactivate()
	end
end)

local function disablePlugin()
	Exporter.Clean()
	CurrentPlugin = nil
end

local function unloadPlugin()
	Api.Clean()
	disablePlugin()
end

plugin.Unloading:Connect(unloadPlugin)
plugin.Deactivation:Connect(disablePlugin)

Api.Init()