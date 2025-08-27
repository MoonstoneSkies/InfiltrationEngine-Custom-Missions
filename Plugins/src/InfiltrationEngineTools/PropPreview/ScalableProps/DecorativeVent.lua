local function addPart(model, baseCFr, offset, size)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = baseCFr * CFrame.new(offset)
	p.Anchored = true
	p.CanCollide = true
	p.Name = "Part0"
	p.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	p.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
	p.Material = Enum.Material.Metal
	p.CanTouch = false
	p.Parent = model
	p.CollisionGroup = "Default"
	p.CastShadow = false
	return p
end

local function addWedgePart(model, baseCFr, offset, size)
	local p = Instance.new("WedgePart")
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
	local height = size.Y
	local baseCFr = self.CFrame * CFrame.new(0, height / -2, 0)

	local model = Instance.new("Model")
	local mainSectionBottom = 0
	local mainSectionTop = height

	local bendTop = self.Base:GetAttribute("BendTop")
	if bendTop == 1 then
		local bendSize = size.Z / 2
		mainSectionTop -= bendSize
		addPart(
			model,
			baseCFr,
			Vector3.new(0, mainSectionTop + bendSize / 2, bendSize / -2),
			Vector3.new(size.X, bendSize, bendSize)
		)
		addWedgePart(
			model,
			baseCFr * CFrame.Angles(0, math.pi, 0),
			Vector3.new(0, mainSectionTop + bendSize / 2, bendSize / -2),
			Vector3.new(size.X, bendSize, bendSize)
		)
	elseif bendTop == 2 then
		local bendSize = size.X / 2
		mainSectionTop -= bendSize
		addPart(
			model,
			baseCFr,
			Vector3.new(bendSize / 2, mainSectionTop + bendSize / 2, 0),
			Vector3.new(bendSize, bendSize, size.Z)
		)
		addWedgePart(
			model,
			baseCFr * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0, mainSectionTop + bendSize / 2, bendSize / -2),
			Vector3.new(size.Z, bendSize, bendSize)
		)
	elseif bendTop == 3 then
		local bendSize = size.X / 2
		mainSectionTop -= bendSize
		addPart(
			model,
			baseCFr,
			Vector3.new(bendSize / -2, mainSectionTop + bendSize / 2, 0),
			Vector3.new(bendSize, bendSize, size.Z)
		)
		addWedgePart(
			model,
			baseCFr * CFrame.Angles(0, math.pi / -2, 0),
			Vector3.new(0, mainSectionTop + bendSize / 2, bendSize / -2),
			Vector3.new(size.Z, bendSize, bendSize)
		)
	end

	local bendBottom = self.Base:GetAttribute("BendBottom")
	if bendBottom == 1 then
		local bendSize = size.Z / 2
		mainSectionBottom += bendSize
		addPart(model, baseCFr, Vector3.new(0, bendSize / 2, bendSize / -2), Vector3.new(size.X, bendSize, bendSize))
		addWedgePart(
			model,
			baseCFr * CFrame.Angles(math.pi, 0, 0),
			Vector3.new(0, bendSize / -2, bendSize / -2),
			Vector3.new(size.X, bendSize, bendSize)
		)
	elseif bendBottom == 2 then
		local bendSize = size.X / 2
		mainSectionBottom += bendSize
		addPart(model, baseCFr, Vector3.new(bendSize / 2, bendSize / 2, 0), Vector3.new(bendSize, bendSize, size.Z))
		addWedgePart(
			model,
			baseCFr * CFrame.Angles(math.pi, math.pi / 2, 0),
			Vector3.new(0, bendSize / -2, bendSize / -2),
			Vector3.new(size.Z, bendSize, bendSize)
		)
	elseif bendBottom == 3 then
		local bendSize = size.X / 2
		mainSectionBottom += bendSize
		addPart(model, baseCFr, Vector3.new(bendSize / -2, bendSize / 2, 0), Vector3.new(bendSize, bendSize, size.Z))
		addWedgePart(
			model,
			baseCFr * CFrame.Angles(math.pi, math.pi / -2, 0),
			Vector3.new(0, bendSize / -2, bendSize / -2),
			Vector3.new(size.Z, bendSize, bendSize)
		)
	end

	addPart(
		model,
		baseCFr,
		Vector3.new(0, (mainSectionTop + mainSectionBottom) / 2, 0),
		Vector3.new(size.X, mainSectionTop - mainSectionBottom, size.Z)
	)

	local ringDepth = self.Base:GetAttribute("RingDepth") or 0
	local ringDist = self.Base:GetAttribute("RingSpace") or 5
	local rings = math.floor((mainSectionTop - mainSectionBottom) / ringDist)
	local ringStart = (mainSectionTop - mainSectionBottom - rings * ringDist) / 2 + mainSectionBottom
	for i = 0, rings do
		local h = ringStart + i * ringDist
		addPart(model, baseCFr, Vector3.new(0, h, size.Z / 2), Vector3.new(size.X + 0.2, 0.3, 0.2))
		addPart(
			model,
			baseCFr,
			Vector3.new(size.X / 2, h, ringDepth / -2 - 0.1),
			Vector3.new(0.2, 0.3, size.Z + ringDepth)
		)
		addPart(
			model,
			baseCFr,
			Vector3.new(size.X / -2, h, ringDepth / -2 - 0.1),
			Vector3.new(0.2, 0.3, size.Z + ringDepth)
		)
	end

	self.Model = model
	self.Parts = model:GetChildren()
end

return {
	InitModel = createModel,
}
