local StringConversion = require(script.Parent.Parent.StringConversion)
local InstanceTypes = require(script.Parent.Parent.Types.InstanceTypes)
local ReadInstance = require(script.Parent.ReadInstance)

local EnumTypes = require(script.Parent.Parent.Types.Enums.Main)

local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local SIGNED_INT_BOUND = StringConversion.GetMaxNumber(3) / 2
local INT_BOUND = StringConversion.GetMaxNumber(4)
local BOUNDED_FLOAT_BOUND = StringConversion.GetMaxNumber(3)
local SHORT_BOUNDED_FLOAT_BOUND = StringConversion.GetMaxNumber(2)

local Read

local denormalize = function(value)
	return value * (2 * math.pi) - math.pi
end

local InstanceKeys = {}
for i, v in pairs(InstanceTypes) do
	InstanceKeys[v] = i
end

local function CreateEnumReader(enum, map)
	local ids = {}
	for i, v in map do
		ids[v] = i
	end
	return function(str, cursor)
		local num = StringConversion.StringToNumber(str, cursor, 1)
		return enum[ids[num]], cursor + 1
	end
end

local function NewlineGSub(capture)
	if capture == "&n" then
		return "\n"
	elseif capture == "&r" then
		return "\r"
	elseif capture == "&t" then
		return utf8.char(9)
	end
	return "&"
end

Read = {
	Bool = function(str, cursor) -- returns the value read as a boolean. 1 symbol
		return string.sub(str, cursor, cursor) == "b", cursor + 1
	end,

	ShortestInt = function(str, cursor) -- returns the value read as a shortest int. 1 symbol
		return StringConversion.StringToNumber(str, cursor, 1), cursor + 1
	end,

	ShortInt = function(str, cursor) -- returns the value read as a short integer. 2 symbols
		return StringConversion.StringToNumber(str, cursor, 2), cursor + 2
	end,

	Int = function(str, cursor) -- returns the value read as an integer. 4 symbols
		return StringConversion.StringToNumber(str, cursor, 4), cursor + 4
	end,

	LongInt = function(str, cursor) -- returns the value read as an integer. 6 symbols
		return StringConversion.StringToNumber(str, cursor, 6), cursor + 6
	end,

	SignedInt = function(str, cursor) -- returns the value read as a signed integer. 3 symbols
		return StringConversion.StringToNumber(str, cursor, 3) - math.floor(SIGNED_INT_BOUND), cursor + 3
	end,

	Float = function(str, cursor) -- returns the value read as a float. 5 symbols
		local beforeDecimal, cursor = Read.SignedInt(str, cursor)
		local afterDecimal = StringConversion.StringToNumber(str, cursor, 2) / SHORT_BOUNDED_FLOAT_BOUND
		return afterDecimal + beforeDecimal, cursor + 2
	end,

	FloatRange = function(str, cursor)
		local rangeVec
		rangeVec, cursor = Read.Vector2(str, cursor)
		return NumberRange.new(rangeVec.X, rangeVec.Y), cursor
	end,

	FloatSequence = function(str, cursor)
		local numberSequenceKeypoints = {}
		local numberSequenceLength, time, number, envelope
		numberSequenceLength, cursor = Read.ShortInt(str, cursor)
		for i = 1, numberSequenceLength do
			time, cursor = Read.ShortBoundedFloat(str, cursor)
			number, cursor = Read.Float(str, cursor)
			envelope, cursor = Read.Float(str, cursor)
			numberSequenceKeypoints[i] = NumberSequenceKeypoint.new(time, number, envelope)
		end
		return NumberSequence.new(numberSequenceKeypoints), cursor
	end,

	Vector2 = function(str, cursor)
		local X, cursor = Read.Float(str, cursor)
		local Y, cursor = Read.Float(str, cursor)
		return Vector2.new(X, Y), cursor
	end,

	Vector3 = function(str, cursor) -- returns the value read as a Vector3. 24 symbols
		local X, cursor = Read.Float(str, cursor)
		local Y, cursor = Read.Float(str, cursor)
		local Z, cursor = Read.Float(str, cursor)
		return Vector3.new(X, Y, Z), cursor
	end,

	UDim = function(str, cursor)
		local udimVec
		udimVec, cursor = Read.Vector2(str, cursor)
		return UDim.new(udimVec.X, udimVec.Y), cursor
	end,

	UDim2 = function(str, cursor)
		local xUdim, yUdim
		xUdim, cursor = Read.UDim(str, cursor)
		yUdim, cursor = Read.UDim(str, cursor)
		return UDim2.new(xUdim, yUdim), cursor
	end,

	CFrame = function(str, cursor) -- returns the value read as a CFrame. 36 symbols
		local X, cursor = Read.Float(str, cursor)
		local Y, cursor = Read.Float(str, cursor)
		local Z, cursor = Read.Float(str, cursor)
		local rx, cursor = Read.BoundedFloat(str, cursor)
		rx = denormalize(rx)
		local ry, cursor = Read.BoundedFloat(str, cursor)
		ry = denormalize(ry)
		local rz, cursor = Read.BoundedFloat(str, cursor)
		rz = denormalize(rz)
		return CFrame.new(X, Y, Z) * CFrame.fromEulerAnglesXYZ(rx, ry, rz), cursor
	end,

	BoundedFloat = function(str, cursor) -- returns the value read as a bounded float between 0-1. 3 symbols.
		return StringConversion.StringToNumber(str, cursor, 3) / BOUNDED_FLOAT_BOUND, cursor + 3
	end,

	ShortBoundedFloat = function(str, cursor) -- returns the value read as a bounded float between 0-1. 4 symbols.
		return StringConversion.StringToNumber(str, cursor, 2) / SHORT_BOUNDED_FLOAT_BOUND, cursor + 2
	end,

	Color3 = function(str, cursor)
		local R, cursor = Read.ShortBoundedFloat(str, cursor)
		local G, cursor = Read.ShortBoundedFloat(str, cursor)
		local B, cursor = Read.ShortBoundedFloat(str, cursor)
		return Color3.new(R, G, B), cursor
	end,

	ColorSequence = function(str, cursor)
		local colorSequenceKeypoints = {}
		local colorSequenceLength, cursor = Read.ShortInt(str, cursor)
		-- The ColorSequence array constructor only accepts an array with 2+ indicies.
		if colorSequenceLength == 1 then
			local _, cursor = Read.ShortBoundedFloat(str, cursor)
			local color, cursor = Read.Color3(str, cursor)
			return ColorSequence.new(color), cursor
		end
		local time, color
		for i = 1, colorSequenceLength do
			time, cursor = Read.ShortBoundedFloat(str, cursor)
			color, cursor = Read.Color3(str, cursor)
			colorSequenceKeypoints[i] = ColorSequenceKeypoint.new(time, color)
		end
		return ColorSequence.new(colorSequenceKeypoints), cursor
	end,

	ColorMap = function(str, cursor)
		local colorMap = {}
		local colorMapLength
		colorMapLength, cursor = Read.ShortInt(str, cursor)
		for i = 1, colorMapLength do
			colorMap[i], cursor = Read.Color3(str, cursor)
		end
		return colorMap, cursor
	end,

	String = function(str, cursor)
		local length, cursor = Read.Int(str, cursor)
		local value = str:sub(cursor, cursor + length - 1)

		if VersionConfig.ReplaceNewlines then
			value = value:gsub("&.", NewlineGSub)
		end

		return value, cursor + length
	end,

	StringMap = function(str, cursor)
		local stringMap = {}
		local stringMapLength
		stringMapLength, cursor = Read.ShortInt(str, cursor)
		for i = 1, stringMapLength do
			stringMap[i], cursor = Read.String(str, cursor)
		end
		return stringMap, cursor
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
		}, cursor
	end,

	Mission = function(str, cursor)
		if str:sub(1, 3) == "!!!" then
			local code = str:match("!!!.-!!!(.+)")
			if not code then
				error("Malformed opening comment")
			end
			str = code
		end

		local colorMap
		colorMap, cursor = Read.ColorMap(str, cursor)
		local stringMap
		stringMap, cursor = Read.StringMap(str, cursor)
		local mission = Read.Instance(str, cursor, colorMap, stringMap)

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
		end

		return mission
	end,

	Instance = function(str, cursor, colorMap, stringMap)
		local InstanceId = StringConversion.StringToNumber(str, cursor, 1)
		cursor += 1
		if InstanceId ~= InstanceTypes.Nil then
			local InstanceType = InstanceKeys[InstanceId]
			local object, cursor = ReadInstance[InstanceType](str, cursor, Read, colorMap, stringMap)
			while StringConversion.StringToNumber(str, cursor, 1) ~= 0 do
				local child
				child, cursor = Read.Instance(str, cursor, colorMap, stringMap)
				if child ~= nil then
					child.Parent = object
				end
			end
			return object, cursor + 1
		else
			return nil, cursor
		end
	end,

	Material = CreateEnumReader(Enum.Material, EnumTypes.Materials),
	PartType = CreateEnumReader(Enum.PartType, EnumTypes.PartTypes),
	NormalId = CreateEnumReader(Enum.NormalId, EnumTypes.NormalId),

	MeshType = CreateEnumReader(Enum.MeshType, EnumTypes.MeshType),
	RenderFidelity = CreateEnumReader(Enum.RenderFidelity, EnumTypes.RenderFidelity),
	CollisionFidelity = CreateEnumReader(Enum.CollisionFidelity, EnumTypes.CollisionFidelity),

	ParticleEmitterShape = CreateEnumReader(Enum.ParticleEmitterShape, EnumTypes.ParticleEmitterShape),
	ParticleEmitterShapeInOut = CreateEnumReader(Enum.ParticleEmitterShapeInOut, EnumTypes.ParticleEmitterShapeInOut),
	ParticleEmitterShapeStyle = CreateEnumReader(Enum.ParticleEmitterShapeStyle, EnumTypes.ParticleEmitterShapeStyle),
	ParticleOrientation = CreateEnumReader(Enum.ParticleOrientation, EnumTypes.ParticleOrientation),

	ResamplerMode = CreateEnumReader(Enum.ResamplerMode, EnumTypes.ResamplerMode),
	SurfaceGuiSizingMode = CreateEnumReader(Enum.SurfaceGuiSizingMode, EnumTypes.SurfaceGuiSizingMode),
}

return Read
