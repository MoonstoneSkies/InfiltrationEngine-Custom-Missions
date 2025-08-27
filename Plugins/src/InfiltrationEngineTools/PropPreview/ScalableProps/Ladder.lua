local POLE_DIAMETER = 0.3
local POLE_HEIGHT = 1
local RUNG_DIAMETER = 0.2
local RUNG_SPACING = 0.7
local TOP_DEPTH = 2

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

local function createModel(self)
	self.Base.CollisionGroup = "Default"

	local size = self.Base.Size
	local center = self.CFrame * CFrame.new(0, 0, (size.Z - POLE_DIAMETER) / 2)

	local model = Instance.new("Model")

	local left, right = (size.X - POLE_DIAMETER) / 2, (size.X - POLE_DIAMETER) / -2
	-- Main poles
	addPart(
		model,
		center,
		Vector3.new(left, POLE_HEIGHT / 2, 0),
		Vector3.new(POLE_DIAMETER, size.Y + POLE_HEIGHT, POLE_DIAMETER)
	)
	addPart(
		model,
		center,
		Vector3.new(right, POLE_HEIGHT / 2, 0),
		Vector3.new(POLE_DIAMETER, size.Y + POLE_HEIGHT, POLE_DIAMETER)
	)
	-- Top Back Poles
	addPart(
		model,
		center,
		Vector3.new(left, (size.Y + POLE_HEIGHT) / 2, -TOP_DEPTH + POLE_DIAMETER),
		Vector3.new(POLE_DIAMETER, POLE_HEIGHT, POLE_DIAMETER)
	)
	addPart(
		model,
		center,
		Vector3.new(right, (size.Y + POLE_HEIGHT) / 2, -TOP_DEPTH + POLE_DIAMETER),
		Vector3.new(POLE_DIAMETER, POLE_HEIGHT, POLE_DIAMETER)
	)
	-- Top Flat Poles
	addPart(
		model,
		center,
		Vector3.new(left, (size.Y - POLE_DIAMETER) / 2 + POLE_HEIGHT, (TOP_DEPTH - POLE_DIAMETER) / -2),
		Vector3.new(POLE_DIAMETER, POLE_DIAMETER, TOP_DEPTH - POLE_DIAMETER - POLE_DIAMETER)
	)
	addPart(
		model,
		center,
		Vector3.new(right, (size.Y - POLE_DIAMETER) / 2 + POLE_HEIGHT, (TOP_DEPTH - POLE_DIAMETER) / -2),
		Vector3.new(POLE_DIAMETER, POLE_DIAMETER, TOP_DEPTH - POLE_DIAMETER - POLE_DIAMETER)
	)

	local rungSize = Vector3.new(size.X - POLE_DIAMETER, RUNG_DIAMETER, RUNG_DIAMETER)
	for l = (size.Y - RUNG_DIAMETER) / 2, (size.Y - 2) / -2, -RUNG_SPACING do
		addPart(model, center, Vector3.new(0, l, 0), rungSize)
	end

	self.Model = model
	self.Parts = model:GetChildren()
end

return {
	InitModel = createModel,
}
