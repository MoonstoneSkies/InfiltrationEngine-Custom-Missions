local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptEditorService = game:GetService("ScriptEditorService")
local UserInputService = game:GetService("UserInputService")
local Write = require(script.Parent.Write)
local StringConversion = require(script.Parent.Parent.StringConversion)
local Read = require(script.Parent.Parent.Reading.Read)

local Button = require(script.Parent.Parent.Util.Button)
local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)
local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable

local MAX_PASTE_SIZE = 199999
local PASTE_INFO_SIZE = 7
local PASTE_SIZE = MAX_PASTE_SIZE - PASTE_INFO_SIZE

local VERSION_NUMBER = VersionConfig.VersionNumber

local GIST_PREFIX = [[!!! 
How to play custom missions:

1) Join the game and find "Custom Mission" in the mission menu
2) Start a custom mission lobby
3) Go to the table and open the custom mission loader
4) Copy the URL of this page into the box and hit enter. It will NOT work if you copy the contents of this page instead of the URL.

Mission Name:
Creator:
Version:
Briefing:

!!!]]

local module = {}

module.Init = function(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

	local CodeState = State("")
	local Pastes = State({})

	Pastes = Derived(function(code)
		local codeChunks = {}
		local first = 1
		local current = PASTE_SIZE -- leaving space for paste information
		local currentPaste = 1
		local maxPastes = math.ceil(#code / current)
		local mapId = math.random(1, StringConversion.GetMaxNumber(2)) -- A 3 character integer that can be used to identify maps
		while first < #code do
			local prePaste = ""
			prePaste = StringConversion.NumberToString(VERSION_NUMBER, 1)
			prePaste = prePaste .. Write.ShortInt(mapId)
			prePaste = prePaste .. Write.ShortInt(currentPaste)
			prePaste = prePaste .. Write.ShortInt(maxPastes)
			codeChunks[#codeChunks + 1] = prePaste .. code:sub(first, current)
			first += PASTE_SIZE
			current += PASTE_SIZE
			currentPaste += 1
		end
		return codeChunks
	end, CodeState)

	module.UI = Create("ScreenGui", {
		Parent = game:GetService("CoreGui"),
		Archivable = false,
	}, {
		Button({
			Size = UDim2.new(0, 200, 0, 30),
			Enabled = module.EnabledState,
			Position = UDim2.new(0, 50, 0, 50),
			Text = "Generate Code",
			Activated = function()
				local mission = workspace:FindFirstChild("DebugMission")
					or game.ReplicatedStorage:FindFirstChild("DebugMission")
				if not mission then
					error(
						"No mission found: Mission must be named 'DebugMission' and placed in workspace or ReplicatedStorage"
					)
				end
				for _, p in mission:GetChildren() do
					VisibilityToggle.TempReveal(p)
				end
				local code = Write.Mission(mission)
				VisibilityToggle.HideTempRevealedParts(mission)

				if not workspace:FindFirstChild("DebugMission") then
					local model = Read.Mission(code, 1)
					model.Parent = workspace
				end
				CodeState:set(code)
			end,
		}),
		if workspace:GetAttribute("ReadDocs")
			then Button({
				Size = UDim2.new(0, 200, 0, 30),
				Enabled = module.EnabledState,
				Position = UDim2.new(0, 270, 0, 50),
				Text = "Gist Code",
				Activated = function()
					local mission = workspace:FindFirstChild("DebugMission")
						or game.ReplicatedStorage:FindFirstChild("DebugMission")
					if not mission then
						error(
							"No mission found: Mission must be named 'DebugMission' and placed in workspace or ReplicatedStorage"
						)
					end
					for _, p in mission:GetChildren() do
						VisibilityToggle.TempReveal(p)
					end
					local code = Write.Mission(mission)
					VisibilityToggle.HideTempRevealedParts(mission)

					if not workspace:FindFirstChild("DebugMission") then
						local model = Read.Mission(code, 1)
						model.Parent = workspace
					end

					local output = ""
					output = StringConversion.NumberToString(VERSION_NUMBER, 1)
					output = output .. Write.ShortInt(math.random(1, 100))
					output = output .. Write.ShortInt(1)
					output = output .. Write.ShortInt(1)
					output = output .. code
					output = GIST_PREFIX .. output

					if workspace:FindFirstChild("CustomMissionCode") then
						workspace.CustomMissionCode:Destroy()
					end

					local s = Instance.new("Script")
					s.Name = "CustomMissionCode"
					ScriptEditorService:UpdateSourceAsync(s, function()
						return output
					end)
					s.Parent = workspace
					ScriptEditorService:OpenScriptDocumentAsync(s)
				end,
			})
			else nil,
		Create("ScrollingFrame", {
			Size = UDim2.new(0, 200, 1, -150),
			Position = UDim2.new(0, 50, 1, -50),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			Visible = Derived(function(code)
				if code == "" then
					return false
				else
					return true
				end
			end, CodeState),
			CanvasSize = Derived(function(code)
				return UDim2.new(0, 180, 0, 34 * (math.ceil(#code / PASTE_SIZE)))
			end, CodeState),
		}, {
			DerivedTable(function(index, value)
				local textBox = Create("TextBox", {
					ClearTextOnFocus = false,
					Size = UDim2.new(0, 80, 0, 20),
					Position = UDim2.new(0, 10, 0, 5),
					TextEditable = false,
					TextScaled = false,
					TextSize = 10,
					ClipsDescendants = true,
					TextWrapped = false,
					BackgroundTransparency = 1,
					TextColor3 = Color3.new(255, 255, 255),
					BorderSizePixel = 5,
					Text = value,
				})

				local selector = Create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 200, 0, 50),
					Position = UDim2.new(0, 0, 0, (index - 1) * 34 + 4),
				}, {
					textBox,
					Create("TextButton", {
						Size = UDim2.new(0, 90, 0, 20),
						Position = UDim2.new(0, 100, 0, 5),
						Text = "Select " .. tostring(index),
						FontFace = Font.fromEnum(Enum.Font.SciFi),
						BackgroundColor3 = Color3.new(255, 255, 255),
						BorderColor3 = Color3.new(0, 0, 0),
						TextScaled = false,
						TextSize = 14,
						TextStrokeColor3 = Color3.new(0, 0, 0),
						BorderSizePixel = 0,
						Activated = function()
							textBox:CaptureFocus()
							textBox.SelectionStart = 0
							textBox.CursorPosition = #value + 1
						end,
					}),
				})
				return selector
			end, Pastes),
		}),
	})
end

module.Clean = function()
	if not module.Active then
		return
	end
	module.Active = false

	module.UI:Destroy()
	module.UI = nil
end

return module
