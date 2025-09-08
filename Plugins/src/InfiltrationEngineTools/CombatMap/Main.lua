local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)

local module = {}

local DrawnModel = nil
local ClickConnection = nil
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

local function LinkId(id0, id1)
	if id0 < id1 then
		return id0 .. "|" .. id1
	end
	return id1 .. "|" .. id0
end

local function ToggleNodeLink(node1, node2)
	local node1Links = HttpService:JSONDecode(node1:GetAttribute("LinkedIds") or "[]")
	local node2Links = HttpService:JSONDecode(node2:GetAttribute("LinkedIds") or "[]")
	
	local idx = table.find(node1Links, node2.Name)
	if idx == nil then
		table.insert(node1Links, node2.Name)
		table.insert(node2Links, node1.Name)
	else
		table.remove(node1Links, idx)
		table.remove(node2Links, table.find(node2Links, node1.Name))
	end
	
	node1:SetAttribute("LinkedIds", HttpService:JSONEncode(node1Links))
	node2:SetAttribute("LinkedIds", HttpService:JSONEncode(node2Links))
end

function module.Init(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true

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
			local linkTo = HttpService:JSONDecode(part:GetAttribute("LinkedIds"))

			for _, targetId in linkTo do
				local linkName = LinkId(checkId, targetId)

				if DrawnModel:FindFirstChild(linkName) ~= nil then
					-- Node link already exists, don't create a second one
					continue
				end

				local linkPart = CurrentMap:FindFirstChild(targetId)
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
		end

		part:SetAttribute("FilteredLinks", HttpService:JSONEncode(FilteredLinks))
		part.Color = BLACK
	end

	ClickConnection = UIS.InputBegan:Connect(function(input, processed)
		-- Only act on mouse inputs
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		
		-- If the mouse button being pressed was to interact with UI, do nothing
		if processed then return end
		
		local part = mouse.Target
		local wasCtrlPressed = input:IsModifierKeyDown(Enum.ModifierKey.Ctrl)
		local partIsFlowNode = part:IsDescendantOf(workspace.DebugMission.CombatFlowMap) 
		
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

	if ClickConnection then
		ClickConnection:Disconnect()
		ClickConnection = nil
	end

	module.Active = false
end

return module

