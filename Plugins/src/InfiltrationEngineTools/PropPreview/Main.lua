local Button = require(script.Parent.Parent.Util.Button)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable

local CustomPropsFolder = State(false)

local NoModelPlaceholder = Instance.new("Model")
local NoModelBase = Instance.new("Part")
NoModelBase.Parent = NoModelPlaceholder
NoModelBase.Transparency = 1
NoModelBase.Size = Vector3.new(0.2, 0.2, 0.2)

local module = {}

local ColorMap = {}
local Prop = {}

local ModelFolder = State(false)
local function UpdateModelFolder()
	local assetsFolder = game.ReplicatedStorage:FindFirstChild("Assets")
	ModelFolder:set(assetsFolder and assetsFolder:FindFirstChild("Props") or false)
end

-- Position/Color
function module:RepositionProp(part)
	local model = Prop[part]
	model = model and model.Model
	local base = model and model:FindFirstChild("Base", true)

	if not base then
		return
	end

	local diff = part.CFrame * base.CFrame:Inverse()
	for _, p in pairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = diff * p.CFrame
		end
	end
end

function module:RecolorProp(part)
	local model = Prop[part]
	model = model and model.Model
	if not model then
		return
	end

	local index = 0
	local search = true
	local colors = {}
	while true do
		local colour = part:GetAttribute("Color" .. index)
		if colour then
			if typeof(colour) == "string" then
				colour = ColorMap[colour]
			end
			colors["Part" .. index] = {
				Color = colour,
				Material = part:GetAttribute("Material" .. index),
			}
			index += 1
		else
			break
		end
	end

	for _, p in pairs(model:GetDescendants()) do
		if p:IsA("BasePart") and colors[p.Name] then
			for prop, value in pairs(colors[p.Name]) do
				p[prop] = value
			end
		end
	end
end

-- Add/Remove

local BaseByModel = {}
function module:AddProp(basePart)
	if not basePart:IsA("BasePart") then
		return
	end

	if Prop[basePart] then
		return
	end

	if script.Parent.ScalableProps:FindFirstChild(basePart.Name) then
		basePart.Transparency = 1

		local module = require(script.Parent.ScalableProps[basePart.Name])
		local function generateModel()
			local generator = setmetatable({
				Base = basePart,
				CFrame = basePart.CFrame,
			}, { __index = module })
			generator:InitModel()
			local model = generator.Model
			if not model:FindFirstChild("Base") then
				local p = Instance.new("Part")
				p.Size = Vector3.new(0.2, 0.2, 0.2)
				p.CFrame = basePart.CFrame
				p.Transparency = 1
				p.Name = "Base"
				p.Parent = model
			end
			for _, p in pairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Archivable = false
				end
			end
			model.Archivable = false
			return model
		end

		local model = generateModel()
		Prop[basePart] = {
			Model = model,
			Events = {
				basePart:GetPropertyChangedSignal("CFrame"):Connect(function()
					self:RepositionProp(basePart)
				end),
				basePart:GetPropertyChangedSignal("Size"):Connect(function()
					Prop[basePart].Model:Destroy()
					local newModel = generateModel()
					Prop[basePart].Model = newModel
					BaseByModel[newModel] = basePart
					newModel.Parent = self.World
					self:RecolorProp(basePart)
				end),
				basePart.AttributeChanged:Connect(function(attribute)
					Prop[basePart].Model:Destroy()
					local newModel = generateModel()
					Prop[basePart].Model = newModel
					BaseByModel[newModel] = basePart
					newModel.Parent = self.World
					self:RecolorProp(basePart)
				end),
			},
		}
		model.Parent = self.World
		BaseByModel[model] = basePart
		self:RepositionProp(basePart)
		self:RecolorProp(basePart)
		return
	end
	
	local leverageMoveProp = basePart.Name == `LeverageMove` and basePart:GetAttribute(`Prop`)
	local modelName = basePart:GetAttribute("AltPropModel") or leverageMoveProp or basePart.Name
	local storedModel = CustomPropsFolder._Value and CustomPropsFolder._Value:FindFirstChild(modelName)
		or ModelFolder._Value and ModelFolder._Value:FindFirstChild(modelName)
	
	local noPropModel = false
	if not storedModel then
		storedModel = NoModelPlaceholder
		noPropModel = true
	else
		basePart.Transparency = 1
	end

	local model = storedModel:Clone()
	model.Archivable = false
	for _, p in pairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Archivable = false
		end
	end
	
	if basePart:GetAttribute("DoubleDoor") and not noPropModel then
		local baseInverse = model.Base.CFrame:Inverse()
		local leftShift = model.Base.CFrame * CFrame.Angles(0, math.pi, 0) * CFrame.new(2.5, 0, 0) * baseInverse
		local rightShift = model.Base.CFrame * CFrame.new(2.5, 0, 0) * baseInverse
		for _, p in pairs(model:GetDescendants()) do
			if p.Name == "Base" or not p:IsA("BasePart") then
				continue
			end
			p.Archivable = true
			local left = p:Clone()
			left.CFrame = leftShift * left.CFrame
			left.Parent = p.Parent
			p.CFrame = rightShift * p.CFrame
			p.Archivable = false
			left.Archivable = false
		end
	end

	Prop[basePart] = {
		Model = model,
		Events = {
			basePart:GetPropertyChangedSignal("CFrame"):Connect(function()
				self:RepositionProp(basePart)
			end),
			basePart.AttributeChanged:Connect(function(attribute)
				model.Parent = self.World
				if attribute == "AltPropModel" or attribute == "DoubleDoor" then
					self:RemoveProp(basePart)
					self:AddProp(basePart)
					return
				end
				self:RecolorProp(basePart)
			end),
			basePart:GetPropertyChangedSignal("Name"):Connect(function()
				model.Parent = self.World
				self:RemoveProp(basePart)
				self:AddProp(basePart)
			end),
		},
	}
	model.Parent = self.World
	BaseByModel[model] = basePart
	self:RepositionProp(basePart)
	self:RecolorProp(basePart)
end

function module:RemoveProp(basePart)
	if basePart:IsA("BasePart") then
		basePart.Transparency = 0.5
	end

	local propData = Prop[basePart]
	if propData then
		BaseByModel[propData.Model] = nil
		propData.Model:Destroy()
		for _, event in pairs(propData.Events) do
			event:Disconnect()
		end
		Prop[basePart] = nil
	end
end

module.OverlaysEnabled = false
module.EnabledState = State(false)

function module:SetEnabled()
	if self.Enabled then
		return
	end
	self.Enabled = true

	if workspace.DebugMission:FindFirstChild("MissionSetup") then
		local missionData = require(workspace.DebugMission.MissionSetup:Clone())
		ColorMap = missionData.Colors or {}
	end

	module.Folder = workspace:FindFirstChild(`PropPreviewModels`) or Instance.new(`Folder`)
	module.Folder.Archivable = false
	module.Folder.Parent = workspace
	module.Folder.Name = `PropPreviewModels`
	module.World = module.Folder:FindFirstChild(`WorldModel`) or Instance.new(`WorldModel`)
	module.World.Archivable = false
	module.World.Parent = module.Folder

	for _, prop in pairs(workspace.DebugMission.Props:GetDescendants()) do
		module:AddProp(prop)
	end

	module.AddEvents = {
		workspace.DebugMission.Props.DescendantAdded:Connect(function(p)
			self:AddProp(p)
		end),
		workspace.DebugMission.Props.DescendantRemoving:Connect(function(p)
			self:RemoveProp(p)
		end),
	}
end

local SearchText = State("")
local SearchResults = Derived(function(text, customProps, modelFolder)
	local list = {}
	if modelFolder then
		for _, item in pairs(modelFolder:GetChildren()) do
			if string.lower(item.Name):match(string.lower(text)) then
				table.insert(list, item.Name)
			end
		end
		if customProps then
			for _, item in customProps:GetChildren() do
				if not modelFolder:FindFirstChild(item.Name) and string.lower(item.Name):match(string.lower(text)) then
					table.insert(list, item.Name)
				end
			end
		end
	end
	return list
end, SearchText, CustomPropsFolder, ModelFolder)

function module:SetDisabled()
	if not self.Enabled then
		return
	end
	self.Enabled = false

	module.Folder:Destroy()

	for _, e in pairs(self.AddEvents) do
		e:Disconnect()
	end
	self.AddEvents = nil

	for propBase in Prop do
		module:RemoveProp(propBase)
	end
end

local function ReplicatedStorageChildrenChanged(child: Instance)
	if not child:IsA("Model") then
		return
	end
	if child.Name == "Assets" then
		UpdateModelFolder()
	end
end

-- Init/Cleanup
module.Init = function(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

	if not module.ReplicatedChildAddedConnection then
		module.ReplicatedChildAddedConnection =
			game.ReplicatedStorage.ChildAdded:Connect(ReplicatedStorageChildrenChanged)
	end

	if not module.ReplicatedChildRemovedConnection then
		module.ReplicatedChildRemovedConnection =
			game.ReplicatedStorage.ChildRemoved:Connect(ReplicatedStorageChildrenChanged)
	end

	UpdateModelFolder()
	if not ModelFolder._Value then
		warn(
			"No Assets folder found! Please read the Quick Start guide found here:\n\thttps://github.com/MoonstoneSkies/InfiltrationEngine-Custom-Missions/blob/main/README.md"
		)
	else
		-- Autogenerate scalable props for insert
		local api = shared.InfilEngine_SerializerAPI
		local validation = game:GetService("CoreGui"):FindFirstChild("InfilEngine_SerializerAPIAvailable")
		if validation and tostring(api) == validation.Value then
			local attributeMap = api:GetAttributesMap()
			for _, scalableProp in script.Parent.ScalableProps:GetChildren() do
				local scalablePropData = require(scalableProp)
				if
					ModelFolder._Value:FindFirstChild(scalableProp.Name)
					or not scalablePropData.DefaultSize
					or not attributeMap[scalableProp.Name]
				then
					continue
				end
				local model = Create(
					"Model",
					{
						Name = scalableProp.Name,
						Archivable = false,
					},
					Create("Part", {
						TopSurface = Enum.SurfaceType.SmoothNoOutlines,
						BottomSurface = Enum.SurfaceType.SmoothNoOutlines,
						Size = scalablePropData.DefaultSize,
						Transparency = 0.5,
						Name = "Base",
					})
				)
				for k, v in attributeMap[scalableProp.Name] do
					model.Base:SetAttribute(k, v[2])
				end
				model.Parent = ModelFolder._Value
			end
		end
	end

	CustomPropsFolder:set(
		workspace:FindFirstChild("DebugMission") and workspace.DebugMission:FindFirstChild("CustomProps") or false
	)

	local searchBox
	searchBox = Create("TextBox", {
		PlaceholderText = "Search For Prop",
		Text = "",
		Size = UDim2.new(0, 300, 0, 30),
		Position = UDim2.new(0, 50, 0, 80),
		BorderSizePixel = 0,
		Changed = function()
			if searchBox then
				SearchText:set(searchBox.Text)
			end
		end,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.5,
	})

	module.UI = Create("ScreenGui", {
		Parent = game:GetService("CoreGui"),
		Archivable = false,
	}, {
		Button({
			Size = UDim2.new(0, 300, 0, 30),
			Enabled = module.EnabledState,
			Position = UDim2.new(0, 50, 0, 50),
			Text = Derived(function(e)
				return e and "Disable Prop Preview" or "Enable Prop Preview"
			end, module.EnabledState),
			Activated = function()
				module.OverlaysEnabled = not module.OverlaysEnabled
				module.EnabledState:set(module.OverlaysEnabled)
				if module.OverlaysEnabled then
					module:SetEnabled()
				else
					module:SetDisabled()
				end
			end,
		}),
		searchBox,
		Create("ScrollingFrame", {
			Size = UDim2.new(0, 300, 0.8, -100),
			Position = UDim2.new(0, 50, 0.9, 0),
			AnchorPoint = Vector2.new(0, 1),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			Create("UIListLayout", {}),
			DerivedTable(function(index, value)
				return Button({
					Text = value,
					Enabled = State(false),
					Activated = function()
						local model = CustomPropsFolder._Value and CustomPropsFolder._Value:FindFirstChild(value)
							or ModelFolder._Value and ModelFolder._Value[value]
						local base = model and model:FindFirstChild("Base")
						if base then
							local prop = base:Clone()
							prop.Name = value
							prop.Transparency = 0.5
							prop.Anchored = true
							prop.Color = Color3.fromRGB(163, 162, 165)
							prop.Material = Enum.Material.Plastic
							prop.Parent = workspace.DebugMission.Props
							prop.CFrame = CFrame.new((workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -5)).Position)
						end
					end,
					Size = UDim2.new(1, 0, 0, 30),
				})
			end, SearchResults),
		}),
	})
end

module.Clean = function()
	if not module.Active then
		return
	end
	module.Active = false

	if module.ReplicatedChildAddedConnection then
		module.ReplicatedChildAddedConnection:Disconnect()
		module.ReplicatedChildAddedConnection = nil
	end

	if module.ReplicatedChildRemovedConnection then
		module.ReplicatedChildRemovedConnection:Disconnect()
		module.ReplicatedChildRemovedConnection = nil
	end

	module.UI:Destroy()
	module.UI = nil
end

return module
