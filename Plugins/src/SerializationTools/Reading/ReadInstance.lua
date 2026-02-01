local InsertService = game:GetService("InsertService")

local ENABLE_ARBITRARY_MESHES = true

local StringConversion = require(script.Parent.Parent.StringConversion)
local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local DefaultProperties = require(script.Parent.Parent.Types.DefaultProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)

local AttributeKeys = {}
for i, v in pairs(AttributeTypes) do
	AttributeKeys[v] = i
end

local WithAttributes = function(DefaultReader)
	return function(str, cursor, Read, colorMap, stringMap)
		local newInstance
		newInstance, cursor = DefaultReader(str, cursor, Read, colorMap, stringMap)
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
			newInstance:SetAttribute(name, value)
			attributeId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
		end
		local attributes = newInstance:GetAttributes()
		attributes = AttributeValidation.Validate(newInstance.ClassName, newInstance.Name, attributes, true)
		for i, v in pairs(attributes) do
			newInstance:SetAttribute(i, v)
		end
		return newInstance, cursor
	end
end

local ReadInstance

local CreateInstanceReader = function(instanceType, properties)
	local defaults = DefaultProperties[instanceType]

	local InstanceReader = function(str, cursor, Read, colorMap, stringMap)
		local newInstance = Instance.new(instanceType)
		if defaults then
			for k, v in defaults do
				newInstance[k] = v
			end
		end
		for i, v in pairs(properties) do -- sets all Instance properties to their default values as defined in InstanceProperties.lua
			newInstance[v[1]] = v[3]
		end
		local propertyId = StringConversion.StringToNumber(str, cursor, 1)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			if valueType == "Color3" then
				local colorMapIndex
				colorMapIndex, cursor = Read.ShortInt(str, cursor)
				newInstance[typeName] = colorMap[colorMapIndex]
			elseif valueType == "String" then
				local stringMapIndex
				stringMapIndex, cursor = Read.ShortInt(str, cursor)
				newInstance[typeName] = stringMap[stringMapIndex]
			else
				local set, newCursor = Read[valueType](str, cursor)
				if typeof(set) == "function" then -- TODO: optimize this somehow because I doubt Cish will be a fan of checking if every single property value is a function
					cursor = newCursor
					task.spawn(function()
						newInstance[typeName] = set()
					end)
				else
					newInstance[typeName], cursor = set, newCursor
				end
			end
			propertyId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
		end
		return newInstance, cursor
	end
	return InstanceReader
end

local CachedUserMeshFolder = game.ReplicatedStorage:FindFirstChild("Assets")
if CachedUserMeshFolder then
	CachedUserMeshFolder = CachedUserMeshFolder:FindFirstChild("LoadedMeshes")
	if not CachedUserMeshFolder then
		CachedUserMeshFolder = Instance.new("Folder")
		CachedUserMeshFolder.Name = "LoadedMeshes"
		CachedUserMeshFolder.Parent = game.ReplicatedStorage.Assets
	end
end

local CreateProtectedInstanceReader = function(instanceType, properties)
	local defaults = DefaultProperties[instanceType]

	local InstanceReader = function(str, cursor, Read, colorMap, stringMap)
		local newProperties = {}
		if defaults then
			for k, v in defaults do
				newProperties[k] = v
			end
		end
		for i, v in pairs(properties) do -- sets all Instance properties to their default values as defined in InstanceProperties.lua
			newProperties[v[1]] = v[3]
		end
		local propertyId = StringConversion.StringToNumber(str, cursor, 1)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			if valueType == "Color3" then
				local colorMapIndex
				colorMapIndex, cursor = Read.ShortInt(str, cursor)
				newProperties[typeName] = colorMap[colorMapIndex]
			elseif valueType == "String" then
				local stringMapIndex
				stringMapIndex, cursor = Read.ShortInt(str, cursor)
				newProperties[typeName] = stringMap[stringMapIndex]
			else
				newProperties[typeName], cursor = Read[valueType](str, cursor)
			end
			propertyId = StringConversion.StringToNumber(str, cursor, 1)
			cursor += 1
		end

		local newInstance = Instance.new("Part")
		local instanceInitialized = false
		local meshId = newProperties.MeshId
		local id = meshId and newProperties.MeshId:match("%d+")
		if id and #id > 3 then
			meshId = id
		end
		newProperties.MeshId = nil

		local cachedMeshPart = meshId
			and (
				(
					game.ReplicatedStorage:FindFirstChild("Assets")
					and game.ReplicatedStorage.Assets:FindFirstChild("ImportParts")
					and game.ReplicatedStorage.Assets.ImportParts:FindFirstChild(meshId)
				) or (CachedUserMeshFolder and CachedUserMeshFolder:FindFirstChild(meshId))
			)
		if cachedMeshPart then
			newInstance = cachedMeshPart:Clone()
			newProperties.CollisionFidelity = nil
			newProperties.RenderFidelity = nil
			for k, v in newProperties do
				newInstance[k] = v
			end
			instanceInitialized = true
		elseif meshId and ENABLE_ARBITRARY_MESHES then
			-- CreateMeshPartAsync is likely less reliable than cloning, so prefer using ImportParts when possible
			local success, instOrReason = pcall(function()
				local part = InsertService:CreateMeshPartAsync(
					`rbxassetid://{meshId}`,
					newProperties["CollisionFidelity"] or Enum.CollisionFidelity.Default,
					newProperties["RenderFidelity"] or Enum.RenderFidelity.Automatic
				)
				if CachedUserMeshFolder then
					local copy = part:Clone()
					copy.Name = meshId
					copy.Parent = CachedUserMeshFolder
				end
				return part
			end)
			newProperties.CollisionFidelity = nil
			newProperties.RenderFidelity = nil
			if success then
				newInstance = instOrReason
				for k, v in newProperties do
					newInstance[k] = v
				end
				instanceInitialized = true
			end
		end

		if not instanceInitialized then
			for k, v in newProperties do
				pcall(function()
					newInstance[k] = v
				end)
			end
		end

		return newInstance, cursor
	end
	return InstanceReader
end

ReadInstance = {
	Model = WithAttributes(CreateInstanceReader("Model", InstanceProperties.Model)),
	Folder = WithAttributes(CreateInstanceReader("Folder", InstanceProperties.Folder)),
	Part = WithAttributes(CreateInstanceReader("Part", InstanceProperties.Part)),
	PartNoAttributes = CreateInstanceReader("Part", InstanceProperties.Part),
	BoolValue = WithAttributes(CreateInstanceReader("BoolValue", InstanceProperties.BoolValue)),
	WedgePart = CreateInstanceReader("WedgePart", InstanceProperties.WedgePart),
	StringValue = CreateInstanceReader("StringValue", InstanceProperties.StringValue),
	MeshPart = WithAttributes(CreateProtectedInstanceReader("MeshPart", InstanceProperties.MeshPart)),
	UnionOperation = WithAttributes(CreateProtectedInstanceReader("UnionOperation", InstanceProperties.UnionOperation)),
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
