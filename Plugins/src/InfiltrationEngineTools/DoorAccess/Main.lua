--!strict

local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Parent.Util.Button)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived

local module = {}
module.Active = false
module.DoorState = {}

local RESTRICTIONS_LIST = {
	"Never",
	"Combat",
	"BasicKeycard",
	"SecurityKeycard",
	"MasterKeycard",
	"MRKey",
	"MasterKey",
	"SecurityBadge",
	"LeadSecurityBadge",
	"ITBadge",
}

type DoorData = {
	Base: Part?,
	Side: number?,
	Restrictions: { [number]: string },
	Recover: boolean,
	Locked: boolean,
	IgnoreWhenOpen: boolean,
	IgnoreWhenUnlocked: boolean,
	IgnoreWhenBroken: boolean,
	Display: Part?,
}

local DEFAULT_DOOR_STATE: DoorData = {
	Restrictions = {},
	Recover = false,
	Locked = false,
	IgnoreWhenOpen = false,
	IgnoreWhenUnlocked = false,
	IgnoreWhenBroken = false,
}

module.UIState = State(DEFAULT_DOOR_STATE)
function module:UpdateSelectedState(key: string, value: any)
	local newData = {}
	for k, v in pairs(self.UIState._Value) do
		newData[k] = if k ~= key then v else value
	end
	self.UIState:set(newData)
end

-- Data Load/Unload
function module:GetDoorsFromLevel()
	local doors = {}
	local props = workspace.DebugMission.Props:GetChildren()
	for _, part in pairs(props) do
		if string.match(part.Name, "^Door") then
			table.insert(doors, part)
		end
	end
	return doors
end

function module:ReadData(part: Part, side: number)
	local atr = part:GetAttributes()
	local req = atr["PathReq" .. side]
	local data: DoorData = {
		Base = part,
		Side = side,
		Restrictions = {},
		Locked = atr[side == 1 and "LockFront" or "LockBack"],
		Recover = atr.PathRecover and atr.PathRecover % (side + side) >= side or false,
		IgnoreWhenOpen = atr.PathIgnoreOpen and atr.PathIgnoreOpen % (side + side) >= side or false,
		IgnoreWhenUnlocked = atr.PathIgnoreUnlocked and atr.PathIgnoreUnlocked % (side + side) >= side or false,
		IgnoreWhenBroken = atr.PathIgnoreBroken and atr.PathIgnoreBroken % (side + side) >= side or false,
	}
	if req then
		for s in req:gmatch("(%a+)") do
			table.insert(data.Restrictions, s)
		end
	end
	return data
end

local function setBitMaskValue(mask: number, bit: number, enabled: boolean)
	local n = if mask % (bit + bit) >= bit then mask - bit else mask
	if enabled then
		n += bit
	end
	return n
end

function module:WriteData(part: Part, side: number, data: DoorData)
	local atr = part:GetAttributes()
	local req = table.concat(data.Restrictions, " ")
	part:SetAttribute("PathReq" .. side, if req ~= "" then req else nil)

	part:SetAttribute(side == 1 and "LockFront" or "LockBack", data.Locked)

	local recover = setBitMaskValue(atr.PathRecover or 0, side, data.Recover)
	part:SetAttribute("PathRecover", if recover ~= 0 then recover else nil)

	local ignoreOpen = setBitMaskValue(atr.PathIgnoreOpen or 0, side, data.IgnoreWhenOpen)
	part:SetAttribute("PathIgnoreOpen", if ignoreOpen ~= 0 then ignoreOpen else nil)

	local ignoreUnlocked = setBitMaskValue(atr.PathIgnoreUnlocked or 0, side, data.IgnoreWhenUnlocked)
	part:SetAttribute("PathIgnoreUnlocked", if ignoreUnlocked ~= 0 then ignoreUnlocked else nil)

	local ignoreBroken = setBitMaskValue(atr.PathIgnoreBroken or 0, side, data.IgnoreWhenBroken)
	part:SetAttribute("PathIgnoreBroken", if ignoreBroken ~= 0 then ignoreBroken else nil)

	local newData = self:ReadData(part, side)
	newData.Display = self.DoorState[part][side].Display
	self.DoorState[part][side] = newData
	self:UpdateDisplayedData(newData)
end

-- Display
local COLOR_MAP = {
	Unrestricted = Color3.new(0, 0.8, 0),
	Recovery = Color3.new(0, 0.8, 0),
	Unlocked = Color3.new(0, 0.8, 0),
	Combat = Color3.new(0.8, 0, 0),
	Never = Color3.new(0.8, 0, 0),
	Locked = Color3.new(0.8, 0, 0),
}

function module:UpdateDisplayedData(data: DoorData)
	if data.Display then
		data.Display:Destroy()
		data.Display = nil
	end

	local listItems = {}
	table.insert(listItems, data.Locked and "Locked" or "Unlocked")

	if #data.Restrictions == 0 then
		table.insert(listItems, "Unrestricted")
	else
		table.insert(listItems, table.concat(data.Restrictions, " - "))
	end

	if data.Recover then
		table.insert(listItems, "Recovery")
	end

	if data.IgnoreWhenOpen then
		table.insert(listItems, "Ignore When Open")
	end

	if data.IgnoreWhenUnlocked then
		table.insert(listItems, "Ignore When Unlocked")
	end

	if data.IgnoreWhenBroken then
		table.insert(listItems, "Ignore When Broken")
	end

	for index, item in pairs(listItems) do
		listItems[index] = Create("TextLabel", {
			Text = item,
			TextColor3 = COLOR_MAP[item] or Color3.new(1, 1, 1),
			Font = Enum.Font.SciFi,
			TextSize = 42,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			TextWrapped = true,
		})
	end

	if data.Base then
		data.Display = Create("Part", {
			CFrame = data.Base.CFrame * CFrame.Angles(0, data.Side == 2 and math.pi or 0, 0) * CFrame.new(0, 0, -0.5),
			Size = Vector3.new(4, 4, 0.2),
			Parent = workspace,
			Material = Enum.Material.Glass,
			Color = Color3.new(0, 0, 0),
		}, {
			Create("SurfaceGui", {
				PixelsPerStud = 25,
			}, {
				Create("Frame", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
				}, {
					Create("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 10),
					}),
					listItems,
				}),
			}),
		})
	end
end

-- Input Processing
module.ProcessInput = function(io: InputObject)
	if io.UserInputState == Enum.UserInputState.Begin then
		local door, side = module:GetHoveredDoor()
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			if door and side then
				print("Overwrite")
				module:WriteData(door, side, module.UIState._Value)
			end
		elseif io.KeyCode == Enum.KeyCode.F or io.KeyCode == Enum.KeyCode.C then
			if door and side then
				print("Copy door data")
				module.UIState:set(module:ReadData(door, side))
			else
				print("Clearing door data")
				module.UIState:set(DEFAULT_DOOR_STATE)
			end
		end
	end
end

function module:GetHoveredDoor(): (Part?, number?)
	local part = self.Mouse.Target
	if part and part:IsA("Part") and self.DoorState[part] then
		local hit = self.Mouse.Hit.Position
		local rel = part.CFrame:PointToObjectSpace(hit)
		return part, if rel.Z < 0 then 1 else 2
	end
	return nil, nil
end

-- UI setup
function module:InitUI()
	local buttons = {
		Button({
			Text = "Locked",
			Enabled = Derived(function(data: DoorData)
				return data.Locked
			end, self.UIState),
			Activated = function()
				self:UpdateSelectedState("Locked", not self.UIState._Value.Locked)
			end,
		}),
		Button({
			Text = "Recovery",
			Enabled = Derived(function(data: DoorData)
				return data.Recover
			end, self.UIState),
			Activated = function()
				self:UpdateSelectedState("Recover", not self.UIState._Value.Recover)
			end,
		}),
		Button({
			Text = "Ignore When Open",
			Enabled = Derived(function(data: DoorData)
				return data.IgnoreWhenOpen
			end, self.UIState),
			Activated = function()
				self:UpdateSelectedState("IgnoreWhenOpen", not self.UIState._Value.IgnoreWhenOpen)
			end,
		}),
		Button({
			Text = "Ignore When Unlocked",
			Enabled = Derived(function(data: DoorData)
				return data.IgnoreWhenUnlocked
			end, self.UIState),
			Activated = function()
				self:UpdateSelectedState("IgnoreWhenUnlocked", not self.UIState._Value.IgnoreWhenUnlocked)
			end,
		}),
		Button({
			Text = "Ignore When Broken",
			Enabled = Derived(function(data: DoorData)
				return data.IgnoreWhenBroken
			end, self.UIState),
			Activated = function()
				self:UpdateSelectedState("IgnoreWhenBroken", not self.UIState._Value.IgnoreWhenBroken)
			end,
		}),
	}

	for index, text in pairs(RESTRICTIONS_LIST) do
		table.insert(
			buttons,
			Button({
				Text = text,
				Enabled = Derived(function(data: DoorData)
					for _, restriction in pairs(data.Restrictions) do
						if restriction == text then
							return true
						end
					end
					return false
				end, module.UIState),
				Activated = function()
					local wasRemoved = false
					local copy = {}
					for _, restriction in pairs(module.UIState._Value.Restrictions) do
						if restriction ~= text then
							table.insert(copy, restriction)
						else
							wasRemoved = true
						end
					end
					if not wasRemoved then
						table.insert(copy, text)
					end
					self:UpdateSelectedState("Restrictions", copy)
				end,
			})
		)
	end

	self.UI = Create("ScreenGui", {
		Parent = game:GetService("CoreGui"),
		Archivable = false,
		Name = "DoorAccessConfig",
	}, {
		Create("Frame", {
			Position = UDim2.new(1, -20, 1, -20),
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.new(0, 200, 0, 200),
			BackgroundTransparency = 1,
		}, {
			Create("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}),
			buttons,
		}),
	})
end

function module:CleanUI()
	if self.UI then
		self.UI:Destroy()
		self.UI = nil
	end
end

-- Init/Cleanup
module.Init = function(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

	local self = module
	self.Mouse = mouse

	for _, door in pairs(self:GetDoorsFromLevel()) do
		self.DoorState[door] = {
			self:ReadData(door, 1),
			self:ReadData(door, 2),
		}
		self:UpdateDisplayedData(self.DoorState[door][1])
		self:UpdateDisplayedData(self.DoorState[door][2])
	end

	self:InitUI()

	self.InputEvent = UserInputService.InputBegan:Connect(module.ProcessInput)
end

module.Clean = function()
	if not module.Active then
		return
	end
	module.Active = false

	local self = module

	self.InputEvent:Disconnect()
	self.InputEvent = nil

	for _, list in pairs(self.DoorState) do
		for _, data in pairs(list) do
			if data.Display then
				data.Display:Destroy()
			end
		end
	end
	self.DoorState = {}

	self:CleanUI()
end

return module
