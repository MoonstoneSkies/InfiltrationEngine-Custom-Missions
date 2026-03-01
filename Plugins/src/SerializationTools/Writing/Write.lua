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

local IndexCache = {}

local function GetIndex(object)
	if IndexCache[object] then
		return IndexCache[object]
	end
	
	local parent = object.Parent
	if not parent then return 1 end

	local children = parent:GetChildren()
	local index = 1
	for _, child in children do
		if WriteInstance[child.ClassName] then -- Ignore unserialized instances
			IndexCache[child] = index
			index += 1
		end
	end
	
	return IndexCache[object] or 1
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
		local sequenceBuffer = { Write.ShortInt(#keypoints) }
		for i, v in pairs(keypoints) do
			table.insert(sequenceBuffer, Write.ShortBoundedFloat(v.Time))
			table.insert(sequenceBuffer, Write.Float(v.Value))
			table.insert(sequenceBuffer, Write.Float(v.Envelope))
		end
		return table.concat(sequenceBuffer)
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
		local sequenceBuffer = { Write.ShortInt(#keypoints) }
		for i, v in pairs(keypoints) do
			table.insert(sequenceBuffer, Write.ShortBoundedFloat(v.Time))
			table.insert(sequenceBuffer, Write.Color3(v.Value))
		end
		return table.concat(sequenceBuffer)
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
		local pathStr = table.concat(path, `.`)
		return Write.Int(#pathStr) .. pathStr
	end,

	ColorMap = function(colorMap)
		local mapBuffer = {}
		for i, v in pairs(colorMap) do
			table.insert(mapBuffer, Write.Color3(v))
		end
		return Write.ShortInt(#colorMap) .. table.concat(mapBuffer)
	end,

	StringMap = function(stringMap)
		local mapBuffer = {}
		for i, v in pairs(stringMap) do
			table.insert(mapBuffer, Write.String(v))
		end
		return Write.ShortInt(#stringMap) .. table.concat(mapBuffer)
	end,

	MissionCodeHeader = function(mapId, current, total)
		local header = Write.ShortestInt(VersionConfig.VersionNumber)
		header = header .. Write.ShortInt(mapId)
		header = header .. Write.ShortInt(current)
		header = header .. Write.ShortInt(total)
		return header
	end,

	Mission = function(mission)
		local str
		table.clear(IndexCache)

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

		for stringValue, stridx in pairs(stringMap) do
			stringMapArr[stridx] = stringValue
		end

		local colorMapStr = Write.ColorMap(colorMapArr)
		local stringMapStr = Write.StringMap(stringMapArr)

		return colorMapStr .. stringMapStr .. str
	end,

	Instance = function(object, colorMap, stringMap, buffer)
		local returnStr = false
		if buffer == nil then
			buffer = {}
			returnStr = true
		end

		local className = object.ClassName
		if InstanceTypes[object.ClassName] ~= nil then
			if next(object:GetAttributes()) == nil and object.ClassName == "Part" then
				className = className .. "NoAttributes"
			end
			local instanceType = StringConversion.NumberToString(InstanceTypes[className], 1)
			table.insert(buffer, instanceType)
			
			colorMap, stringMap = WriteInstance[className](object, Write, colorMap, stringMap, buffer)
			for i, v in pairs(object:GetChildren()) do
				colorMap, stringMap = Write.Instance(v, colorMap, stringMap, buffer)
			end
			table.insert(buffer, StringConversion.NumberToString(0, 1))
			
			if returnStr then
				return table.concat(buffer), colorMap, stringMap
			else
				return colorMap, stringMap
			end
		else
			table.insert(buffer, StringConversion.NumberToString(InstanceTypes.Nil, 1))
			if returnStr then
				return table.concat(buffer), colorMap, stringMap
			else
				return colorMap, stringMap
			end
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
