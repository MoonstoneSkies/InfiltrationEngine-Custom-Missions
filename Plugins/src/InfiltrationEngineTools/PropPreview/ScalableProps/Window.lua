local FRAME_WIDTH = 0.2

local function createServerGlass(self)
	local base = self.Base
	local attributes = base:GetAttributes()
	local bulletproof = base:GetAttribute("Bulletproof")

	local glass = Instance.new("Part")
	glass.Size = Vector3.new(
		base.Size.Z - (if attributes.NoFrame then 0 else FRAME_WIDTH * 2),
		base.Size.Y - (if attributes.NoFrame then 0 else FRAME_WIDTH * 2)
	)
	glass.CastShadow = false
	glass.CFrame = base.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	glass.Anchored = true
	glass.Color = base:GetAttribute("GlassColor") or Color3.new(0, 0, 0)
	glass.Transparency = 0.8
	glass.Reflectance = 0.2
	glass.Material = Enum.Material.SmoothPlastic

	local size = base.Size
	local center = base.CFrame
	local model = Instance.new("Model")
	local material = base:GetAttribute("Material0") or "Metal"

	local function addPart(model, baseCFr, offset, size)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = baseCFr * CFrame.new(offset)
		p.Anchored = true
		p.Name = "Part0"
		p.TopSurface = Enum.SurfaceType.SmoothNoOutlines
		p.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
		p.Material = Enum.Material.Metal
		p.CanTouch = false
		p.Parent = model
		p.CastShadow = false
		p.Material = material
		return p
	end

	if not attributes.NoFrame then
		addPart(model, center, Vector3.new(0, (size.Y - FRAME_WIDTH) / 2, 0), Vector3.new(size.X, FRAME_WIDTH, size.Z))
		addPart(model, center, Vector3.new(0, (size.Y - FRAME_WIDTH) / -2, 0), Vector3.new(size.X, FRAME_WIDTH, size.Z))
		addPart(
			model,
			center,
			Vector3.new(0, 0, (size.Z - FRAME_WIDTH) / 2),
			Vector3.new(size.X, size.Y - FRAME_WIDTH * 2, FRAME_WIDTH)
		)
		addPart(
			model,
			center,
			Vector3.new(0, 0, (size.Z - FRAME_WIDTH) / -2),
			Vector3.new(size.X, size.Y - FRAME_WIDTH * 2, FRAME_WIDTH)
		)
	end

	if bulletproof then
		glass.Parent = model
		glass.CollisionGroup = "Clear"
		glass:SetAttribute("CanDestroy", true)

		local p = addPart(
			model,
			center,
			Vector3.new(),
			Vector3.new(
				0.1,
				size.Y - (if attributes.NoFrame then 0 else FRAME_WIDTH),
				size.Z - (if attributes.NoFrame then 0 else FRAME_WIDTH)
			)
		)
		p.Material = Enum.Material.Concrete
		p.CollisionGroup = "None"
		p.Transparency = 0.9

		local texture = Instance.new("Texture")
		texture.Texture = "rbxassetid://5009999"
		texture.StudsPerTileU = 2
		texture.StudsPerTileV = 2
		texture.Face = Enum.NormalId.Left
		texture.Parent = p

		texture = texture:Clone()
		texture.Face = Enum.NormalId.Right
		texture.Parent = p

		p.Parent = model
	else
		glass.Name = "Glass"
		glass.Parent = model
	end

	self.Model = model
end

return {
	InitModel = createServerGlass,
}
