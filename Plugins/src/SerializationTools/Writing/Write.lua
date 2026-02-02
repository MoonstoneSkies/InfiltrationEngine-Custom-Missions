local StringConversion = require(script.Parent.Parent.StringConversion)
local InstanceTypes = require(script.Parent.Parent.Types.InstanceTypes)
local WriteInstance = require(script.Parent.WriteInstance)

local EnumTypes = require(script.Parent.Parent.Types.Enums.Main)

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local Write

local SHORTEST_INT_BOUND = StringConversion.GetMaxNumber(1)
local SHORT_INT_BOUND = StringConversion.GetMaxNumber(2)
local INT_BOUND = StringConversion.GetMaxNumber(4)
local LONG_INT_BOUND = StringConversion.GetMaxNumber(6)
local SIGNED_INT_BOUND = math.floor(StringConversion.GetMaxNumber(3) / 2)
local BOUNDED_FLOAT_BOUND = StringConversion.GetMaxNumber(3)
local SHORT_BOUNDED_FLOAT_BOUND = math.floor(StringConversion.GetMaxNumber(2))

local normalize = function(value) -- normalizes an angle in radians (from -pi to pi) to 0-1
	return (value + math.pi) / (math.pi * 2)
end

local function CreateEnumWriter(keys)
	return function(value)
		local index = keys[value.Name] or 1
		return StringConversion.NumberToString(index, 1)
	end
end

local function GetIndex(object)
	local parent = object.Parent
	local children = parent:GetChildren()
	
	local index
	for i,v in (children) do
		if not WriteInstance[v.ClassName] then -- Clear out unserialized instances to not break order during mission loading
			table.remove(children, table.find(children, v))
		end
	end
	
	for i,v in (children) do
		if v == object then
			index = i
			break
		end
	end
	
	return index
end

local ESCAPED_NEWLINES_ACTIVE = VersionConfig.ReplaceNewlines
local TAB_CHAR = utf8.char(9)

Write = {
	Bool = function(bool) -- 1 character
		return if bool then "b" else "c"
	end,

	ShortestInt = function(num) -- 1 character
		num = math.clamp(num, 0, SHORTEST_INT_BOUND)
		return StringConversion.NumberToString(num, 1)
	end,

	ShortInt = function(num) -- 2 characters
		if num > SHORT_INT_BOUND then
			return StringConversion.NumberToString(SHORT_INT_BOUND, 2)
		elseif num < 0 then
			return StringConversion.NumberToString(0, 2)
		else
			return StringConversion.NumberToString(num, 2)
		end
	end,

	Int = function(num) -- 4 characters
		if num > INT_BOUND then
			warn("Int out of bounds range:", num)
			return StringConversion.NumberToString(INT_BOUND, 4)
		elseif num < 0 then
			warn("Int out of bounds range:", num)
			return StringConversion.NumberToString(0, 4)
		else
			return StringConversion.NumberToString(num, 4)
		end
	end,

	LongInt = function(num) -- 6 characters
		if num > LONG_INT_BOUND then
			warn("Int out of bounds range:", num)
			return StringConversion.NumberToString(LONG_INT_BOUND, 6)
		elseif num < 0 then
			warn("Int out of bounds range:", num)
			return StringConversion.NumberToString(0, 6)
		else
			return StringConversion.NumberToString(num, 6)
		end
	end,

	SignedInt = function(num) -- 3 characters
		if num > SIGNED_INT_BOUND then
			return StringConversion.NumberToString(SIGNED_INT_BOUND * 2, 3)
		elseif num < SIGNED_INT_BOUND * -1 then
			return StringConversion.NumberToString(0, 3)
		else
			return StringConversion.NumberToString(num + SIGNED_INT_BOUND, 3)
		end
	end,

	Float = function(num) -- 5 characters, 3 before decimal, 2 after
		local beforeDecimalStr = Write.SignedInt(math.floor(num))
		local afterDecimalStr =
			StringConversion.NumberToString(math.round((num - math.floor(num)) * SHORT_INT_BOUND), 2)
		return beforeDecimalStr .. afterDecimalStr
	end,

	FloatRange = function(numberRange) -- Vector2 wrapper
		return Write.Vector2(Vector2.new(numberRange.Min, numberRange.Max))
	end,

	FloatSequence = function (numberSequence) -- 2 + 7 * keypoints characters
		local keypoints = numberSequence.Keypoints
		local numberSequenceStr = Write.ShortInt(#keypoints)
		for i, v in pairs(keypoints) do
			numberSequenceStr = numberSequenceStr .. Write.ShortBoundedFloat(v.Time) .. Write.Float(v.Value) .. Write.Float(v.Envelope)
		end
		return numberSequenceStr
	end,

	Vector2 = function(vector) -- 10 characters, 5 for each float XY
		return Write.Float(vector.X) .. Write.Float(vector.Y)
	end,

	Vector3 = function(vector) -- 15 characters, 5 per float XYZ
		return Write.Float(vector.X) .. Write.Float(vector.Y) .. Write.Float(vector.Z)
	end,

	UDim = function(udim)
		return Write.Vector2(Vector2.new(udim.Scale, udim.Offset))
	end,

	UDim2 = function(udim2)
		return Write.UDim(udim2.X) .. Write.UDim(udim2.Y)
	end,

	CFrame = function(frame) -- 24 characters, 15 for position, 9 for rotation
		local rx, ry, rz = frame:ToEulerAnglesXYZ()
		return Write.Float(frame.X)
			.. Write.Float(frame.Y)
			.. Write.Float(frame.Z)
			.. Write.BoundedFloat(normalize(rx))
			.. Write.BoundedFloat(normalize(ry))
			.. Write.BoundedFloat(normalize(rz))
	end,

	BoundedFloat = function(num) -- 3 characters
		if num > 1 then
			num = 1
		end
		if num < 0 then
			num = 0
		end
		return StringConversion.NumberToString(math.round(num * BOUNDED_FLOAT_BOUND), 3)
	end,

	ShortBoundedFloat = function(num) -- 2 characters
		if num > 1 then
			num = 1
		end
		if num < 0 then
			num = 0
		end
		return StringConversion.NumberToString(math.round(num * SHORT_BOUNDED_FLOAT_BOUND), 2)
	end,

	Color3 = function(color) -- 6 characters
		return Write.ShortBoundedFloat(color.R) .. Write.ShortBoundedFloat(color.G) .. Write.ShortBoundedFloat(color.B)
	end,

	ColorSequence = function (colorSequence) -- 2 + 8 * keypoints characters
		local keypoints = colorSequence.Keypoints
		local colorSequenceStr = Write.ShortInt(#keypoints)
		for i, v in pairs(keypoints) do
			colorSequenceStr = colorSequenceStr .. Write.ShortBoundedFloat(v.Time) .. Write.Color3(v.Value)
		end
		return colorSequenceStr
	end,

	String = function(str) -- 4 + length characters
		if ESCAPED_NEWLINES_ACTIVE then
			str = str:gsub("&", "&&"):gsub("\n", "&n"):gsub("\r", "&r"):gsub(TAB_CHAR, "&t")
		end
		return Write.Int(#str) .. str
	end,
	
	InstanceReference = function(object)
		local path = {}
		local current = object
		
		-- Get parent path
		while current and current.Parent and (current.Name ~= `DebugMission` and current ~= workspace) do
			local index = GetIndex(current)
			if index then
				table.insert(path, index)
			end
			current = current.Parent
		end
		
		-- Reverse order
		for i = 1, math.floor(#path / 2) do
			path[i], path[#path - i + 1] = path[#path - i + 1], path[i]
		end
		
		-- Concat
		path = table.concat(path, `.`)
		return Write.Int(#path) .. path
	end,

	ColorMap = function(colorMap)
		local colorStr = ""
		for i, v in pairs(colorMap) do
			colorStr = colorStr .. Write.Color3(v)
		end
		return Write.ShortInt(#colorMap) .. colorStr
	end,

	StringMap = function(stringMap)
		local stringStr = ""
		for i, v in pairs(stringMap) do
			stringStr = stringStr .. Write.String(v)
		end
		return Write.ShortInt(#stringMap) .. stringStr
	end,

	MissionCodeHeader = function(mapId, current, total)
		local header = Write.ShortestInt(VersionConfig.VersionNumber)
		header = header .. Write.ShortInt(mapId)
		header = header .. Write.ShortInt(current)
		header = header .. Write.ShortInt(total)
		return header
	end,

	Mission = function(mission)
		local str = ""

		local MissionSetup = require(mission:FindFirstChild("MissionSetup"):Clone())

		while mission:FindFirstChild("StringMissionSetup") do
			mission:FindFirstChild("StringMissionSetup"):Destroy()
		end
		while mission:FindFirstChild("TableMissionSetup") do
			mission:FindFirstChild("TableMissionSetup"):Destroy()
		end

		-- setting Color3s into tables for encoding
		for i, v in pairs(MissionSetup["Colors"]) do
			MissionSetup["Colors"][i] = { v.R, v.G, v.B }
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

		-- Numeric index so as to not have the size collide with existing values
		local colorMap = { [0] = 0 }
		local stringMap = { [0] = 0 }

		str, colorMap, stringMap = Write.Instance(mission, colorMap, stringMap)

		colorMap[0] = nil
		stringMap[0] = nil

		local colorMapArr = {}
		local stringMapArr = {}

		for colHex, colidx in pairs(colorMap) do
			colorMapArr[colidx] = Color3.fromHex(colHex)
		end

		for str, stridx in pairs(stringMap) do
			stringMapArr[stridx] = str
		end

		local colorMapStr = Write.ColorMap(colorMapArr)
		local stringMapStr = Write.StringMap(stringMapArr)

		return colorMapStr .. stringMapStr .. str
	end,

	Instance = function(object, colorMap, stringMap)
		local className = object.ClassName
		if InstanceTypes[object.ClassName] ~= nil then
			if next(object:GetAttributes()) == nil and object.ClassName == "Part" then
				className = className .. "NoAttributes"
			end
			local instanceType = StringConversion.NumberToString(InstanceTypes[className], 1)
			local objectProperties, colorMap, stringMap = WriteInstance[className](object, Write, colorMap, stringMap)
			local childrenProperties = ""
			for i, v in pairs(object:GetChildren()) do
				childrenProperties = childrenProperties .. Write.Instance(v, colorMap, stringMap)
			end
			return instanceType .. objectProperties .. childrenProperties .. StringConversion.NumberToString(0, 1),
			colorMap,
			stringMap
		else
			return StringConversion.NumberToString(InstanceTypes.Nil, 1), colorMap, stringMap
		end
	end,

	Material = CreateEnumWriter(EnumTypes.Materials),
	PartType = CreateEnumWriter(EnumTypes.PartTypes),
	NormalId = CreateEnumWriter(EnumTypes.NormalId),

	MeshType = CreateEnumWriter(EnumTypes.MeshType),
	RenderFidelity = CreateEnumWriter(EnumTypes.RenderFidelity),
	CollisionFidelity = CreateEnumWriter(EnumTypes.CollisionFidelity),

	ParticleEmitterShape = CreateEnumWriter(EnumTypes.ParticleEmitterShape),
	ParticleEmitterShapeInOut = CreateEnumWriter(EnumTypes.ParticleEmitterShapeInOut),
	ParticleEmitterShapeStyle = CreateEnumWriter(EnumTypes.ParticleEmitterShapeStyle),
	ParticleOrientation = CreateEnumWriter(EnumTypes.ParticleOrientation),

	ResamplerMode = CreateEnumWriter(EnumTypes.ResamplerMode),
	SurfaceGuiSizingMode = CreateEnumWriter(EnumTypes.SurfaceGuiSizingMode),

	TextureMode = CreateEnumWriter(EnumTypes.TextureMode),
}

return Write
