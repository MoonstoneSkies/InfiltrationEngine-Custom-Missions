--!strict

local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Parent.Util.Button)
local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)

local DEFAULT_COLOR = Color3.fromRGB(163, 162, 165)
local OFF_COLOR = Color3.fromRGB(30, 30, 30)
local ON_COLOR = Color3.fromRGB(0, 170, 170)

local ATTRIBUTE_NAME = "HasTopBarrier"
local PROP_BARRIER = "PropBarrier"

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived

local module = {}
module.Active = false
module.DoorState = {}

-- Input Processing
module.ProcessInput = function(self, io)
	if io.UserInputState == Enum.UserInputState.Begin then
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			local part = self.Mouse.Target
			if part and part.Parent.Name == "Props" then
				local newValue = if part:GetAttribute(ATTRIBUTE_NAME) then nil else true
				part:SetAttribute(ATTRIBUTE_NAME, newValue)
				part.Color = newValue and ON_COLOR or OFF_COLOR
			end
		end
	end
end

local MAX_DIST = 20
local IgnoreList = {}
local CastConfig = RaycastParams.new()
CastConfig.FilterType = Enum.RaycastFilterType.Exclude

module.GetProjectedDistance = function(self, pos: Vector3, dir: Vector3)
	local cast = workspace:Raycast(pos, dir * MAX_DIST, CastConfig)
	local cellsModel = workspace:FindFirstChild("DebugMission")
	cellsModel = cellsModel and cellsModel:FindFirstChild("Cells")
	while
		cast
		and cast.Instance
		and cast.Instance.Transparency > 0.3
		and (not cellsModel or not cast.Instance:IsDescendantOf(cellsModel))
	do
		table.insert(IgnoreList, cast.Instance)
		CastConfig.FilterDescendantsInstances = IgnoreList
		cast = workspace:Raycast(pos, dir * MAX_DIST, CastConfig)
	end

	if cast then
		return cast.Distance
	end

	return MAX_DIST
end

-- Init/Cleanup
module.Init = function(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

	if workspace:FindFirstChild("DebugMission") and workspace.DebugMission:FindFirstChild("Props") then
		for _, prop in pairs(workspace.DebugMission.Props:GetDescendants()) do
			if prop:IsA("BasePart") then
				prop.Color = prop:GetAttribute(ATTRIBUTE_NAME) and ON_COLOR or OFF_COLOR
			end
		end

		if workspace.DebugMission:FindFirstChild("Barrier") then
			VisibilityToggle.TempReveal(workspace.DebugMission.Barrier)

			for _, part in pairs(workspace.DebugMission.Barrier:GetChildren()) do
				if part:GetAttribute(PROP_BARRIER) then
					part:Destroy()
				end
			end
		end
	end

	local self = module
	self.Mouse = mouse

	self.InputEvent = UserInputService.InputBegan:Connect(function(io)
		self:ProcessInput(io)
	end)
end

module.Clean = function()
	if not module.Active then
		return
	end
	module.Active = false

	local self = module

	if workspace:FindFirstChild("DebugMission") and workspace.DebugMission:FindFirstChild("Props") then
		for _, prop in pairs(workspace.DebugMission.Props:GetDescendants()) do
			if prop:IsA("BasePart") then
				prop.Color = DEFAULT_COLOR

				if prop:GetAttribute(ATTRIBUTE_NAME) then
					local top = prop.CFrame * CFrame.new(0, prop.Size.Y / 2, 0)
					local dist = module:GetProjectedDistance(top.p, Vector3.yAxis)

					local b = Instance.new("Part")
					b.Color = ON_COLOR
					b.Size = Vector3.new(prop.Size.X, dist, prop.Size.Z)
					b.CFrame = top * CFrame.new(0, dist / 2, 0)
					b.Anchored = true
					b.Transparency = 0.5
					b.TopSurface = Enum.SurfaceType.SmoothNoOutlines
					b.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
					b.CastShadow = false

					b:SetAttribute(PROP_BARRIER, true)

					b.Parent = workspace.DebugMission.Barrier
				end
			end
		end
	end

	self.InputEvent:Disconnect()
	self.InputEvent = nil
end

return module
