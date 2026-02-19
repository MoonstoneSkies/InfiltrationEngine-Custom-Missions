local runService = game:GetService("RunService")

local toolbar = plugin:CreateToolbar("Mission Exporter")
local ExportButton = toolbar:CreateButton("Exporter", "Exporter", "rbxassetid://86828934223336")

local Exporter = require(script.Parent.Writing.Main)

-- Should silence morgan's studio warnings about anti-tamper
local Api
if runService:IsStudio() and not runService:IsRunMode() then
	Api = require("./API/Main")
else
	Api = { Clean = function() end, Init = function() end }
end

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