local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local WriteStats = require(script.Parent.Stats)

local function lookupMapIndex(map, value)
	-- Vectors are supported here without any special casing due to a quirk of roblox lua
	-- Wherein the "Vector3" roblox datatype corresponds to the "vector" value type
	-- This is done for optimisation of vector maths, to my understanding, but it also leads to our desired value semantics
	-- I.e. tbl[Vector3.one] == tbl[Vector3.new(1, 1, 1)]
	if value == nil then
		return 0
	end
	if typeof(value) == "Color3" then
		value = value:ToHex()
	end
	local idx = map[value]
	if idx == nil then
		WriteStats:inc("LookupMap_Misses")
		idx = (map[0] + 1) -- Size + 1
		map[value] = idx
		map[0] = idx -- Update size
	else
		WriteStats:inc("LookupMap_Hits")
	end
	return idx
end

local function lookupMapCFrame(map, cfr)
	local i1, i2, i3
	local xVec = cfr.XVector
	local yVec = cfr.YVector
	
	i1 = lookupMapIndex(map, cfr.Position)
	i2 = lookupMapIndex(map, xVec)
	i3 = lookupMapIndex(map, yVec)
	return i1, i2, i3
end

local function representValue(write, v, vType, colorMap, stringMap, vectorMap)
	local valStr
	if vType == "Color3" then
		local index = lookupMapIndex(colorMap, v)
		valStr = write.ShortInt(index)
	elseif vType == "String" then
		local index = lookupMapIndex(stringMap, v)
		valStr = write.ShortInt(index)
	elseif vType == "Vector3" and VersionConfig.UseVectorMap then
		local index = lookupMapIndex(vectorMap, v)
		valStr = write.LongInt(index)
	elseif vType == "CFrame" and VersionConfig.UseVectorMap then
		local i1, i2, i3 = lookupMapCFrame(vectorMap, v)
		valStr = write.LongInt(i1) .. write.LongInt(i2) .. write.LongInt(i3)
	else
		valStr = write[vType](v)
	end
	return valStr
end

local WithAttributes = function(DefaultWriter)
	return function(object, Write, colorMap, stringMap, vectorMap)
		local str = DefaultWriter(object, Write, colorMap, stringMap, vectorMap)
		local attributes = object:GetAttributes()
		attributes = AttributeValidation.Validate(object.ClassName, object.Name, attributes, false)
		local attString = ""

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
			attString = attString
				.. StringConversion.NumberToString(AttributeTypes[attributeType], 1)
				.. Write.ShortInt(index)
				.. representValue(Write, v, attributeType, colorMap, stringMap, vectorMap)
			
		end
		str = str .. attString .. StringConversion.NumberToString(0, 1)
		return str, colorMap, stringMap, vectorMap
	end
end

local CreateInstanceWriter = function(properties)
	local WriteInstance = function(object, Write, colorMap, stringMap, vectorMap)
		local str = ""
		for i, v in pairs(properties) do
			local value
			if v[1] == "MeshId" and object.ClassName == "UnionOperation" then
				value = object:GetAttribute("MeshId")
			else
				value = object[v[1]]
			end
			local valueType = v[2]
			local defaultValue = v[3]
			
			if value == defaultValue then continue end
			
			str = str .. StringConversion.NumberToString(i, 1) .. representValue(Write, value, valueType, colorMap, stringMap, vectorMap)
		end

		str = str .. StringConversion.NumberToString(0, 1)
		return str, colorMap, stringMap, vectorMap
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
