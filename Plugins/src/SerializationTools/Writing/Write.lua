local InstanceTypes = require(script.Parent.Parent.Types.InstanceTypes)
local WriteInstance = require(script.Parent.WriteInstance)

local EncodingService = game:GetService("EncodingService")

local WriteStats = require(script.Parent.Stats)
local FeatureCheck = require(script.Parent.Parent.Util.FeatureCheck)

local NotifMan = require(script.Parent.Parent.Util.Notifications.Manager)

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local Write

local function WriteMap(map, sizeFunc, primFunc)
	local mapStrArr = { sizeFunc(#map) }
	for _, v in ipairs(map) do
		mapStrArr[#mapStrArr + 1] = primFunc(v)
	end
	return table.concat(mapStrArr)
end

local ESCAPED_NEWLINES_ACTIVE = VersionConfig.ReplaceNewlines
local TAB_CHAR = utf8.char(9)

Write = {

	ColorMap = function(colorMap)
		return WriteMap(colorMap, Write.Primitive.ShortInt, Write.Primitive.Color3)
	end,

	StringMap = function(stringMap)
		return WriteMap(stringMap, Write.Primitive.ShortInt, Write.Primitive.String)
	end,

	VectorMap = function(vectorMap)
		if not VersionConfig.UseVectorMap then
			return ""
		else
			return WriteMap(vectorMap, Write.Primitive.LongInt, Write.Primitive.Vector3)
		end
	end,

	MissionCodeHeader = function(mapId, current, total)
		return table.concat{
			Write.Primitive.ShortestInt(VersionConfig.VersionNumber, true),
			Write.Primitive.ShortInt(mapId, true),
			Write.Primitive.ShortInt(current, true),
			Write.Primitive.ShortInt(total, true)
		}
	end,

	Mission = function(mission)
		WriteStats.reset()

		local str = ""

		local MissionSetup = require(mission:FindFirstChild("MissionSetup"):Clone())

		while mission:FindFirstChild("StringMissionSetup") do
			mission:FindFirstChild("StringMissionSetup"):Destroy()
		end
		while mission:FindFirstChild("TableMissionSetup") do
			mission:FindFirstChild("TableMissionSetup"):Destroy()
		end

		if MissionSetup.Colors == nil then
			NotifMan.Push({
				Title = "MissionSetup Error",
				Description = [[
								No Colors table was found in your MissionSetup!

								An empty one will be used as placeholder.
							]],
				Severity = "WARN",
			})
			MissionSetup.Colors = {}
		end

		-- setting Color3s into tables for encoding
		for i, v in pairs(MissionSetup.Colors) do
			MissionSetup.Colors[i] = { v.R, v.G, v.B }
		end

		local json = game:GetService("HttpService"):JSONEncode(MissionSetup)

		local TableMissionSetup = Instance.new("StringValue")
		TableMissionSetup.Name = "TableMissionSetup"
		TableMissionSetup.Value = json
		TableMissionSetup.Parent = mission

		local StringMissionSetup = Instance.new("StringValue")
		StringMissionSetup.Name = "StringMissionSetup"
		StringMissionSetup.Value = mission:FindFirstChild("MissionSetup").Source
		StringMissionSetup.Parent = mission

		for _, subModule in mission.MissionSetup:GetChildren() do
			if subModule:IsA("ModuleScript") then
				local ExtraModuleSource = Instance.new("StringValue")
				ExtraModuleSource.Name = subModule.Name
				ExtraModuleSource.Value = subModule.Source
				ExtraModuleSource.Parent = StringMissionSetup
			end
		end

		-- Numeric index so as to not have the size collide with existing values
		local colorMap = { [0] = 0 }
		local stringMap = { [0] = 0 }
		local vectorMap = { [0] = 0 }

		local maps = {
			Color = colorMap,
			String = stringMap,
			Vector = vectorMap
		}

		str, maps = Write.Instance(mission, maps)

		colorMap[0] = nil
		stringMap[0] = nil
		vectorMap[0] = nil

		local colorMapArr = {}
		local stringMapArr = {}
		local vectorMapArr = {}

		for colHex, colidx in pairs(colorMap) do
			colorMapArr[colidx] = Color3.fromHex(colHex)
		end

		for str, stridx in pairs(stringMap) do
			stringMapArr[stridx] = str
		end

		for vec, vecidx in pairs(vectorMap) do
			vectorMapArr[vecidx] = vec
		end

		local colorMapStr = Write.ColorMap(colorMapArr)
		local stringMapStr = Write.StringMap(stringMapArr)
		local vectorMapStr = Write.VectorMap(vectorMapArr)

		local missionStr = colorMapStr .. stringMapStr .. vectorMapStr .. str

		if not VersionConfig.UseCompression then
			return missionStr
		end

		local compressLevel = FeatureCheck("SerializerCompressionLevel", false)

		if type(compressLevel) ~= "number" then
			if type(compressLevel) ~= "nil" then
				warn(
					`SerializerCompressionLevel : Expected int|nil, got {type(compressLevel)} {compressLevel}! Will use default of 4`
				)
			end
			compressLevel = 4
		end

		local inputCompressLevel = compressLevel
		compressLevel = math.round(compressLevel)
		if compressLevel ~= inputCompressLevel then
			warn(
				`SerializerCompressionLevel : Expected integer from range -7 <-> 22 inclusive, got {inputCompressLevel}! Will use rounded value of {compressLevel}`
			)
		end

		inputCompressLevel = compressLevel
		compressLevel = math.clamp(compressLevel, -7, 22)

		if compressLevel ~= inputCompressLevel then
			warn(
				`SerializerCompressionLevel : Expected integer from range -7 <-> 22 inclusive, got {inputCompressLevel}! Will use clamped value of {compressLevel}`
			)
		end

		local buf = buffer.create(#missionStr)
		buffer.writestring(buf, 0, missionStr)

		local compressedBuf = EncodingService:Base64Encode(
			EncodingService:CompressBuffer(buf, Enum.CompressionAlgorithm.Zstd, compressLevel)
		)

		local compressedStr = buffer.readstring(compressedBuf, 0, buffer.len(compressedBuf))

		if FeatureCheck("SerializerCompressionStats") == true then
			print(`=== Compression Stats ===`)
			print(`Before Compression: {#missionStr * 0.001}K`)
			print(`After Compression: {#compressedStr * 0.001}K`)
		end

		if FeatureCheck("SerializerDebug", false) == true then
			WriteStats.output()
		end

		return compressedStr
	end,

	Instance = function(object, maps)
		local className = object.ClassName
		if InstanceTypes[object.ClassName] ~= nil then
			if next(object:GetAttributes()) == nil and object.ClassName == "Part" then
				className = className .. "NoAttributes"
			end
			local instanceType = Write.Primitive.ShortestInt(InstanceTypes[className])
			local objectProperties, maps = WriteInstance[className](object, maps)
			local childrenProperties = ""
			for i, v in pairs(object:GetChildren()) do
				childrenProperties = childrenProperties .. Write.Instance(v, maps)
			end
			return instanceType .. objectProperties .. childrenProperties .. Write.Primitive.ShortestInt(0), maps
		else
			return Write.Primitive.ShortestInt(InstanceTypes.Nil), maps
		end
	end,

	Primitive = require(script.Parent.WritePrimitive)
}

-- Debugging code for writing changes, should never be invoked in finalised builds
setmetatable(
	Write,
	{
		__index = function(self, k)
			warn(`Serializer Dev Warn: Attempt to index write with key {k}`)

			local e = self.Primitive[k]
			if e ~= nil then
				warn(`\tIt's likely you meant Write.Primitive.{k}`)
				return e
			end

			error(`Serializer Dev Error: Attempt to index write for unsupported type {k}`)
		end,
	}
)

return Write
