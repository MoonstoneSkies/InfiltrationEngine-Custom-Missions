local InsertService = game:GetService("InsertService")

local ENABLE_ARBITRARY_MESHES = true

local InstanceProperties = require(script.Parent.Parent.Types.InstanceProperties)
local DefaultProperties = require(script.Parent.Parent.Types.DefaultProperties)
local AttributeTypes = require(script.Parent.Parent.Types.AttributeTypes)
local AttributeValidation = require(script.Parent.Parent.AttributeValidation)

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local ReadPrimitive = require(script.Parent.ReadPrimitive)

local AttributeKeys = {}
for i, v in pairs(AttributeTypes) do
	AttributeKeys[v] = i
end

local function readCFrame(str, cursor, vectorMap)
	local pIdx, cursor = ReadPrimitive.LongInt(str, cursor)
	local xIdx, cursor = ReadPrimitive.LongInt(str, cursor)
	local yIdx, cursor = ReadPrimitive.LongInt(str, cursor)
	
	local pos  = vectorMap[pIdx]
	local xVec = vectorMap[xIdx]
	local yVec = vectorMap[yIdx]
	
	return CFrame.fromMatrix(pos, xVec, yVec), cursor
end

local function readValue(str, cursor, vType, colorMap, stringMap, vectorMap, refHandler)
	local value
	if vType == "Color3" then
		local colorMapIndex
		colorMapIndex, cursor = ReadPrimitive.ShortInt(str, cursor)
		value = colorMap[colorMapIndex]
	elseif vType == "String" then
		local valueMapIndex
		valueMapIndex, cursor = ReadPrimitive.ShortInt(str, cursor)
		value = stringMap[valueMapIndex]
	elseif vType == "Vector3" and VersionConfig.UseVectorMap then
		local vecMapIndex
		vecMapIndex, cursor = ReadPrimitive.LongInt(str, cursor)
		value = vectorMap[vecMapIndex]
	elseif vType == "CFrame" and VersionConfig.UseVectorMap then
		value, cursor = readCFrame(str, cursor, vectorMap)
	elseif vType == "InstanceReference" and refHandler ~= nil then
		local set
		set, cursor = ReadPrimitive[vType](str, cursor)
		task.spawn(refHandler, set)
	else
		value, cursor = ReadPrimitive[vType](str, cursor)
	end
	return value, cursor
end

local WithAttributes = function(DefaultReader)
	return function(str, cursor, colorMap, stringMap, vectorMap)
		local newInstance
		newInstance, cursor = DefaultReader(str, cursor, colorMap, stringMap, vectorMap)
		local attributeId = ReadPrimitive.ShortestInt(str, cursor)
		cursor += 1
		while not (attributeId == 0) do
			local typeName = AttributeKeys[attributeId]
			local nameMapIndex
			nameMapIndex, cursor = ReadPrimitive.ShortInt(str, cursor)
			local name = stringMap[nameMapIndex]
			local value
			value, cursor = readValue(str, cursor, typeName, colorMap, stringMap, vectorMap)
			newInstance:SetAttribute(name, value)
			attributeId = ReadPrimitive.ShortestInt(str, cursor)
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

	local InstanceReader = function(str, cursor, colorMap, stringMap, vectorMap)
		local newInstance = Instance.new(instanceType)
		if defaults then
			for k, v in defaults do
				newInstance[k] = v
			end
		end
		for i, v in pairs(properties) do -- sets all Instance properties to their default values as defined in InstanceProperties.lua
			newInstance[v[1]] = v[3]
		end
		local propertyId = ReadPrimitive.ShortestInt(str, cursor)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			local value
			value, cursor = readValue(str, cursor, valueType, colorMap, stringMap, vectorMap, function(setter)
				newInstance[typeName] = setter()
			end)
			if value ~= nil then newInstance[typeName] = value end
			propertyId = ReadPrimitive.ShortestInt(str, cursor)
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

	local InstanceReader = function(str, cursor, colorMap, stringMap, vectorMap)
		local newProperties = {}
		if defaults then
			for k, v in defaults do
				newProperties[k] = v
			end
		end
		for i, v in pairs(properties) do -- sets all Instance properties to their default values as defined in InstanceProperties.lua
			newProperties[v[1]] = v[3]
		end
		local propertyId = ReadPrimitive.ShortestInt(str, cursor)
		cursor += 1
		while not (propertyId == 0) do
			local typeName = properties[propertyId][1]
			local valueType = properties[propertyId][2]
			newProperties[typeName], cursor = readValue(str, cursor, valueType, colorMap, stringMap, vectorMap)
			propertyId = ReadPrimitive.ShortestInt(str, cursor)
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
	Model            = WithAttributes(         CreateInstanceReader("Model", InstanceProperties.Model)),
	Folder           = WithAttributes(         CreateInstanceReader("Folder", InstanceProperties.Folder)),
	Part             = WithAttributes(         CreateInstanceReader("Part", InstanceProperties.Part)),
	PartNoAttributes =                         CreateInstanceReader("Part", InstanceProperties.Part),
	BoolValue        = WithAttributes(         CreateInstanceReader("BoolValue", InstanceProperties.BoolValue)),
	WedgePart        =                         CreateInstanceReader("WedgePart", InstanceProperties.WedgePart),
	StringValue      =                         CreateInstanceReader("StringValue", InstanceProperties.StringValue),
	MeshPart         = WithAttributes(CreateProtectedInstanceReader("MeshPart", InstanceProperties.MeshPart)),
	UnionOperation   = WithAttributes(CreateProtectedInstanceReader("UnionOperation", InstanceProperties.UnionOperation)),
	Texture          =                         CreateInstanceReader("Texture", InstanceProperties.Texture),
	BlockMesh        =                         CreateInstanceReader("BlockMesh", InstanceProperties.BlockMesh),
	PointLight       =                         CreateInstanceReader("PointLight", InstanceProperties.PointLight),
	SpotLight        =                         CreateInstanceReader("SpotLight", InstanceProperties.SpotLight),
	SurfaceLight     =                         CreateInstanceReader("SurfaceLight", InstanceProperties.SurfaceLight),
	SpecialMesh      =                         CreateInstanceReader("SpecialMesh", InstanceProperties.SpecialMesh),
	Decal            =                         CreateInstanceReader("Decal", InstanceProperties.Decal),
	Fire             =                         CreateInstanceReader("Fire", InstanceProperties.Fire),
	Smoke            =                         CreateInstanceReader("Smoke", InstanceProperties.Smoke),
	Attachment       =                         CreateInstanceReader("Attachment", InstanceProperties.Attachment),
	ParticleEmitter  =                         CreateInstanceReader("ParticleEmitter", InstanceProperties.ParticleEmitter),
	Sparkles         =                         CreateInstanceReader("Sparkles", InstanceProperties.Sparkles),
	SurfaceGui       =                         CreateInstanceReader("SurfaceGui", InstanceProperties.SurfaceGui),
	ImageLabel       =                         CreateInstanceReader("ImageLabel", InstanceProperties.ImageLabel),
	BillboardGui     =                         CreateInstanceReader("BillboardGui", InstanceProperties.BillboardGui),
	Frame            =                         CreateInstanceReader("Frame", InstanceProperties.Frame),
	Beam             =                         CreateInstanceReader("Beam", InstanceProperties.Beam),
	Trail            =                         CreateInstanceReader("Trail", InstanceProperties.Trail),
}

return ReadInstance
