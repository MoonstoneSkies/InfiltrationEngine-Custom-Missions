local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptEditorService = game:GetService("ScriptEditorService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local InternalAPI = require(script.Parent.Parent.API.Internal)
local Write = require(script.Parent.Write)
local StringConversion = require(script.Parent.Parent.StringConversion)
local Read = require(script.Parent.Parent.Reading.Read)
local ReadbackButton = require(script.Parent.ReadbackButton)

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

local function GetMission()
	local mission = workspace:FindFirstChild("DebugMission") or game.ReplicatedStorage:FindFirstChild("DebugMission")
	if not mission then
		error("No mission found: Mission must be named 'DebugMission' and placed in workspace or ReplicatedStorage")
	end

	for _, p in mission:GetChildren() do
		VisibilityToggle.TempReveal(p)
	end

	local missionClone = mission:Clone()
	VisibilityToggle.HideTempRevealedParts(mission)

	InternalAPI.InvokeHook("PreSerialize", missionClone)
	InternalAPI.InvokeHook("PreSerializeMissionSetup", missionClone:FindFirstChild("MissionSetup"))

	return missionClone
end

local function GetMissionCode()
	local mission = GetMission()
	local code = Write.Mission(mission)
	mission:Destroy()
	return code
end

local function GetMapId()
	return math.random(0, StringConversion.GetMaxNumber(2))
end

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
		local mapId = GetMapId() -- A 2 character integer that can be used to identify maps
		while first < #code do
			local header = Write.MissionCodeHeader(mapId, currentPaste, maxPastes)
			codeChunks[#codeChunks + 1] = header .. code:sub(first, current)
			first += PASTE_SIZE
			current += PASTE_SIZE
			currentPaste += 1
		end
		return codeChunks
	end, CodeState)

	local allEnabled 		= workspace:GetAttribute("SerializerEnableAllFeatures")
	local apiDevEnabled 	= allEnabled or workspace:GetAttribute("APIDev")
	local gistEnabled 		= allEnabled or workspace:GetAttribute("ReadDocs")
	local readbackEnabled 	= allEnabled or workspace:GetAttribute("Readback")

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
				local code = GetMissionCode()

				if not workspace:FindFirstChild("DebugMission") then
					local model = Read.Mission(code, 1)
					model.Parent = workspace
				end
				CodeState:set(code)
			end,
		}),
		if gistEnabled
			then Button({
				Size = UDim2.new(0, 200, 0, 30),
				Enabled = module.EnabledState,
				Position = UDim2.new(0, 270, 0, 50),
				Text = "Gist Code",
				Activated = function()
					local code = GetMissionCode()

					if not workspace:FindFirstChild("DebugMission") then
						local model = Read.Mission(code, 1)
						model.Parent = workspace
					end

					local output = Write.MissionCodeHeader(GetMapId(), 1, 1)
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
		if readbackEnabled
			then ReadbackButton(module.EnabledState)
			else nil,
		if apiDevEnabled
			then
			Button({
				Size = UDim2.new(0, 200, 0, 30),
				Enabled = module.EnabledState,
				Position = UDim2.new(0, 50, 1, -50),
				AnchorPoint = Vector2.new(0, 1),
				Text = "Preserialize Preview",
				Activated = function()
					local preprocessed = GetMission()
					preprocessed.Name = `{preprocessed.Name}_Preserialized`
					preprocessed.Parent = workspace
				end,
			})
			else nil,
		Create("ScrollingFrame", {
			Size = UDim2.new(0, 200, 1, apiDevEnabled and -180 or -130),
			Position = UDim2.new(0, 50, 0, 80),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
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
