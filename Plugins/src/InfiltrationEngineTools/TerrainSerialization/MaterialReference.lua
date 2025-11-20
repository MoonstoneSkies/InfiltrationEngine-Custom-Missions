local MaterialId

MaterialId = {
	Asphalt = 1,
	Basalt = 2,
	Brick = 3,
	Cobblestone = 4,
	Concrete = 5,
	CorrodedMetal = 6,
	CrackedLava = 7,
	DiamondPlate = 8,
	Fabric = 9,
	Foil = 10,
	ForceField = 11,
	Glacier = 12,
	Glass = 13,
	Granite = 14,
	Grass = 15,
	Ground = 16,
	Ice = 17,
	LeafyGrass = 18,
	Limestone = 19,
	Marble = 20,
	Metal = 21,
	Mud = 22,
	Neon = 23,
	Pavement = 24,
	Pebble = 25,
	Plastic = 26,
	Rock = 27,
	Salt = 28,
	Sand = 29,
	Sandstone = 30,
	Slate = 31,
	SmoothPlastic = 32,
	Snow = 33,
	Wood = 34,
	WoodPlanks = 35,
	ClayRoofTiles = 36,
	Carpet = 37,
	Cardboard = 38,
	CeramicTiles = 39,
	RoofShingles = 40,
	Leather = 41,
	Plaster = 42,
	Rubber = 43,
	Air = 44,
}

for _, material in Enum.Material:GetEnumItems() do
	if MaterialId[material.Name] then
		local id = MaterialId[material.Name]
		MaterialId[material] = id
		MaterialId[id] = material
	end
end

return MaterialId
