local module = {}

local TerrainSerialization = require(script.Parent.TerrainSerialization)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable

function module:GetTerrainFolder()
	if not workspace:FindFirstChild("DebugMission") then
		return
	end
	if not workspace.DebugMission:FindFirstChild("TerrainData") then
		Create("Folder", {
			Name = "TerrainData",
			Parent = workspace.DebugMission,
		})
	end
	return workspace.DebugMission.TerrainData
end

function module:GetTerrainBounds()
	local areaMin, areaMax = Vector3.new(-10, -2, -10), Vector3.new(10, 2, 10)
	local dataFolder = self:GetTerrainFolder()
	if dataFolder then
		if workspace.DebugMission:FindFirstChild("TerrainBounds") then
			areaMin, areaMax = TerrainSerialization:GetCoordinateBoundsFromPart(workspace.DebugMission.TerrainBounds)
			dataFolder:SetAttribute("BoundsMin", areaMin)
			dataFolder:SetAttribute("BoundsMax", areaMax)
		else
			local savedMin, savedMax = dataFolder:GetAttribute("BoundsMin"), dataFolder:GetAttribute("BoundsMax")
			if savedMin then
				areaMin = savedMin
			else
				dataFolder:SetAttribute("BoundsMin", areaMin)
			end
			if savedMax then
				areaMax = savedMax
			else
				dataFolder:SetAttribute("BoundsMax", areaMax)
			end
		end
	end
	return areaMin, areaMax
end

function module.Init(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

	module.UI = Create("ScreenGui", {
		Parent = game.CoreGui,
		Archivable = false,
	}, {
		Create("Frame", {
			Size = UDim2.new(0, 300, 1, -100),
			Position = UDim2.new(0, 20, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
		}, {
			Create("UIListLayout", {
				Padding = UDim.new(0, 20),
			}),
			Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				Text = "Save Terrain Data To Mission",
				TextColor3 = Color3.new(1, 1, 1),
				Activated = function()
					local dataFolder = module:GetTerrainFolder()
					local areaMin, areaMax = module:GetTerrainBounds()
					TerrainSerialization:SaveArea(dataFolder, areaMin, areaMax)
				end,
			}),
			Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				Text = "Load Terrain Data From Mission To Workspace",
				TextColor3 = Color3.new(1, 1, 1),
				Activated = function()
					local dataFolder = module:GetTerrainFolder()
					TerrainSerialization:LoadArea(dataFolder)
				end,
			}),
		}),
	})
end

function module.Clean()
	module.Active = false
	if module.UI then
		module.UI:Destroy()
		module.UI = nil
	end
end

return module
