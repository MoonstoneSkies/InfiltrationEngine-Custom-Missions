local InstanceTypes = require(script.Parent.Parent.Types.InstanceTypes)
local ReadInstance = require(script.Parent.ReadInstance)
local ReadMissionRoot = require(script.Parent.ReadMissionRoot)

local EncodingService = game:GetService("EncodingService")

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local Read

local function ReadMap(str, cursor, sizeFunc, primFunc)
	local n, v
	n, cursor = sizeFunc(str, cursor)
	
	local map = table.create(n)
	
	for i=1, n do
		v, cursor = primFunc(str, cursor)
		map[#map+1] = v
	end
	
	return map, cursor
end

local InstanceKeys = {}
for i, v in pairs(InstanceTypes) do
	InstanceKeys[v] = i
end

Read = {
	VectorMap = function(str, cursor)
		if not VersionConfig.UseVectorMap then return {}, cursor end
		return ReadMap(str, cursor, Read.Primitive.LongInt, Read.Primitive.Vector3)
	end,

	ColorMap = function(str, cursor)
		return ReadMap(str, cursor, Read.Primitive.ShortInt, Read.Primitive.Color3)
	end,

	StringMap = function(str, cursor)
		return ReadMap(str, cursor, Read.Primitive.ShortInt, Read.Primitive.String)
	end,

	MissionCodeHeader = function(str, cursor)
		local codeVersion, mapId, currentCode, totalCodes

		codeVersion, cursor = Read.ShortestInt(str, cursor)
		mapId, cursor = Read.ShortInt(str, cursor)
		currentCode, cursor = Read.ShortInt(str, cursor)
		totalCodes, cursor = Read.ShortInt(str, cursor)

		return {
			CodeVersion = codeVersion,
			CodeCurrent = currentCode,
			CodeTotal = totalCodes,
			MapId = mapId,
		},
			cursor
	end,

	Mission = function(str, cursor)
		
		if VersionConfig.UseCompression then
			local uncompressed = buffer.create(#str)
			buffer.writestring(uncompressed, 0, str)

			str = buffer.tostring(
				EncodingService:DecompressBuffer(
					EncodingService:Base64Decode(uncompressed),
					Enum.CompressionAlgorithm.Zstd
				)
			)
		end
		
		ReadMissionRoot:Set(nil)
		
		local colorMap, stringMap, vectorMap
		colorMap, cursor = Read.ColorMap(str, cursor)
		stringMap, cursor = Read.StringMap(str, cursor)
		vectorMap, cursor = Read.VectorMap(str, cursor)
		local mission = Read.Instance(str, cursor, colorMap, stringMap, vectorMap)

		-- Reading Color3s from TableMissionSetup
		local ImportedMissionSetup = game:GetService("HttpService")
			:JSONDecode(mission:FindFirstChild("TableMissionSetup").Value)

		for i, v in pairs(ImportedMissionSetup["Colors"]) do
			ImportedMissionSetup["Colors"][i] = Color3.new(v[1], v[2], v[3])
		end

		if game:GetService("RunService"):IsStudio() and not _G.Common then -- If the mission is read using the plugin, then create a MissionSetup ModuleScript
			local StringMissionSetup = mission:FindFirstChild("StringMissionSetup")
			local MissionSetup = Instance.new("ModuleScript")
			MissionSetup.Name = "MissionSetup"
			MissionSetup.Parent = mission
			MissionSetup.Source = StringMissionSetup.Value
			for _, subModule in StringMissionSetup:GetChildren() do
				local module = Instance.new("ModuleScript")
				module.Name = subModule.Name
				module.Parent = MissionSetup
				module.Source = subModule.Value
			end
		end
		
		ReadMissionRoot:Finalize()
		return mission
	end,

	Instance = function(str, cursor, colorMap, stringMap, vectorMap)
		local InstanceId = Read.Primitive.ShortestInt(str, cursor)
		cursor += 1
		if InstanceId ~= InstanceTypes.Nil then
			local InstanceType = InstanceKeys[InstanceId]
			local object, cursor = ReadInstance[InstanceType](str, cursor, colorMap, stringMap, vectorMap)
			
			ReadMissionRoot:TrySet(object)
			
			while Read.Primitive.ShortestInt(str, cursor) ~= 0 do
				local child
				child, cursor = Read.Instance(str, cursor, colorMap, stringMap, vectorMap)
				if child ~= nil then
					child.Parent = object
				end
			end
			return object, cursor + 1
		else
			return nil, cursor
		end
	end,

	Primitive = require(script.Parent.ReadPrimitive)
}

-- Debugging code for writing changes, should never be invoked in finalised builds
setmetatable(
	Read,
	{
		__index = function(self, k)
			warn(`Serializer Dev Warn: Attempt to index read with key {k}`)

			local e = self.Primitive[k]
			if e ~= nil then
				warn(`\tIt's likely you meant Read.Primitive.{k}`)
				return e
			end

			error(`Serializer Dev Error: Attempt to index read for unsupported type {k}`)
		end,
	}
)

return Read
