local ThinBush = require(script.Parent.ThinBush)

local RailWidth = 0.4
local RailWidthHalf = RailWidth / 2
local RailHeight = 0.1

local function addPart(model, cfr, size, name)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cfr
	p.Anchored = true
	p.CanCollide = true
	p.Name = name
	p.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	p.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
	p.Material = Enum.Material.SmoothPlastic
	p.CanTouch = false
	p.Parent = model
	p.CastShadow = false
	return p
end

local function createModel(self)
	local size = self.Base.Size
	local height = size.Y + RailHeight
	local baseCFr = self.CFrame * CFrame.new(0, RailHeight / 2, 0)

	local model = Instance.new("Model")

	addPart(
		model,
		baseCFr * CFrame.new(0, 0, size.Z / 2 - RailWidthHalf),
		Vector3.new(size.X - RailWidth * 2, height, RailWidth),
		"Part0"
	)
	addPart(
		model,
		baseCFr * CFrame.new(0, 0, size.Z / -2 + RailWidthHalf),
		Vector3.new(size.X - RailWidth * 2, height, RailWidth),
		"Part0"
	)
	addPart(
		model,
		baseCFr * CFrame.new(size.X / 2 - RailWidthHalf, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(size.Z, height, RailWidth),
		"Part0"
	)
	addPart(
		model,
		baseCFr * CFrame.new(size.X / -2 + RailWidthHalf, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(size.Z, height, RailWidth),
		"Part0"
	)
	addPart(
		model,
		baseCFr,
		Vector3.new(size.X - RailWidth - RailWidth, height - RailHeight - RailHeight, size.Z - RailWidth - RailWidth),
		"Part1"
	).Material =
		Enum.Material.Pebble

	local base = self.Base
	local attributes = self.Base:GetAttributes()
	local height = attributes.PlantHeight or 3
	local width = attributes.PlantWidth or 0
	if height > 0 then
		local p = Instance.new("Part")
		p.Name = "ThinBush"
		p.CFrame = base.CFrame * CFrame.new(0, base.Size.Y / 2 + height / 2, 0)
		p.Size = Vector3.new(base.Size.X + width, height, base.Size.Z + width)
		local generator = setmetatable({
			Base = p,
			CFrame = p.CFrame,
		}, { __index = ThinBush })
		generator:InitModel()
		generator.Model.Parent = model
	end

	self.Model = model
end

return {
	InitModel = createModel,
}
