local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable
local OnChange = Actor.OnChange
local Watch = Actor.Watch

local module = {}

local ROW_HEIGHT = 20

local SearchText = State("")
local SearchResults = Derived(function(text)
	if #text < 3 or not workspace:FindFirstChild("DebugMission") then
		return {}
	end
	local results = {}

	local missionModule = require(workspace.DebugMission.MissionSetup:Clone())
	local match = {}

	local function searchTable(prefix, tbl)
		for field, value in tbl do
			if value == "" then
				continue
			end
			if typeof(value) == "string" then
				if (typeof(field) == "string" and field:lower():match(text)) or value:lower():match(text) then
					local entry = if prefix then `{prefix}.{field}` else field
					match[entry] = value
				end
			elseif typeof(value) == "table" then
				local entry = if prefix then `{prefix}.{field}` else field
				searchTable(entry, value)
			end
		end
	end
	searchTable(nil, missionModule)

	if next(match) then
		results[workspace.DebugMission.MissionSetup] = match
		match = {}
	end

	for _, instance in workspace.DebugMission:GetDescendants() do
		local attributes = instance:GetAttributes()
		if not next(attributes) then
			continue
		end

		for k, v in attributes do
			if v ~= "" and k:lower() == text or typeof(v) == "string" and v:lower():match(text) then
				match[k] = tostring(v)
			end
		end

		if next(match) then
			results[instance] = match
			match = {}
		end
	end
	return results
end, SearchText)

module.PropMarkers = {}
local function ClearPropMarkers()
	for _, p in module.PropMarkers do
		p:Destroy()
	end
	module.PropMarkers = {}
end
local function UpdatePropMarkers(list)
	ClearPropMarkers()
	for k in list do
		if k:IsA("BasePart") then
			table.insert(
				module.PropMarkers,
				Create("BillboardGui", {
					Archivable = false,
					Parent = game:GetService("CoreGui"),
					Adornee = k,
					Size = UDim2.new(0, 20, 0, 20),
					AlwaysOnTop = true,
				}, {
					Create("Frame", {
						Size = UDim2.new(0, 20, 0, 20),
						BorderSizePixel = 0,
						BackgroundColor3 = Color3.new(1, 1, 1),
					}, {
						Create("UICorner", {
							CornerRadius = UDim.new(0.5, 0),
						}),
					}),
				})
			)
		end
	end
end
Watch(UpdatePropMarkers, SearchResults)

local function ListEntry(instance, fields)
	local fieldCount = 0
	local contents = {
		Create("TextLabel", {
			Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
			Position = UDim2.new(0, 0, 0, 0),
			Text = instance.Name,
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
		}),
	}

	for k, v in fields do
		table.insert(
			contents,
			Create(
				"TextLabel",
				{
					Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
					Position = UDim2.new(0, 200, 0, ROW_HEIGHT * fieldCount),
					Text = k,
					TextXAlignment = Enum.TextXAlignment.Right,
					BackgroundTransparency = 1,
					TextColor3 = Color3.new(1, 1, 1),
				},
				Create("UIPadding", {
					PaddingRight = UDim.new(0, 10),
				})
			)
		)
		table.insert(
			contents,
			Create("TextLabel", {
				Size = UDim2.new(0, 0, 0, ROW_HEIGHT),
				Position = UDim2.new(0, 400, 0, ROW_HEIGHT * fieldCount),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = tostring(v):gsub("\n", "   "),
				BackgroundTransparency = 0.6,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				BorderSizePixel = 0,
			}, {
				Create("UIPadding", {
					PaddingRight = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
				}),
			})
		)
		fieldCount += 1
	end

	local layoutOrder = 0
	if instance.Name ~= "MissionSetup" then
		layoutOrder = 1000 * string.byte(instance.Name:lower(), 1, 1) + string.byte(instance.Name:lower(), 2, 2)
	end

	return Create("TextButton", {
		Size = UDim2.new(0, 400, 0, fieldCount * ROW_HEIGHT),
		Text = "",
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Activated = function()
			game.Selection:Set({ instance })
		end,
	}, contents)
end

local lastTextChange = 0
function module.Init(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true
	UpdatePropMarkers(SearchResults._Value)

	local searchBox
	searchBox = Create("TextBox", {
		Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
		PlaceholderText = "Search Attribute",
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(),
		PlaceholderColor3 = Color3.new(0.8, 0.8, 0.8),
		TextColor3 = Color3.new(1, 1, 1),
		Text = SearchText._Value,
		ClearTextOnFocus = false,
		[OnChange("Text")] = function()
			lastTextChange += 1
			local clock = lastTextChange
			task.delay(1, function()
				if clock == lastTextChange then
					SearchText:set(searchBox.Text:lower())
				end
			end)
		end,
		FocusLost = function()
			SearchText:set(searchBox.Text)
		end,
	})

	module.UI = Create("ScreenGui", {
		Parent = game.CoreGui,
		Archivable = false,
	}, {
		Create("Frame", {
			Size = UDim2.new(1, -100, 1, -100),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			searchBox,
			Create("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -ROW_HEIGHT * 1.5),
				Position = UDim2.new(0, 0, 1, 0),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, {
				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				DerivedTable(ListEntry, SearchResults),
			}),
		}),
	})
end

function module.Clean()
	module.Active = false
	ClearPropMarkers()
	if module.UI then
		module.UI:Destroy()
		module.UI = nil
	end
end

return module
