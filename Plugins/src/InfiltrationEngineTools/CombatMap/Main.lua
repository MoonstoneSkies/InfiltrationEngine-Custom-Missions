local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)

local module = {}

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable

local DrawnModel = nil
local InputConnection = nil
local CurrentMap = nil

local BLUE = Color3.new(0, 0, 0.8)
local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local function DrawLine(p0, p1, color)
	local p = Instance.new("Part")
	p.Size = Vector3.new(1, 1, (p0 - p1).Magnitude)
	p.CFrame = CFrame.new((p0 + p1) / 2, p0)
	p.Color = color
	p.CastShadow = false
	return p
end

local function GetLinkId(id0, id1)
	if id0 < id1 then
		return id0 .. "|" .. id1
	end
	return id1 .. "|" .. id0
end

local function GetNodeId(node)
	local nodeId = node:GetAttribute("Id")
	if nodeId then return nodeId end

	warn(`Node {node.Name} missing Id attribute, reusing name as Id`)
	node:SetAttribute("Id", node.Name)
	return node.Name
end

local function ToggleNodeLink(node1, node2)
	local node1Links = HttpService:JSONDecode(node1:GetAttribute("LinkedIds") or "[]")
	local node2Links = HttpService:JSONDecode(node2:GetAttribute("LinkedIds") or "[]")

	local idx = table.find(node1Links, GetNodeId(node2))
	if idx == nil then
		table.insert(node1Links, GetNodeId(node2))
		table.insert(node2Links, GetNodeId(node1))
	else
		table.remove(node1Links, idx)
		table.remove(node2Links, table.find(node2Links, GetNodeId(node1)))
	end

	node1:SetAttribute("LinkedIds", HttpService:JSONEncode(node1Links))
	node2:SetAttribute("LinkedIds", HttpService:JSONEncode(node2Links))
end

local function InputNodeName(box)
	-- Need intermediate event to avoid error with FocusLost event order
	local event = Instance.new("BindableEvent")
	local nodeName = nil

	box.Visible = true
	box:CaptureFocus()
	box.Text = ""
	box.FocusLost:Once(function(enterPressed, _)
		if enterPressed then
			nodeName = box.Text
		end
		box.Visible = false
		event:Fire()
	end)

	event.Event:Wait()
	event:Destroy()
	return nodeName
end

function module.Init(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

	print("       Left Click Link - Toggle Link Blocked")
	print("       Left Click Node - Select Combat Flow Node")
	print("CTRL + Left Click Node - Connect Selected Node To Clicked Node")
	print("       Space - Add Node With Automatic ID")
	print("CTRL + Space - Add Node With Manual ID")

	local nodeNameBox
	nodeNameBox = Create("TextBox", {
		Text = "",
		Size = UDim2.new(0, 300, 0, 30),
		Position = UDim2.new(0, 50, 0, 80),
		BorderSizePixel = 0,
		ClearTextOnFocus = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.5,
		Visible = false,
	})

	module.UI = Create("ScreenGui", {
		Parent = game:GetService("CoreGui"),
		Archivable = false,
	}, {
		nodeNameBox
	})

	if workspace.DebugMission:FindFirstChild("CombatFlowMap") then
		VisibilityToggle.TempReveal(workspace.DebugMission.CombatFlowMap)
	end

	local function RedrawMap(id)
		if DrawnModel then
			DrawnModel:Destroy()
			DrawnModel = nil
		end

		DrawnModel = Instance.new("Model")
		DrawnModel.Parent = workspace

		local part = CurrentMap[id]
		local used = {}
		local blocked = part:GetAttribute("BlockedLinks") or "{}"
		blocked = game:GetService("HttpService"):JSONDecode(blocked)

		local FilteredLinks = {}

		local distLeft = {
			[id] = 3,
		}
		local expandFrom = { id }

		while #expandFrom > 0 do
			local checkId = expandFrom[1]
			table.remove(expandFrom, 1)

			local part = CurrentMap:FindFirstChild(checkId)
			local linkTo = HttpService:JSONDecode(part:GetAttribute("LinkedIds") or "[]")

			local deadLinks = {}
			for _, targetId in linkTo do
				local linkName = GetLinkId(checkId, targetId)

				if DrawnModel:FindFirstChild(linkName) ~= nil then
					-- Node link already exists, don't create a second one
					continue
				end

				local linkPart = CurrentMap:FindFirstChild(targetId)
				if linkPart == nil then
					deadLinks[#deadLinks+1] = targetId
					continue
				end

				local p = DrawLine(part.Position, linkPart.Position, BLUE)
				p.Parent = DrawnModel
				p.Name = linkName

				if blocked[linkName] then
					p.Color = BLACK
				else
					table.insert(FilteredLinks, targetId)
					if distLeft[checkId] > 1 and not distLeft[targetId] then
						table.insert(expandFrom, targetId)
					end
				end
				distLeft[targetId] = distLeft[checkId] - 1
			end

			-- Remove links to now-deleted nodes
			for _, dead in pairs(deadLinks) do
				warn(`Found dead link to "{dead}" on node {checkId}, removing...`)
				table.remove(linkTo, table.find(linkTo, dead))
			end
			part:SetAttribute("LinkedIds", HttpService:JSONEncode(linkTo))
		end

		part:SetAttribute("FilteredLinks", HttpService:JSONEncode(FilteredLinks))
		part.Color = BLACK
	end

	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Include
	InputConnection = UIS.InputBegan:Connect(function(input, processed)
		-- Only act on relevant inputs
		local inputIsAdd = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space
		local inputIsMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		local inputIsValid = inputIsAdd or inputIsMouse

		if not inputIsValid then return end

		-- If the mouse button being pressed was to interact with UI, do nothing
		if processed then return end

		local part = mouse.Target
		
		if part == nil then
			game.Selection:Set({})
			if DrawnModel then
				DrawnModel:Destroy()
				DrawnModel = nil
			end
			return
		end
		
		local wasCtrlPressed = input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
		local partIsFlowNode = part:IsDescendantOf(workspace.DebugMission.CombatFlowMap)

		if inputIsAdd and partIsFlowNode then
			-- Probably a mistake - why would you add a flow node directly beside another flow node?
			return
		elseif inputIsAdd then
			local flowElem = game.Selection:Get()[1]
			local flowElemValid = flowElem ~= nil and flowElem:IsDescendantOf(workspace.DebugMission.CombatFlowMap) and (flowElem:IsA("Model") or flowElem:IsA("Part"))

			if not flowElemValid then
				warn("Select a Combat Flow Map or a to-be-connected flow node before attempting to add a new flow node!")
				return
			end

			local flowMap = if flowElem:IsA("Model") then flowElem else flowElem.Parent
			CurrentMap = flowMap

			local newNode = Instance.new("Part")
			newNode.Parent = flowMap
			newNode.Size = Vector3.new(5,5,5)
			newNode.Anchored = true
			newNode.Color = Color3.new(0,0,0)
			newNode.CastShadow = false
			newNode.Transparency = 0.5
			newNode.TopSurface = Enum.SurfaceType.Smooth
			newNode.BottomSurface = Enum.SurfaceType.Smooth

			-- Offset from surface by 5 studs to avoid being half clipped into walls/floors
			castParams.FilterDescendantsInstances = { mouse.Target.Parent }
			local surfaceNormal = workspace:Raycast(mouse.UnitRay.Origin, mouse.UnitRay.Direction*1000, castParams).Normal or Vector3.FromNormalId(mouse.TargetSurface)
			newNode.Position = mouse.Hit.Position + (surfaceNormal*5)

			local manualName = input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
			local newNodeName = if manualName then InputNodeName(nodeNameBox) else HttpService:GenerateGUID(false)
			newNodeName = newNodeName or ""
			newNodeName = newNodeName:gsub("^%s", ""):gsub("%s$", "")

			if flowMap:FindFirstChild(newNodeName) ~= nil then
				warn("Cannot create flow node with duplicate Id!")
				return
			end

			if #newNodeName < 1 then
				newNode:Destroy() -- Destroy preview
				return
			end

			newNode.Transparency = 0
			newNode.Name = newNodeName
			newNode:SetAttribute("Id", newNode.Name)

			if flowElem:IsA("Part") then
				-- If flow node was selected before adding, connect to it
				ToggleNodeLink(newNode, flowElem)
			end

			game.Selection:Set({ newNode })

			RedrawMap(GetNodeId(newNode))

			return
		end

		if partIsFlowNode and not wasCtrlPressed then
			CurrentMap = part.Parent

			for _, p in CurrentMap:GetChildren() do
				p.Name = p:GetAttribute("Id")
				if p.Name == part.Name and p ~= part then
					-- Duplicate part IDs, emit warn
					warn(`Encountered Combat Flow Nodes with duplicate ID of {p.Name} - combat flow may behave unexpectedly`)
				end
			end

			local id = part:GetAttribute("Id")
			game.Selection:Set({ part })

			RedrawMap(id)
		elseif partIsFlowNode and wasCtrlPressed then
			local firstNode = game.Selection:Get()[1]

			-- Current selection isn't flow node, do nothing
			if not firstNode:IsDescendantOf(workspace.DebugMission.CombatFlowMap) then return end

			-- Both are flow nodes but are from different maps so can't join them
			if firstNode.Parent ~= part.Parent then warn(`Attempt to join combat flow nodes {firstNode.Name} and {part.Name} from differing flow maps!`) return end

			ToggleNodeLink(firstNode, part)

			RedrawMap(firstNode:GetAttribute("Id")) -- Sets FilteredLinks
		elseif part.Name:match("|") and #part.Name >= 3 then
			local node = game.Selection:Get()[1]
			local blocked = node:GetAttribute("BlockedLinks") or "{}"
			blocked = game:GetService("HttpService"):JSONDecode(blocked)

			local beingBlocked = not blocked[part.Name]
			blocked[part.Name] = if beingBlocked then true else nil

			node:SetAttribute("BlockedLinks", HttpService:JSONEncode(blocked))

			RedrawMap(node.Name)
		else
			local id0, id1 = part.Name:match("|")

			if DrawnModel then
				DrawnModel:Destroy()
				DrawnModel = nil
			end
		end
	end)
end

function module.Clean()
	if DrawnModel then
		DrawnModel:Destroy()
		DrawnModel = nil
	end

	if InputConnection then
		InputConnection:Disconnect()
		InputConnection = nil
	end

	module.Active = false

	if module.UI then
		module.UI:Destroy()
		module.UI = nil
	end
end

return module

