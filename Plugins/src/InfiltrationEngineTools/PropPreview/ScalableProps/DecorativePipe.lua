local RING_DIST = 5

local function addPart(model, baseCFr, offset, size)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = baseCFr * CFrame.new(offset)
	p.Anchored = true
	p.CanCollide = false
	p.Name = "Part0"
	p.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	p.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
	p.Material = Enum.Material.Metal
	p.CanTouch = false
	p.Parent = model
	p.CollisionGroup = "None"
	p.CastShadow = false
	return p
end

local function addCylinderPart(model, baseCFr, offset, size)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = baseCFr * CFrame.new(offset)
	p.Anchored = true
	p.CanCollide = true
	p.Shape = Enum.PartType.Cylinder
	p.Name = "Part0"
	p.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	p.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
	p.Material = Enum.Material.Metal
	p.CanTouch = false
	p.Parent = model
	p.CollisionGroup = "None"
	p.CastShadow = false
	return p
end

local function createModel(self)
	self.Base.CollisionGroup = "Default"

	local size = self.Base.Size
	local height = size.Y
	local baseCFr = self.CFrame * CFrame.new(0, height / -2, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local model = Instance.new("Model")

	local POLE_DIAMETER = self.Base.Size.X
	local RING_DIAMETER = POLE_DIAMETER + 0.1

	local bendHeight = height

	if self.Base:GetAttribute("BendTop") or self.Base.Name == "ClimbablePipe" then
		bendHeight = bendHeight - POLE_DIAMETER / 2

		addPart(model, baseCFr, Vector3.new(bendHeight, 0, 0), Vector3.new(POLE_DIAMETER, POLE_DIAMETER, POLE_DIAMETER)).Shape =
			Enum.PartType.Ball

		local bent = addCylinderPart(
			model,
			baseCFr,
			Vector3.new(bendHeight, 0, POLE_DIAMETER / -2),
			Vector3.new(POLE_DIAMETER, POLE_DIAMETER, POLE_DIAMETER)
		)
		bent.CFrame = bent.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	end

	addCylinderPart(
		model,
		baseCFr,
		Vector3.new(bendHeight / 2, 0, 0),
		Vector3.new(bendHeight, POLE_DIAMETER, POLE_DIAMETER)
	).CollisionGroup =
		"Default" -- Main pipe part

	local ringDist = self.Base:GetAttribute("RingSpace") or RING_DIST
	local ringCount = math.floor((bendHeight - 2) / ringDist)

	for i = 0, ringCount do
		local ringHeight = bendHeight / 2 + (i - ringCount / 2) * ringDist
		addCylinderPart(model, baseCFr, Vector3.new(ringHeight, 0, 0), Vector3.new(0.2, RING_DIAMETER, RING_DIAMETER))
		addPart(model, baseCFr, Vector3.new(ringHeight, 0, RING_DIAMETER / -2), Vector3.new(0.2, RING_DIAMETER, 0.2))
	end

	self.Model = model
	self.Parts = model:GetChildren()
end

return {
	InitModel = createModel,
}
