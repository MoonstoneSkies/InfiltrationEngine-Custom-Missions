local renStep = game:GetService("RunService").RenderStepped

local MOVE_SPEED = 4

local function addPart(model, baseCFr, offset, size)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = baseCFr * CFrame.new(offset)
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	p.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
	p.CanTouch = false
	p.Parent = model
	p.CastShadow = false
	return p
end

local function createModel(self)
	local size = self.Base.Size
	local height = size.Y
	local baseCFr = self.CFrame * CFrame.new(0, height / -2, 0)

	local model = Instance.new("Model")

	for row = 0, math.floor(height) do
		local main = addPart(model, baseCFr, Vector3.new(0, row + 0.4, 0), Vector3.new(0.3, 0.8, size.Z))
		main.Material = Enum.Material.DiamondPlate
		main.Name = "Part0"
		local fill = addPart(model, baseCFr, Vector3.new(0, row + 0.9, 0), Vector3.new(0.2, 0.2, size.Z))
		fill.Material = Enum.Material.Metal
		fill.Name = "Part1"
	end

	self.Model = model
	self.Parts = model:GetChildren()
end

return {
	InitModel = createModel,
}
