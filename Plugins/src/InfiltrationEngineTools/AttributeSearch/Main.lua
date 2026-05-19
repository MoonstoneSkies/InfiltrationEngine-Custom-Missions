local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable
local OnChange = Actor.OnChange
local Watch = Actor.Watch

local module = {}

local ROW_HEIGHT = 20

local SEARCH_TERM_MATCH_PATTERN = "[%w%.]+"

local SearchText = State("")
local SearchSubStrings = Derived(function(text)
	local substrings = {}
	for s in text:gmatch(SEARCH_TERM_MATCH_PATTERN) do
		substrings[s] = true
	end
	table.sort(substrings)
	return substrings
end, SearchText)
local SearchResults = Derived(function(text)
	if #text < 3 or not workspace:FindFirstChild("DebugMission") then
		return {}
	end
	local results = {}

	local substrings = {}
	for s in text:lower():gmatch(SEARCH_TERM_MATCH_PATTERN) do
		substrings[s] = true
	end
	local function hasSubstringMatch(target)
		for substring in substrings do
			if target:match(substring) then
				return true
			end
		end
		return false
	end

	local missionModule = require(workspace.DebugMission.MissionSetup:Clone())
	local match = {}

	local function searchTable(prefix, tbl)
		for field, value in tbl do
			if value == "" then
				continue
			end
			if typeof(value) == "string" then
				if
					(typeof(field) == "string" and hasSubstringMatch(field:lower()))
					or hasSubstringMatch(value:lower())
				then
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
			if v ~= "" and hasSubstringMatch(k:lower()) or typeof(v) == "string" and hasSubstringMatch(v:lower()) then
				match[k] = tostring(v)
			end
		end

		if next(match) then
			results[instance] = match
			match = {}
		end
	end

	if text:lower() == "powerarea" then
		local areaList = {}
		for instance in results do
			local area = instance:GetAttribute("PowerArea")
			if not area then
				continue
			end
			areaList[area] = (areaList[area] or 0) + 1
		end
		if next(areaList) then
			print("--- POWER AREAS ---")
			for k, v in areaList do
				print(`{k}: {v}`)
			end
			print("-------------------")
		end
	end

	return results
end, SearchText)

local function StringToColor(name)
	if name == "Default" then
		return Color3.new(0, 0, 0)
	end

	local h = 5 ^ 7
	local n = 0
	for i = 1, #name do
		n = (n * 257 + string.byte(name, i, i)) % h
	end
	local color = Color3.fromHSV((n % 1000) / 1000, 0.3, 1)
	return color
end

module.PropMarkers = {}
local function ClearPropMarkers()
	for _, p in module.PropMarkers do
		p:Destroy()
	end
	module.PropMarkers = {}
end
local function UpdatePropMarkers(list)
	ClearPropMarkers()
	for k, v in list do
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
						BackgroundColor3 = StringToColor(next(v) and v[next(v)] or ""),
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
	module.PluginOpen = true
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
					SearchText:set(searchBox.Text)
				end
			end)
		end,
		FocusLost = function()
			SearchText:set(searchBox.Text)
		end,
	})

	local pinButton
	pinButton = Create("TextButton", {
		Text = "Pin",
		Size = UDim2.new(0, 100, 0, ROW_HEIGHT),
		BackgroundTransparency = 0,
		Position = UDim2.new(0, 320, 0, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = Color3.new(0, 0, 0),
		Activated = function()
			module.KeepPinned = not module.KeepPinned
			pinButton.Text = module.KeepPinned and "Unpin" or "Pin"
			if not module.KeepPinned and not module.PluginOpen then
				module.Clean()
			end
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
			Create("TextButton", {
				Text = "Clear",
				Size = UDim2.new(0, 100, 0, ROW_HEIGHT),
				BackgroundTransparency = 0,
				Position = UDim2.new(0, 210, 0, 0),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
				TextColor3 = Color3.new(0, 0, 0),
				Activated = function()
					SearchText:set("")
				end,
			}),
			pinButton,
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

			Create("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -ROW_HEIGHT, 1, ROW_HEIGHT * -2),
				Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
				BackgroundTransparency = 1,
			}, {
				Create("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					Padding = UDim.new(0, 8),
				}),
				DerivedTable(function(k, v)
					return Create("TextButton", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.new(0, 0, 0),
						TextColor3 = Color3.new(1, 1, 1),
						Text = k,
						Activated = function()
							SearchText:set(k)
						end,
					})
				end, SearchSubStrings),
			}),

			Create("TextButton", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -ROW_HEIGHT, 1, 0),
				Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
				BackgroundColor3 = Color3.new(1, 1, 1),
				TextColor3 = Color3.new(0, 0, 0),
				Text = "Find Links",
				Activated = function()
					local added = {}
					local variableList = {}
					local instances = game.Selection:Get()
					for _, p in instances do
						local attributes = p:GetAttributes()
						for k, v in attributes do
							if k == "PowerArea" then
								continue
							end
							if typeof(v) ~= "string" then
								continue
							end
							if v == "" or v == "1" or v == "0" then
								continue
							end
							for sub in v:gmatch(SEARCH_TERM_MATCH_PATTERN) do
								if added[sub] or #sub < 3 then
									continue
								end
								table.insert(variableList, sub)
								added[sub] = true
							end
						end
					end
					table.sort(variableList)
					SearchText:set(table.concat(variableList, " || "))
				end,
			}),
		}),
	})
end

function module.Clean()
	module.PluginOpen = false
	if module.KeepPinned then
		return
	end
	module.Active = false
	ClearPropMarkers()
	if module.UI then
		module.UI:Destroy()
		module.UI = nil
	end
end

return module
