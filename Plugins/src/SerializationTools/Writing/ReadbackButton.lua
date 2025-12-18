local HttpService = game:GetService("HttpService")

local Read = require(script.Parent.Parent.Reading.Read)

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived

local function GistLinkToMissionCode(link)
	link = string.gsub(link, "^%s*(https://gist%.githubusercontent%.com/[^/]+/[^/]+/raw/[^/]+/[%w%.]+)%s*$", function(s) return s end)
	local creator, fileName = string.match(link, "^%s*https://gist%.githubusercontent%.com/([^/]+)/[^/]+/raw/[^/]+/([%w%.]+)%s*$")
	if creator == nil or fileName == nil then return false, "Invalid Gist Link" end

	local success, gistCode = pcall(HttpService.GetAsync, HttpService, link)
	return success, gistCode
end

local function CreateReadbackBox(enabledState)
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

	local codeInput = Create(
		"TextBox",
		{
			Size = UDim2.new(1, -30, 0.5, 0),
			Enabled = enabledState,
			Position = UDim2.new(0, 0, 0, 0),
			Text = "",
			TextTruncate = Enum.TextTruncate.AtEnd,
			PlaceholderText = "Input Code",
			TextColor3 = Color3.new(255, 255, 255),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			TextSize = 20,
			Font = Enum.Font.SciFi,
		}
	)

	codeInput.FocusLost:Connect(function(enterPressed, _)
		if not enterPressed then return end
		local inputText = codeInput.Text
		if codeInput.Text:match("^https://") ~= nil then
			local success, missionCode = GistLinkToMissionCode(inputText)
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
		codeInput.Text = ""

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

		local mission = Read.Mission(finalCode, 1)
		mission.Parent = workspace
		resetReadbackState()
	end)

	local resetState = Create(
		"ImageButton",
		{
			Image = "rbxassetid://89515271880693",
			Size = UDim2.new(0, 30, .5, 0),
			Enabled = enabledState,
			Position = UDim2.new(1, -30, 0, 0),
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Activated = function()
				codeInput:ReleaseFocus()
				codeInput.Text = ""
				readErrState:set("")
				resetReadbackState()
			end,
		}
	)

	local errLabel = Create(
		"TextLabel",
		{
			Size = UDim2.new(1, 0, 0.5, 0),
			Enabled = enabledState,
			Position = UDim2.new(0, 0, 0.5, 0),
			TextColor3 = Color3.fromRGB(209, 77, 79),
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			TextSize = 20,
			TextScaled = true,
			Font = Enum.Font.SciFi,
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
			Size = UDim2.new(1, 0, 0.5, 0),
			Enabled = enabledState,
			Position = UDim2.new(0, 0, 0.5, 0),
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			TextSize = 20,
			Font = Enum.Font.SciFi,
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
			statusLabel
		}
	)

	return readPanel
end

return CreateReadbackBox