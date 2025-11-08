local HttpService = game:GetService("HttpService")

local AxisAlign = require(script.Parent.Parent.Util.AxisAlign)
local ZoneUtil = require(script.Parent.Parent.Util.ZoneUtil)
local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)

local UserInputService = game:GetService("UserInputService")
local UserInputConnection

local DOOR_BUFFER = 4.5

local CurrentZone = nil
local CurrentMap = {}
local CurrentModel = nil
local LinkWith = nil

local function CloseZone()
	if CurrentModel then
		CurrentModel:Destroy()
		CurrentModel = nil
	end
	CurrentMap = {}
	CurrentZone = nil
end

local function CheckLOS(p0, p1)
	if p0 == p1 then
		return false
	end
	local result = workspace:Raycast(p0.Position + Vector3.new(0, 0.75, 0), p1.Position - p0.Position)
	return not result or result.Instance == p1
end

local function AddLink(p0, p1)
	local l0 = Instance.new("Part")
	l0.Size = Vector3.new(0.4, 0.4, (p0.Position - p1.Position).magnitude / 2)
	l0.Transparency = 0.5
	local l1 = l0:Clone()

	l0.CFrame = CFrame.new(p0.Position * 0.75 + p1.Position * 0.25, p0.Position)
	if not CurrentMap[p0][p1] then
		CurrentMap[p0][p1] = l0
		l0.BrickColor = BrickColor.new("Bright blue")
		l0.Parent = CurrentModel
	end

	l1.CFrame = CFrame.new(p1.Position * 0.75 + p0.Position * 0.25, p1.Position)
	if not CurrentMap[p1][p0] then
		CurrentMap[p1][p0] = l1
		l1.BrickColor = BrickColor.new("Bright blue")
		l1.Parent = CurrentModel
	end
end

local function AddOneWayLink(p0, p1)
	local l0 = Instance.new("Part")
	l0.Size = Vector3.new(0.4, 0.4, (p0.Position - p1.Position).magnitude / 2)
	l0.Transparency = 0.5

	l0.CFrame = CFrame.new(p0.Position * 0.75 + p1.Position * 0.25, p0.Position)
	if not CurrentMap[p0][p1] then
		CurrentMap[p0][p1] = l0
		l0.BrickColor = BrickColor.new("Bright blue")
		l0.Parent = CurrentModel
	end
end

local function CreateNode(pos, placed, generateLinks)
	if placed and not ZoneUtil.InZone(CurrentZone, pos) then
		warn("Nodes should not be placed outside of their cell")
		return
	end

	local p = Instance.new("Part")
	p.Size = Vector3.new(2, 2, 2)
	p.Parent = CurrentModel
	p.CFrame = CFrame.new(pos)
	p.BrickColor = BrickColor.new("Bright blue")
	if placed then
		p.Transparency = 0.5
	end
	CurrentMap[p] = {}
	if generateLinks then
		for node in pairs(CurrentMap) do
			if node ~= p and CheckLOS(node, p) then
				AddLink(node, p)
			end
		end
	end
	return p
end

local function OpenZone(newZone)
	if CurrentZone then
		CloseZone()
	end

	local DoorNodes = {}
	for _, prop in pairs(workspace.DebugMission.Props:GetChildren()) do
		if prop.Name:match("Door") then
			local p0 = (prop.CFrame * CFrame.new(0, -3, DOOR_BUFFER)).p
			local p1 = (prop.CFrame * CFrame.new(0, -3, -DOOR_BUFFER)).p
			if ZoneUtil.InZone(newZone, p0) then
				table.insert(DoorNodes, p0)
			end
			if ZoneUtil.InZone(newZone, p1) then
				table.insert(DoorNodes, p1)
			end
		end
	end

	if workspace.DebugMission.Cells:FindFirstChild("Links") then
		for _, link in pairs(workspace.DebugMission.Cells.Links:GetChildren()) do
			if link:GetAttribute("Path") then
				local p0 = (link.CFrame * CFrame.new(0, 0.5, DOOR_BUFFER)).p
				local p1 = (link.CFrame * CFrame.new(0, 0.5, -DOOR_BUFFER)).p
				if ZoneUtil.InZone(newZone, p0) then
					table.insert(DoorNodes, p0)
				end
				if ZoneUtil.InZone(newZone, p1) then
					table.insert(DoorNodes, p1)
				end
			end
		end
	end

	CurrentModel = Instance.new("Model")
	CurrentModel.Parent = workspace
	CurrentMap = {}
	CurrentZone = newZone

	for _, pos in pairs(DoorNodes) do
		CreateNode(pos, false, true)
	end

	--[[if CurrentZone:GetAttribute("Path") then
		local data = HttpService:JSONDecode(CurrentZone:GetAttribute("Path"))
		if data.Placed then
			for _, placed in pairs(data.Placed) do
				CreateNode(Vector3.new(unpack(placed)), true, true)
			end
		end
	end]]
end

local function OpenZoneWithoutRegenerating(newZone)
	if CurrentZone then
		CloseZone()
	end

	CurrentModel = Instance.new("Model")
	CurrentModel.Parent = workspace
	CurrentMap = {}
	CurrentZone = newZone

	game.Selection:Set({ newZone })

	if not CurrentZone:GetAttribute("Path") then
		print("Doing first time generation for zone")
		return OpenZone(newZone)
	end

	local data = HttpService:JSONDecode(CurrentZone:GetAttribute("Path"))
	local PlacedNodes = {}
	if data.Placed then
		for _, placed in pairs(data.Placed) do
			local node = Vector3.new(unpack(placed))
			PlacedNodes[node] = true
		end
	end

	local NodeParts = {}
	for _, node in pairs(data.Node) do
		local pos = Vector3.new(unpack(node))
		local nodePart = CreateNode(pos, PlacedNodes[pos], false)
		table.insert(NodeParts, nodePart)
	end

	for startIndex, list in data.Link do
		for _, endIndex in list do
			AddOneWayLink(NodeParts[startIndex], NodeParts[endIndex])
		end
	end
end

local function RemovePart(part)
	if CurrentMap[part] then -- Is node
		for _, linkPart in pairs(CurrentMap[part]) do
			linkPart:Destroy()
		end
		CurrentMap[part] = nil
		for node, links in pairs(CurrentMap) do
			if links[part] then
				links[part]:Destroy()
				links[part] = nil
			end
		end
		part:Destroy()
	else -- Is link
		for node, linkList in pairs(CurrentMap) do
			for link, linkPart in pairs(linkList) do
				if linkPart == part then
					linkPart:Destroy()
					linkList[link] = nil
					break
				end
			end
		end
	end
end

local function Serialize()
	local node = {}
	local nodeId = {}
	local link = {}
	local placed = {}

	local function getNode(p)
		if not nodeId[p] then
			local pos = p.Position
			node[#node + 1] = { pos.X, pos.Y, pos.Z }
			nodeId[p] = #node

			if p.Transparency > 0.25 then
				table.insert(placed, node[#node])
			end
		end
		return nodeId[p]
	end

	for node, linkList in pairs(CurrentMap) do
		local id = getNode(node)
		local links = {}
		for linkNode in pairs(linkList) do
			table.insert(links, getNode(linkNode))
		end
		link[id] = links
	end

	return HttpService:JSONEncode({
		Node = node,
		Link = link,
		Placed = placed,
	})
end

local function Save()
	CurrentZone:SetAttribute("Path", Serialize())
end

local LastCTap = 0

return {
	Init = function(mouse)
		print("T - Open Cell Meadow Map")
		print("C - Fully Clear Meadow Map (Tap twice)")
		print("G - Add Node")
		print("H - Add Node (No Link Generation)")
		print("R - Remove")

		VisibilityToggle.TempReveal(workspace.DebugMission.Cells)

		UserInputConnection = UserInputService.InputBegan:Connect(function(io)
			if io.KeyCode == Enum.KeyCode.C then
				if tick() - LastCTap < 0.5 then
					LastCTap = 0
					local zone = ZoneUtil.GetZone(mouse.Hit.p)
					if zone then
						OpenZone(zone)
						Save()
					end
				else
					LastCTap = tick()
					local clock = LastCTap
					task.delay(0.5, function()
						if clock ~= LastCTap then
							return
						end
						warn(
							"Double tap C to fully clear and regenerate the meadow map for this room\nThis will remove any manual modifications you've made"
						)
					end)
				end
			elseif io.KeyCode == Enum.KeyCode.T then
				local zone = ZoneUtil.GetZone(mouse.Hit.p)
				if zone then
					OpenZoneWithoutRegenerating(zone)
					Save()
				elseif CurrentZone then
					warn("Cursor must be in cell to open meadow map")
					CloseZone()
				end
			elseif io.KeyCode == Enum.KeyCode.G then
				if CurrentZone then
					CreateNode(mouse.Hit.p + Vector3.new(0, 1, 0), true, true)
					Save()
				end
			elseif io.KeyCode == Enum.KeyCode.H then
				if CurrentZone then
					CreateNode(mouse.Hit.p + Vector3.new(0, 1, 0), true, false)
					Save()
				end
			elseif io.KeyCode == Enum.KeyCode.R then
				if mouse.Target then
					RemovePart(mouse.Target)
					Save()
				end
			elseif io.UserInputType == Enum.UserInputType.MouseButton1 then
				if LinkWith then
					if CurrentMap[LinkWith] and CurrentMap[mouse.Target] then
						AddLink(LinkWith, mouse.Target)
						Save()
					else
						print("Link failed")
					end
					LinkWith = nil
				elseif CurrentMap[mouse.Target] then
					LinkWith = mouse.Target
					print("Click another node to link")
				end
			end
		end)
	end,
	Clean = function()
		if UserInputConnection then
			UserInputConnection:Disconnect()
			UserInputConnection = nil
		end
		if CurrentZone then
			CloseZone()
		end
	end,
}
