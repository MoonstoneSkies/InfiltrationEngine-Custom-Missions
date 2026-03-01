local StringConversion = require(script.Parent.Parent.StringConversion)
local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)

local function lookupMapIndex(map, value)
	if value == nil then
		return 0
	end
	if typeof(value) == "Color3" then
		value = value:ToHex()
	end
	local idx = map[value]
	if idx == nil then
		idx = (map[0] + 1) -- Size + 1
		map[value] = idx
		map[0] = idx -- Update size
	end
	return idx
end

local WithAttributes = function(DefaultWriter)
	return function(object, Write, colorMap, stringMap, buffer)
		colorMap, stringMap = DefaultWriter(object, Write, colorMap, stringMap, buffer)
		local attributes = object:GetAttributes()
		attributes = AttributeValidation.Validate(object.ClassName, object.Name, attributes, false)

		-- Encoding Attributes
		for k, v in pairs(attributes) do
			if k:match("^RBX_") then
				continue
			end

			local attributeType = typeof(v) -- Changing attribute type names to match as they are in the Write file
			if typeof(v) == "number" then
				if v ~= math.round(v) or v < 0 then
					attributeType = "Float"
				else
					attributeType = "LongInt"
				end
			elseif typeof(v) == "boolean" then
				attributeType = "bool"
			end
			attributeType = (string.upper(string.sub(attributeType, 1, 1)) .. string.sub(attributeType, 2, -1))
			if AttributeTypes[attributeType] == nil then -- if the attribute is not in the table, ignore it
				continue
			end

			local index = lookupMapIndex(stringMap, k)
			table.insert(buffer, StringConversion.NumberToString(AttributeTypes[attributeType], 1) .. Write.ShortInt(index))

			if attributeType == "Color3" then
				local index = lookupMapIndex(colorMap, v)
				table.insert(buffer, Write.ShortInt(index))
			elseif attributeType == "String" then
				local index = lookupMapIndex(stringMap, v)
				table.insert(buffer, Write.ShortInt(index))
			else
				table.insert(buffer, Write[attributeType](v))
			end
		end
		table.insert(buffer, StringConversion.NumberToString(0, 1))
		return colorMap, stringMap
	end
end

local CreateInstanceWriter = function(properties)
	local WriteInstance = function(object, Write, colorMap, stringMap, buffer)
		for i, v in pairs(properties) do
			local value
			if v[1] == "MeshId" and object.ClassName == "UnionOperation" then
				value = object:GetAttribute("MeshId")
			else
				value = object[v[1]]
			end
			local valueType = v[2]
			local defaultValue = v[3]
			if (valueType == "Color3") and (value ~= defaultValue) then
				local index = lookupMapIndex(colorMap, value)
				table.insert(buffer, StringConversion.NumberToString(i, 1) .. Write.ShortInt(index))
				continue
			elseif (valueType == "String") and (value ~= defaultValue) then
				local index = lookupMapIndex(stringMap, value)
				table.insert(buffer, StringConversion.NumberToString(i, 1) .. Write.ShortInt(index))
				continue
			elseif value ~= defaultValue then
				table.insert(buffer, StringConversion.NumberToString(i, 1) .. Write[valueType](value))
			end
		end

		table.insert(buffer, StringConversion.NumberToString(0, 1))
		return colorMap, stringMap
	end
	return WriteInstance
end

local WriteInstance

WriteInstance = {
	Model = WithAttributes(CreateInstanceWriter(InstanceProperties.Model)),
	Folder = WithAttributes(CreateInstanceWriter(InstanceProperties.Folder)),
	Part = WithAttributes(CreateInstanceWriter(InstanceProperties.Part)),
	PartNoAttributes = CreateInstanceWriter(InstanceProperties.Part),
	BoolValue = WithAttributes(CreateInstanceWriter(InstanceProperties.BoolValue)),
	WedgePart = CreateInstanceWriter(InstanceProperties.WedgePart),
	StringValue = CreateInstanceWriter(InstanceProperties.StringValue),
	MeshPart = WithAttributes(CreateInstanceWriter(InstanceProperties.MeshPart)),
	UnionOperation = WithAttributes(CreateInstanceWriter(InstanceProperties.UnionOperation)),
	Texture = CreateInstanceWriter(InstanceProperties.Texture),
	BlockMesh = CreateInstanceWriter(InstanceProperties.BlockMesh),
	PointLight = CreateInstanceWriter(InstanceProperties.PointLight),
	SpotLight = CreateInstanceWriter(InstanceProperties.SpotLight),
	SurfaceLight = CreateInstanceWriter(InstanceProperties.SurfaceLight),
	SpecialMesh = CreateInstanceWriter(InstanceProperties.SpecialMesh),
	Decal = CreateInstanceWriter(InstanceProperties.Decal),
	Fire = CreateInstanceWriter(InstanceProperties.Fire),
	Smoke = CreateInstanceWriter(InstanceProperties.Smoke),
	Attachment = CreateInstanceWriter(InstanceProperties.Attachment),
	ParticleEmitter = CreateInstanceWriter(InstanceProperties.ParticleEmitter),
	Sparkles = CreateInstanceWriter(InstanceProperties.Sparkles),
	SurfaceGui = CreateInstanceWriter(InstanceProperties.SurfaceGui),
	ImageLabel = CreateInstanceWriter(InstanceProperties.ImageLabel),
	BillboardGui = CreateInstanceWriter(InstanceProperties.BillboardGui),
	Frame = CreateInstanceWriter(InstanceProperties.Frame),
	Beam = CreateInstanceWriter(InstanceProperties.Beam),
	Trail = CreateInstanceWriter(InstanceProperties.Trail),
}

return WriteInstance
