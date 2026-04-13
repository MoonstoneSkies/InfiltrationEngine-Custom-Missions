local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

local ReadMissionRoot = require(script.Parent.ReadMissionRoot)

local SIGNED_INT_BOUND = StringConversion.GetMaxNumber(3) / 2
local INT_BOUND = StringConversion.GetMaxNumber(4)
local BOUNDED_FLOAT_BOUND = StringConversion.GetMaxNumber(3)
local SHORT_BOUNDED_FLOAT_BOUND = StringConversion.GetMaxNumber(2)

local function NewlineGSub(capture)
	if capture == "&n" then
		return "\n"
	elseif capture == "&r" then
		return "\r"
	elseif capture == "&t" then
		return "\t"
	end
	return "&"
end

local denormalize = function(value)
	return value * (2 * math.pi) - math.pi
end

local function ResolvePath(root, pathString)
	local current = root

	for index in string.gmatch(pathString, "%d+") do
		index = tonumber(index)
		current = current:GetChildren()[index]

		if not current then
			return nil
		end
	end

	return current
end

local ReadPrimitive

ReadPrimitive = {
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
		local beforeDecimal, cursor = ReadPrimitive.SignedInt(str, cursor)
		local afterDecimal = StringConversion.StringToNumber(str, cursor, 2) / SHORT_BOUNDED_FLOAT_BOUND
		return afterDecimal + beforeDecimal, cursor + 2
	end,

	FloatRange = function(str, cursor)
		local rangeVec
		rangeVec, cursor = ReadPrimitive.Vector2(str, cursor)
		return NumberRange.new(rangeVec.X, rangeVec.Y), cursor
	end,

	FloatSequence = function(str, cursor)
		local numberSequenceKeypoints = {}
		local numberSequenceLength, time, number, envelope
		numberSequenceLength, cursor = ReadPrimitive.ShortInt(str, cursor)
		for i = 1, numberSequenceLength do
			time, cursor = ReadPrimitive.ShortBoundedFloat(str, cursor)
			number, cursor = ReadPrimitive.Float(str, cursor)
			envelope, cursor = ReadPrimitive.Float(str, cursor)
			numberSequenceKeypoints[i] = NumberSequenceKeypoint.new(time, number, envelope)
		end
		return NumberSequence.new(numberSequenceKeypoints), cursor
	end,

	Vector2 = function(str, cursor)
		local X, cursor = ReadPrimitive.Float(str, cursor)
		local Y, cursor = ReadPrimitive.Float(str, cursor)
		return Vector2.new(X, Y), cursor
	end,

	Vector3 = function(str, cursor) -- returns the value read as a Vector3. 24 symbols
		local X, cursor = ReadPrimitive.Float(str, cursor)
		local Y, cursor = ReadPrimitive.Float(str, cursor)
		local Z, cursor = ReadPrimitive.Float(str, cursor)
		return Vector3.new(X, Y, Z), cursor
	end,
	
	UDim = function(str, cursor)
		local udimVec
		udimVec, cursor = ReadPrimitive.Vector2(str, cursor)
		return UDim.new(udimVec.X, udimVec.Y), cursor
	end,

	UDim2 = function(str, cursor)
		local xUdim, yUdim
		xUdim, cursor = ReadPrimitive.UDim(str, cursor)
		yUdim, cursor = ReadPrimitive.UDim(str, cursor)
		return UDim2.new(xUdim, yUdim), cursor
	end,

	CFrame = function(str, cursor) -- returns the value read as a CFrame. 36 symbols
		local X, cursor = ReadPrimitive.Float(str, cursor)
		local Y, cursor = ReadPrimitive.Float(str, cursor)
		local Z, cursor = ReadPrimitive.Float(str, cursor)
		local rx, cursor = ReadPrimitive.BoundedFloat(str, cursor)
		rx = denormalize(rx)
		local ry, cursor = ReadPrimitive.BoundedFloat(str, cursor)
		ry = denormalize(ry)
		local rz, cursor = ReadPrimitive.BoundedFloat(str, cursor)
		rz = denormalize(rz)
		return CFrame.new(X, Y, Z) * CFrame.fromEulerAnglesXYZ(rx, ry, rz), cursor
	end,

	InstanceReference = function(str, cursor)
		local value, cursor = ReadPrimitive.String(str, cursor)

		return function()
			if ReadMissionRoot:IsSet() then
				ReadMissionRoot:WaitForFinalize()

				local object = ResolvePath(ReadMissionRoot:Get(), value)
				return object
			end
		end, cursor
	end,

	BoundedFloat = function(str, cursor) -- returns the value read as a bounded float between 0-1. 3 symbols.
		return StringConversion.StringToNumber(str, cursor, 3) / BOUNDED_FLOAT_BOUND, cursor + 3
	end,

	ShortBoundedFloat = function(str, cursor) -- returns the value read as a bounded float between 0-1. 4 symbols.
		return StringConversion.StringToNumber(str, cursor, 2) / SHORT_BOUNDED_FLOAT_BOUND, cursor + 2
	end,

	Color3 = function(str, cursor)
		local R, cursor = ReadPrimitive.ShortBoundedFloat(str, cursor)
		local G, cursor = ReadPrimitive.ShortBoundedFloat(str, cursor)
		local B, cursor = ReadPrimitive.ShortBoundedFloat(str, cursor)
		return Color3.new(R, G, B), cursor
	end,

	ColorSequence = function(str, cursor)
		local colorSequenceKeypoints = {}
		local colorSequenceLength, cursor = ReadPrimitive.ShortInt(str, cursor)
		-- The ColorSequence array constructor only accepts an array with 2+ indicies.
		if colorSequenceLength == 1 then
			local _, cursor = ReadPrimitive.ShortBoundedFloat(str, cursor)
			local color, cursor = ReadPrimitive.Color3(str, cursor)
			return ColorSequence.new(color), cursor
		end
		local time, color
		for i = 1, colorSequenceLength do
			time, cursor = ReadPrimitive.ShortBoundedFloat(str, cursor)
			color, cursor = ReadPrimitive.Color3(str, cursor)
			colorSequenceKeypoints[i] = ColorSequenceKeypoint.new(time, color)
		end
		return ColorSequence.new(colorSequenceKeypoints), cursor
	end,
	
	String = function(str, cursor)
		local length, cursor = ReadPrimitive.Int(str, cursor)
		local value = str:sub(cursor, cursor + length - 1)

		if VersionConfig.ReplaceNewlines then
			value = value:gsub("&.", NewlineGSub)
		end

		return value, cursor + length
	end,
}

local ReadEnum = require(script.Parent.ReadEnum)

for k, v in pairs(ReadEnum) do
	ReadPrimitive[k] = v
end

setmetatable(
	ReadPrimitive,
	{
		__index = function(self, k)
			error(`Serializer Dev Error: Attempt to index ReadPrimitive for unsupported primitive "{k}"`)
		end,
	}
)

return ReadPrimitive