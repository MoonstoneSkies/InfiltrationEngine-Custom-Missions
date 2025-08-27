local leaves = Instance.new("Part")
leaves.BrickColor = BrickColor.new("Slime green")
leaves.Transparency = 0.05
leaves.CanCollide = false
leaves.Anchored = true
leaves.Size = Vector3.new(0.05, 0.05, 0.05)
leaves.Name = "Bush"

local leavesMesh = Instance.new("SpecialMesh")
leavesMesh.MeshType = Enum.MeshType.FileMesh
leavesMesh.MeshId = "rbxassetid://1091940"
leavesMesh.TextureId = "rbxassetid://140397573"

local function createModel(self)
	local expectedSize = self.Base.Size
	local model = Instance.new("Model")

	local variance = 0.2
	local spacing = 1.2

	local part = leaves:Clone()
	local mesh = leavesMesh:Clone()
	mesh.Scale = Vector3.new(expectedSize.X * 0.5, expectedSize.Y, expectedSize.X * 0.5)
	mesh.Parent = part

	local function plant(cfr)
		local l = part:Clone()
		local mesh = l:FindFirstChildOfClass("SpecialMesh")
		local factor = math.noise(cfr.p.X, cfr.p.Y, cfr.p.Z)
		mesh.Scale = Vector3.new(mesh.Scale.X, mesh.Scale.Y * (1 + factor * variance), mesh.Scale.Z)
		l.CFrame = cfr * CFrame.new(0, mesh.Scale.Y * 0.15, 0) * CFrame.Angles(0, factor * 10, 0)
		l.Parent = model
	end

	local dist = expectedSize.Z - expectedSize.X
	local minDist = dist / -2
	local cuts = math.ceil(dist / spacing)

	for x = 0, cuts do
		plant(self.Base.CFrame * CFrame.new(0, 0, minDist + (x / cuts) * dist))
	end

	self.Model = model
	self.Parts = model:GetChildren()
end

return {
	InitModel = createModel,
}
