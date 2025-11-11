local AxisAlign = require(script.Parent.Parent.Util.AxisAlign)
local GetZone = require(script.Parent.GetZone)
local VisibilityToggle = require(script.Parent.Parent.Util.VisibilityToggle)

local UserInputService = game:GetService("UserInputService")

local MAX_PROJECT = 50

local SIZE_PADDING = 1
local POSITION_SINK = 0.3

local CellFolder
local Events = {}
local Ghost
local HoveringCell

local MouseDown = false
local ShiftDown = false
local CtrlDown = false

local GhostCfr
local GhostSize
local GhostMax
local GhostMin

local WithPropCastParams = RaycastParams.new()
local NoPropCastParams = RaycastParams.new()
NoPropCastParams.FilterType = Enum.RaycastFilterType.Exclude

local CellCastParams = RaycastParams.new()
CellCastParams.FilterType = Enum.RaycastFilterType.Include

local function GetLevelRoot()
	return workspace:FindFirstChild("DebugMission") or workspace:FindFirstChild("Level")
end

local function CreateTempDoorFolder()
	local levelRoot = GetLevelRoot()
	local propFolder = levelRoot and levelRoot:FindFirstChild("Props")
	if not propFolder then return end

	local doorsFolderTemp = Instance.new("Folder")
	doorsFolderTemp.Name = "CellMarkerDoorsTemp"
	doorsFolderTemp.Parent = workspace

	for _, prop in pairs(propFolder:GetChildren()) do
		if prop.Name:find("Door") == nil then continue end
		local tempDoor = prop:Clone()
		tempDoor.Parent = doorsFolderTemp
	end
end

local function CleanupTempDoorFolder()
	local doorsFolderTemp = workspace:FindFirstChild("CellMarkerDoorsTemp")
	if not doorsFolderTemp then return end
	doorsFolderTemp:Destroy()
end

local function UpdatePropCastExcludeList()
	local levelRoot = GetLevelRoot()
	NoPropCastParams.FilterDescendantsInstances = {
		levelRoot and levelRoot:FindFirstChild("Props") or nil,
		levelRoot and levelRoot:FindFirstChild("CombatFlowMap") or nil,
		levelRoot and levelRoot:FindFirstChild("Nodes") or nil,
		levelRoot and levelRoot:FindFirstChild("MapData") or nil
	}
end

local function GetProjectionDist(basePos, axis)
	local castParams = CtrlDown and WithPropCastParams or NoPropCastParams

	local castDistance = ShiftDown and 1_000_000 or MAX_PROJECT

	local result = workspace:Raycast(basePos, axis * castDistance, castParams)
	if result then
		return (result.Position - basePos).magnitude
	else
		return MAX_PROJECT
	end
end

local function UpdateGhost(basePos, axis0, axis1, mouseDown)
	if mouseDown then
		Ghost.Transparency = 0.0
		return
	else
		Ghost.Transparency = 0.5
	end
	
	local z0, z1 = GetProjectionDist(basePos, axis0), GetProjectionDist(basePos, -axis0)
	local x0, x1 = GetProjectionDist(basePos, axis1), GetProjectionDist(basePos, -axis1)

	local pos = basePos + axis0 * (z0 - z1) / 2 + axis1 * (x0 - x1) / 2
	GhostCfr = CFrame.new(pos, pos + axis0)
	GhostSize = Vector3.new(x0 + x1, 0.2, z0 + z1)
	GhostMax = GetProjectionDist(basePos, Vector3.new(0, 1, 0))
	GhostMin = GetProjectionDist(basePos, Vector3.new(0, -1, 0))

	if GhostMax == MAX_PROJECT and not ShiftDown then
		GhostMax = GhostMax - GhostMin
	end

	Ghost.CFrame = GhostCfr
	Ghost.Size = GhostSize
end

local function UpdateHoveringCell(pos, mouseDown)
	if HoveringCell then
		-- Reveal previously hovered cell
		for _, p in pairs(HoveringCell:GetChildren()) do
			p.Transparency = 0.5
		end
	end
	
	if not MouseDown then return end
	
	local hoveringCell = GetZone(pos)
	if not hoveringCell then return end
	
	HoveringCell = hoveringCell
	for _, p in pairs(hoveringCell:GetChildren()) do
		p.Transparency = 0
	end
end

local function ReoptimizeCells()
	print("Reoptimize cell floors")
	local LevelBase = workspace:FindFirstChild("DebugMission") or workspace:FindFirstChild("Level")
	for _, cell in pairs(LevelBase.Cells:GetChildren()) do
		if cell:IsA("Model") then
			local canFit = true
			local floorPart

			local baseRef = cell:FindFirstChild("Roof")
			local minX, maxX = baseRef.Position.X, baseRef.Position.X
			local minZ, maxZ = baseRef.Position.Z, baseRef.Position.Z

			for _, part in pairs(cell:GetChildren()) do
				if part.Name=="Roof" then
					for xo = -1, 1, 2 do
						for zo = -1, 1, 2 do
							local ref = part.CFrame:pointToWorldSpace(Vector3.new(part.Size.X * 0.5 * xo, 0, part.Size.Z * 0.5 * zo))
							minX = math.min(minX, ref.X)
							maxX = math.max(maxX, ref.X)
							minZ = math.min(minZ, ref.Z)
							maxZ = math.max(maxZ, ref.Z)
						end
					end
				elseif part.Name=="Floor" then
					if floorPart==nil then
						floorPart = part
					else
						canFit = false
						break
					end
				end
			end

			if floorPart and canFit then
				floorPart.Size = Vector3.new(maxX - minX, floorPart.Size.Y, maxZ - minZ)
				floorPart.CFrame = CFrame.new((maxX + minX)/2, floorPart.Position.Y, (maxZ + minZ)/2)
			end
		end
	end
end

local function ShowCells()
	for _, cell in pairs(CellFolder:GetChildren()) do
		for _, part in pairs(cell:GetChildren()) do
			part.Size = Vector3.new(part.Size.X, 1, part.Size.Z)
			part.Transparency = 0.5
			part.Locked = false
		end
	end
end

local function ShowLinks()
	for _, cell in pairs(CellFolder:GetChildren()) do
		if cell.Name ~= "Links" then continue end
		for _, part in pairs(cell:GetChildren()) do
			part.Size = Vector3.new(part.Size.X, 1, part.Size.Z)
			part.Transparency = 0.5
			part.Locked = false
		end
	end
end

local function HideCells()
	for _, cell in pairs(CellFolder:GetChildren()) do
		for _, part in pairs(cell:GetChildren()) do
			part.Size = Vector3.new(part.Size.X, 0, part.Size.Z)
			part.Transparency = 1
			part.Locked = true
		end
	end
end

local function HideNamedCells()
	for _, cell in pairs(CellFolder:GetChildren()) do
		if cell.Name ~= "Default" then
			for _, part in pairs(cell:GetChildren()) do
				part.Size = Vector3.new(part.Size.X, 0, part.Size.Z)
				part.Transparency = 1
				part.Locked = true
			end
		end
	end
end

local function hashName(name)
	if name == "Default" then
		return Color3.new(0, 0, 0)
	end

	local h = 5^7
	local n = 0
	for i = 1, #name do
		n = (n * 257 + string.byte(name, i, i)) % h 
	end
	local color = Color3.fromHSV((n % 1000) / 1000, 0.5, 0.5)
	return color
end

local function RecolorCells()
	for _, cell in pairs(CellFolder:GetChildren()) do
		local color = hashName(cell.Name)
		for _, part in pairs(cell:GetChildren()) do
			part.Color = color
		end
	end
end

local function CreateCell(mousePos)
	local cellModel = GetZone(mousePos)
	local addFloor = true

	if cellModel then
		addFloor = false
		print("Add to:", cellModel:GetFullName())
	else
		local LevelBase = workspace:FindFirstChild("DebugMission") or workspace:FindFirstChild("Level")
		print("Create new cell")
		cellModel = Instance.new("Model")
		cellModel.Name = "Default"
		cellModel.Parent = LevelBase.Cells
	end

	local roof = Ghost:Clone()
	roof.Size = roof.Size + Vector3.new(SIZE_PADDING * 2, 0.8, SIZE_PADDING * 2)
	roof.CFrame = GhostCfr * CFrame.new(0, GhostMax + POSITION_SINK, 0)
	roof.Name = "Roof"
	roof.Parent = cellModel
	roof.Anchored = true
	roof.Transparency = 0.5
	roof.CastShadow = false

	if addFloor then
		local floor = roof:Clone()
		floor.Name = "Floor"
		floor.CFrame = GhostCfr * CFrame.new(0, -GhostMin - POSITION_SINK, 0)
		floor.Parent = cellModel
		floor.Anchored = true
		floor.CastShadow = false
	else
		ReoptimizeCells()
	end
end

return {
	Init = function(mouse)
		if not workspace:FindFirstChild("Level") then
			local l = Instance.new("Folder")
			l.Name = "Level"
			l.Parent = workspace
		end

		local LevelBase = GetLevelRoot()
		if not LevelBase:FindFirstChild("Cells") then
			local c = Instance.new("Folder")
			c.Name = "Cells"
			c.Parent = LevelBase
		end

		UpdatePropCastExcludeList()
		CreateTempDoorFolder()

		Ghost = Instance.new("Part")
		Ghost.Color = Color3.new(0, 0, 0)
		Ghost.Transparency = 0.5
		Ghost.Parent = LevelBase.Cells
		Ghost.CastShadow = false

		CellFolder = LevelBase.Cells
		mouse.TargetFilter = CellFolder
		WithPropCastParams.FilterType = Enum.RaycastFilterType.Exclude
		WithPropCastParams.FilterDescendantsInstances = { CellFolder }

		Events[1] = game:GetService("RunService").RenderStepped:connect(function()
			if mouse.Target then
				local v0, v1 = AxisAlign.CameraAlign(mouse.Target.CFrame)
				local origin = mouse.Hit.p - mouse.UnitRay.Direction * 0.5
				UpdateGhost(origin, v0, v1, MouseDown)
				UpdateHoveringCell(mouse.Hit.p, MouseDown)
			end
		end)

		Events[2] = mouse.Button1Up:connect(function()
			CreateCell(mouse.Hit.p)
			MouseDown = false
		end)

		Events[3] = mouse.Button1Down:connect(function()
			MouseDown = true
		end)

		Events[4] = UserInputService.InputBegan:connect(function(io)
			ShiftDown = io:IsModifierKeyDown(Enum.ModifierKey.Shift)
			CtrlDown  = io:IsModifierKeyDown(Enum.ModifierKey.Ctrl )
			if io.KeyCode == Enum.KeyCode.T then
				ReoptimizeCells()
			elseif io.KeyCode == Enum.KeyCode.G then
				ShowCells()
			elseif io.KeyCode == Enum.KeyCode.H then
				HideCells()
			elseif io.KeyCode == Enum.KeyCode.J then
				HideNamedCells()
			elseif io.KeyCode == Enum.KeyCode.K then
				RecolorCells()
			elseif io.KeyCode == Enum.KeyCode.L then
				ShowLinks()
			end
		end)
		
		Events[5] = UserInputService.InputEnded:Connect(function(io)
			ShiftDown = io:IsModifierKeyDown(Enum.ModifierKey.Shift)
			CtrlDown  = io:IsModifierKeyDown(Enum.ModifierKey.Ctrl )
		end)

		VisibilityToggle.TempReveal(workspace.DebugMission.Cells)

		print([[T - Reoptimize Cell Floors
		G - Show All Cells
		H - Hide All Cells
		J - Hide Named Cells
		K - Recolor Cells
		L - Show Links]])
	end,
	Clean = function()
		if Events then
			for _, e in pairs(Events) do
				e:Disconnect()
			end
			Events = {}
		end
		if Ghost then
			Ghost:Destroy()
			Ghost = nil
		end
		CleanupTempDoorFolder()
	end,
}