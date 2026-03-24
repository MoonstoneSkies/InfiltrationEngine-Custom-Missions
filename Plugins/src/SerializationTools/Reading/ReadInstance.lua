local InsertService = game:GetService("InsertService")

local ENABLE_ARBITRARY_MESHES = true

local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local DefaultProperties = require(script.Parent.Parent.Types.DefaultProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)
local ReadBuild = require(script.Parent.ReadBuild)

local AttributeKeys = {}
for i, v in (AttributeTypes) do
	AttributeKeys[v] = i
end

local ReadInstance
local DefaultFlags = {
	Protected = false,
	Attributes = false,
}
local rootNode

local CreateInstanceReader = function(instanceType, properties, flags)
	if not flags then flags = DefaultFlags end
	local defaults = DefaultProperties[instanceType]

	local InstanceReader = function(str, cursor, Read, colorMap, stringMap)
		local node = {
			Type = instanceType,
			Children = {},
			Attributes = {},
			Properties = {},
			Protected = flags.Protected or nil,
		}
		
		if defaults then
			for k, v in (defaults) do
				node.Properties[k] = v
			end
		end
		for i, v in (properties) do
			node.Properties[v[1]] = v[3]
		end

		local propertyId = StringConversion.StringToNumber(str, cursor, 1)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			if valueType == "Color3" then
				local colorMapIndex
				colorMapIndex, cursor = Read.ShortInt(str, cursor)
				node.Properties[typeName] = colorMap[colorMapIndex]
			elseif valueType == "String" then
				local stringMapIndex
				stringMapIndex, cursor = Read.ShortInt(str, cursor)
				node.Properties[typeName] = stringMap[stringMapIndex]
			elseif valueType == "InstanceReference" then
				local pathString, newCursor = Read.String(str, cursor)
				cursor = newCursor
				if not node.Expensive then node.Expensive = {} end
				node.Expensive[typeName] = pathString
				ReadBuild.rootNode.Expensives += 1
			else
				node.Properties[typeName], cursor = Read[valueType](str, cursor)
			end
			propertyId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
		end
		
		if flags.Attributes then
			local attributeId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
			while not (attributeId == 0) do
				local typeName = AttributeKeys[attributeId]
				local nameMapIndex
				nameMapIndex, cursor = Read.ShortInt(str, cursor)
				local name = stringMap[nameMapIndex]
				local value
				if typeName == "Color3" then
					local colorMapIndex
					colorMapIndex, cursor = Read.ShortInt(str, cursor)
					value = colorMap[colorMapIndex]
				elseif typeName == "String" then
					local valueMapIndex
					valueMapIndex, cursor = Read.ShortInt(str, cursor)
					value = stringMap[valueMapIndex]
				else
					value, cursor = Read[typeName](str, cursor)
				end
				node.Attributes[name] = value
				attributeId = StringConversion.StringToNumber(str, cursor, 1)
				cursor += 1
			end
			node.Attributes = AttributeValidation.Validate(node.Properties.ClassName, node.Properties.Name, node.Attributes, true)
		end
		
		return node, cursor
	end
	
	return InstanceReader
end

ReadInstance = {
	Model = CreateInstanceReader(`Model`, InstanceProperties.Model, {Attributes = true}),
	Folder = CreateInstanceReader(`Folder`, InstanceProperties.Folder, {Attributes = true}),
	Part = CreateInstanceReader(`Part`, InstanceProperties.Part, {Attributes = true}),
	PartNoAttributes = CreateInstanceReader("Part", InstanceProperties.Part),
	BoolValue = CreateInstanceReader(`BoolValue`, InstanceProperties.BoolValue, {Attributes = true}),
	WedgePart = CreateInstanceReader("WedgePart", InstanceProperties.WedgePart),
	StringValue = CreateInstanceReader("StringValue", InstanceProperties.StringValue),
	MeshPart = CreateInstanceReader(`MeshPart`, InstanceProperties.MeshPart, {Attributes = true, Protected = true}),
	UnionOperation = CreateInstanceReader(`UnionOperation`, InstanceProperties.UnionOperation, {Attributes = true, Protected = true}),
	Texture = CreateInstanceReader("Texture", InstanceProperties.Texture),
	BlockMesh = CreateInstanceReader("BlockMesh", InstanceProperties.BlockMesh),
	PointLight = CreateInstanceReader("PointLight", InstanceProperties.PointLight),
	SpotLight = CreateInstanceReader("SpotLight", InstanceProperties.SpotLight),
	SurfaceLight = CreateInstanceReader("SurfaceLight", InstanceProperties.SurfaceLight),
	SpecialMesh = CreateInstanceReader("SpecialMesh", InstanceProperties.SpecialMesh),
	Decal = CreateInstanceReader("Decal", InstanceProperties.Decal),
	Fire = CreateInstanceReader("Fire", InstanceProperties.Fire),
	Smoke = CreateInstanceReader("Smoke", InstanceProperties.Smoke),
	Attachment = CreateInstanceReader("Attachment", InstanceProperties.Attachment),
	ParticleEmitter = CreateInstanceReader("ParticleEmitter", InstanceProperties.ParticleEmitter),
	Sparkles = CreateInstanceReader("Sparkles", InstanceProperties.Sparkles),
	SurfaceGui = CreateInstanceReader("SurfaceGui", InstanceProperties.SurfaceGui),
	ImageLabel = CreateInstanceReader("ImageLabel", InstanceProperties.ImageLabel),
	BillboardGui = CreateInstanceReader("BillboardGui", InstanceProperties.BillboardGui),
	Frame = CreateInstanceReader("Frame", InstanceProperties.Frame),
	Beam = CreateInstanceReader("Beam", InstanceProperties.Beam),
	Trail = CreateInstanceReader("Trail", InstanceProperties.Trail),
}

return ReadInstance