local ScriptEditorService = game:GetService("ScriptEditorService")

local InternalAPI = require(script.Parent.Parent.API.Internal)
local Write = require(script.Parent.Write)
local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local Read = require(script.Parent.Parent.Reading.Read)

local ReadbackButton = require(script.Parent.ReadbackButton)
local NotifMan = require(script.Parent.Parent.Util.Notifications.Manager)

local Button = require(script.Parent.Parent.Util.Button)
local FeatureCheck = require(script.Parent.Parent.Util.FeatureCheck)
local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)
local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable

local MAX_PASTE_SIZE = 199999
local PASTE_INFO_SIZE = 7
local PASTE_SIZE = MAX_PASTE_SIZE - PASTE_INFO_SIZE

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

local function GetMissionSetting(missionRoot, settingName, settingType, defaultValue)
	if not missionRoot:FindFirstChild("CustomMissionSettings") then
		local settings = Instance.new("BoolValue")
		settings.Name = "CustomMissionSettings"
		settings.Parent = missionRoot
	end
	if not missionRoot.CustomMissionSettings:FindFirstChild(settingName) then
		local setting = Instance.new(settingType)
		setting.Name = settingName
		if defaultValue ~= nil then
			setting.Value = defaultValue
		end
		setting.Parent = missionRoot.CustomMissionSettings
	end
	return missionRoot.CustomMissionSettings[settingName]
end

local function SetMissionSetting(missionRoot, settingName, settingType, to)
	GetMissionSetting(missionRoot, settingName, settingType, nil).Value = to
end

local function InitCustomMissionSettings(incrementVersionNumber)
	local mission = workspace:FindFirstChild("DebugMission") or game.ReplicatedStorage:FindFirstChild("DebugMission")
	if not mission then
		error("No mission found: Mission must be named 'DebugMission' and placed in workspace or ReplicatedStorage")
	end

	GetMissionSetting(mission, "EnforceCellLinks", "BoolValue", true)
	
	local oldVersionValue = mission.CustomMissionSettings:FindFirstChild("ExportVersion")
	if oldVersionValue ~= nil then
		local newVersionValue = mission.CustomMissionSettings:FindFirstChild("MissionVersion")
		if newVersionValue ~= nil then
			oldVersionValue:Destroy()
		else
			warn("Renaming CustomMissionSettings.ExportVersion -> CustomMissionSettings.MissionVersion")
			oldVersionValue.Name = "MissionVersion"
		end
	end
	
	local versionNumber = GetMissionSetting(mission, "MissionVersion", "StringValue", "0")
	if incrementVersionNumber then
		local front, minorVersion = versionNumber.Value:match("^(.-)(%d+)$")
		if not (minorVersion and tonumber(minorVersion)) then
			front = ""
			minorVersion = "0"
		end
		versionNumber.Value = `{front}{tonumber(minorVersion) + 1}`
	end
	GetMissionSetting(mission, "MissionName", "StringValue", "")
	GetMissionSetting(mission, "MissionDesc", "StringValue", "")
	GetMissionSetting(mission, "AuthorName", "StringValue", "")
	local distro = GetMissionSetting(mission, "ExporterDistribution", "StringValue", VersionConfig.Distribution).Value
	local version = tonumber(GetMissionSetting(mission, "ExporterVersion", "StringValue", tostring(VersionConfig.VersionNumber)).Value)
	
	if distro ~= VersionConfig.Distribution then
		if VersionConfig.OfficialDistro then
			warn("Exporter Distribution Mismatch!")
			warn(`Current Exporter is "{VersionConfig.Distribution}", this mission was developed using "{distro}"`)
			warn("Beware of the potential for undesirable behaviour!")
		else
			warn("Exporter Distribution Management")
			warn("Detected you have began using an unofficial exporter version - updating CustomMissionSettings")
			SetMissionSetting(mission, "ExporterDistribution", "StringValue", VersionConfig.Distribution)
		end
	end
	
	if version ~= VersionConfig.VersionNumber then
		warn("Exporter Version Mismatch!")
		warn(`Current Exporter is v{VersionConfig.VersionNumber}, this mission was developed on v{version}`)
		warn("Double-check there's nothing unexpected")
		warn(`If everything works fine, set the ExporterVersion in CustomMissionSettings to "{VersionConfig.VersionNumber}" to silence this warning`)
	end

	return mission.CustomMissionSettings
end

local function GetMissionComment(customSettings)
	local linkWarn = customSettings.EnforceCellLinks.Value and "EnforceCellLinks is disabled on this map\nThis mission is ineligible to be featured in the community missions tab\n" or ""
	
	return table.concat({
		"!!!\n",
		linkWarn,
		"How to play custom missions:\n",
		`1) Join the game and find "Custom Mission" in the mission menu`,
		`2) Start a custom mission lobby`,
		`3) Go to the table and open the custom mission loader`,
		`4) Copy the URL of this page into the box and hit enter. It will NOT work if you copy the contents of this page instead of the URL.\n`,
		`Mission Name: {customSettings.MissionName.Value}`,
		`Author(s): {customSettings.AuthorName.Value}`,
		`Mission Version: {customSettings.MissionVersion.Value}`,
		`Mission Briefing: {customSettings.MissionDesc.Value}`,
		`ExporterID: {customSettings.ExporterDistribution.Value}_v{customSettings.ExporterVersion.Value}\n`,
		"!!!"
	}, '\n')
end

local function GetMissionCode()
	local exportVersion = FeatureCheck("SerializerExportVersion", false)
	local exportVersionSet = exportVersion ~= nil
	
	if exportVersion == nil then exportVersion = VersionConfig.LatestVersion end
	
	if type(exportVersion) ~= "number" then
		warn("SerializerExportVersion must be an integer or nil!")
	end
	
	if exportVersionSet then
		warn("SerializerExportVersion is intended for debugging backwards compatibility, do not rely on it for real mission development!")
	end
	
	local success, wmsg = VersionConfig:change_version(exportVersion)
	if not success then
		warn("SerializerExportVersion - " .. wmsg)
		VersionConfig:change_version(VersionConfig.LatestVersion)
	end
	
	local mission = GetMission()
	local code = Write.Mission(mission)
	mission:Destroy()
	
	if not workspace:FindFirstChild("DebugMission") then
		local model = Read.Mission(code, 1)
		model.Parent = workspace
	end
	
	VersionConfig:change_version(VersionConfig.LatestVersion)
	return code
end

local function GenerateMapId()
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
		local mapId = GenerateMapId() -- A 2 character integer that can be used to identify maps
		while first < #code do
			local header = Write.MissionCodeHeader(mapId, currentPaste, maxPastes)
			codeChunks[#codeChunks + 1] = header .. code:sub(first, current)
			first += PASTE_SIZE
			current += PASTE_SIZE
			currentPaste += 1
		end
		return codeChunks
	end, CodeState)

	local notifDisabled	= FeatureCheck("SerializerNotifsDisabled", false) == true
	local apiDevEnabled = FeatureCheck("APIDev") == true
	local gistEnabled = FeatureCheck("ReadDocs") == true
	local readbackEnabled = FeatureCheck("Readback") == true

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
				InitCustomMissionSettings(false)
				local code = GetMissionCode()
				if code == nil then return end

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
					local customSettings = InitCustomMissionSettings(true)
					local code = GetMissionCode()
					if code == nil then return end

					local output = Write.MissionCodeHeader(GenerateMapId(), 1, 1)
					output = output .. code
					output = GetMissionComment(customSettings)
						.. output

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
		if readbackEnabled then ReadbackButton(module.EnabledState) else nil,
		if apiDevEnabled
			then Button({
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
		if not notifDisabled
			then NotifMan.Init()
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
	NotifMan.Clean()

	if module.UI then
		module.UI:Destroy()
		module.UI = nil
	end
end

return module
