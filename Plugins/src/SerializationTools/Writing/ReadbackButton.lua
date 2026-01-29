local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)
local HttpService = game:GetService("HttpService")

local Read = require(script.Parent.Parent.Reading.Read)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived


local URL_ELEM               = "[^/]+"

local HTTPS_BASE             = "^https?://"

local GIST_NONRAW_BASE       = HTTPS_BASE .. `gist%.github%.com`
local GIST_NONRAW_INFO_PAT   = `{GIST_NONRAW_BASE}/({URL_ELEM})/({URL_ELEM})`

local GIST_URL_BASE          = HTTPS_BASE .. "gist%.githubusercontent%.com"
local GIST_INFO_PAT_NO_NAME  = `{GIST_URL_BASE}/({URL_ELEM})/{URL_ELEM}/raw`
local GIST_INFO_PAT_FILENAME = `{GIST_URL_BASE}/({URL_ELEM})/{URL_ELEM}/raw/{URL_ELEM}/({URL_ELEM})`

local textboxDefaults = {
	Font = Enum.Font.SciFi,
	Text = "",
	
	TextSize = 20,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = Color3.new(1, 1, 1),

	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
}
local function createTextbox(props, children, autoCleanup)
	for k, v in pairs(textboxDefaults) do
		if props[k] ~= nil then continue end
		props[k] = v
	end
	return Create("TextBox", props, children, autoCleanup)
end

local function trimWhitespace(str)
	return str:gsub("^%s*", ""):gsub("%s*$", "")
end

local function gistLinkToRaw(link)
	if not string.match(link, GIST_NONRAW_BASE) then return link end
	local user, hash = link:match(GIST_NONRAW_INFO_PAT)
	return `https://gist.githubusercontent.com/{user}/{hash}/raw`
end

local function gistLinkToMissionCode(link)
	link = trimWhitespace(link)
	link = gistLinkToRaw(link)
	
	local creator, fileName = string.match(link, GIST_INFO_PAT_FILENAME)
	if creator == nil then
		creator = string.match(link, GIST_INFO_PAT_NO_NAME)
	end
	
	if creator == nil then
		warn(`Invalid link info:\n\tLink: {link}\n\tMatch Info:`, string.match(link, GIST_INFO_PAT_FILENAME), "/", string.match(link, GIST_INFO_PAT_NO_NAME))
		return false, "Invalid Gist Link"
	end
	
	print(`Reading back map "{link}"...`)
	print(`Map author: {creator}`)
	if fileName then
		print(`Map filename: {fileName}`)
	end
	
	local success, gistCode = pcall(HttpService.GetAsync, HttpService, link)
	return success, gistCode
end

local function createReadbackBox(enabledState)
	local readbackState = {}
	local readStatusState = State({0, 0})
	local readErrState = State("")

	local function resetReadbackState()
		readbackState.MapInfo = { CodeVersion = -1 }
		readbackState.Codes = {}
		readbackState.Received = {}
		readStatusState:set({0, 0})
		readErrState:set("")
	end
	resetReadbackState()

	local codeInput = createTextbox(
		{
			Enabled = enabledState,
			Size = UDim2.new(1, -30, 0, 30),
			Position = UDim2.fromScale(0, 0),
			
			PlaceholderText = "Input Code"
		}
	)

	codeInput.FocusLost:Connect(function(enterPressed, _)
		if not enterPressed then return end
		local inputText = codeInput.Text
		if codeInput.Text:match(HTTPS_BASE) ~= nil then
			local success, missionCode = gistLinkToMissionCode(inputText)
			if not success then
				readErrState:set(missionCode)
				return
			end
			inputText = missionCode
		end

		local inputNoComment = inputText
		if inputText:match("^!!!") ~= nil then
			inputNoComment = inputText:match("!!!.-!!!(.+)")
			if inputNoComment == nil then
				readErrState:set("Invalid Opening Comment")
				return
			end
		end

		local inputHeader, cursor = Read.MissionCodeHeader(inputNoComment, 1)
		local inputContent = string.sub(inputNoComment, cursor)

		local existingMapInfo = readbackState.MapInfo
		if existingMapInfo.CodeVersion == -1 then
			readbackState.MapInfo.CodeVersion = inputHeader.CodeVersion
			readbackState.MapInfo.CodeTotal = inputHeader.CodeTotal
			readbackState.MapInfo.MapId = inputHeader.MapId
		end

		codeInput.Text = ""
		if existingMapInfo.CodeVersion ~= inputHeader.CodeVersion then
			readErrState:set("Code Version Mismatch")
			return
		elseif existingMapInfo.MapId ~= inputHeader.MapId then
			readErrState:set("Map ID Mismatch")
			return
		elseif existingMapInfo.CodeTotal ~= inputHeader.CodeTotal then
			readErrState:set("Code Count Mismatch")
			return
		end

		readbackState.Codes[inputHeader.CodeCurrent] = inputContent
		readbackState.Received[inputHeader.CodeCurrent] = true
		readErrState:set("")

		local allReceived = true
		local receivedCount = 0
		for i=1, readbackState.MapInfo.CodeTotal do
			if readbackState.Received[i] then receivedCount = receivedCount + 1 end
			allReceived = allReceived and readbackState.Received[i]
		end

		readStatusState:set({ receivedCount, readbackState.MapInfo.CodeTotal })

		if not allReceived then return end
		local finalCode = ""
		for codePart, codeContent in ipairs(readbackState.Codes) do
			finalCode = finalCode .. codeContent
		end
		
		local success, errReason = VersionConfig:change_version(readbackState.MapInfo.CodeVersion)
		if not success then
			readErrState:set(errReason)
			VersionConfig:change_version(VersionConfig.LatestVersion)
			return
		end
		
		local success, mission = pcall(Read.Mission, finalCode, 1)
		VersionConfig:change_version(VersionConfig.LatestVersion)
		
		if not success then error(mission) end
		
		mission.Parent = workspace
		resetReadbackState()
	end)

	local resetState = Create(
		"ImageButton",
		{
			Image = "rbxassetid://89515271880693",
			Size = UDim2.fromOffset(30, 30),
			Enabled = enabledState,
			Position = UDim2.new(1, -30, 0, 0),
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Activated = function()
				codeInput:ReleaseFocus()
				codeInput.Text = ""
				resetReadbackState()
			end,
		}
	)

	local errLabel = Create(
		"TextLabel",
		{
			Enabled = enabledState,
			
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 30),
			
			Font = Enum.Font.SciFi,
			TextColor3 = Color3.fromRGB(209, 77, 79),
			TextSize = 20,
			TextScaled = true,
			
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			
			Text = Derived(function(errmsg)
				return errmsg
			end, readErrState),
			
			Visible = Derived(function(errmsg)
				return #errmsg ~= 0
			end, readErrState)
		}
	)

	local statusLabel = Create(
		"TextLabel",
		{
			Enabled = enabledState,
			
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 30),
			
			Font = Enum.Font.SciFi,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 20,
			
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			
			Text = Derived(function(tbl)
				return "Import Status: " .. tostring(tbl[1]) .. '/' .. tostring(tbl[2])
			end, readStatusState),
			
			Visible = Derived(function(tbl, errmsg)
				if #errmsg ~= 0 then return false end
				return tbl[1] ~= tbl[2]
			end, readStatusState, readErrState)
		}
	)

	local readPanel = Create(
		"Frame",
		{
			Size = UDim2.new(0, 200, 0, 60),
			Enabled = enabledState,
			Position = UDim2.new(1, -50, 0, 50),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
		},
		{
			codeInput,
			resetState,
			errLabel,
			statusLabel,
		}
	)

	return readPanel
end

return createReadbackBox