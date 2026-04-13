--[[
	=== File Guide ===
		=== Purpose ===
		WritePrimitive is for any supported types that correspond to any "trivial" roblox engine datatype
		"Trivial" here refers to any non-instance datatype
		
		=== See Also ===
		Enums go into WriteEnum - for organizational purposes. They get automatically merged into the primitives table
		Complex datatypes go into Write
		Support specific to instances goes into WriteInstance
]]

local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local InstanceTypes = require(script.Parent.Parent.Types.InstanceTypes)
local VersionConfig = require(script.Parent.Parent.Util.VersionConfig)

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

local function GetIndex(object)
	local parent = object.Parent
	local children = parent:GetChildren()

	local index = 1
	for _, child in children do
		if child == object then
			return index
		elseif InstanceTypes[child.ClassName] ~= nil then -- Ignore unserialized instances
			index += 1
		end
	end

	return index
end

local WritePrimitive

WritePrimitive = {
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
		local beforeDecimalStr = WritePrimitive.SignedInt(math.floor(num))
		local afterDecimalStr = StringConversion.NumberToString(
			math.round(
				(num - math.floor(num)) * SHORT_INT_BOUND
			), 
			2
		)
		return beforeDecimalStr .. afterDecimalStr
	end,

	FloatRange = function(numberRange) -- Vector2 wrapper
		return WritePrimitive.Vector2(Vector2.new(numberRange.Min, numberRange.Max))
	end,

	FloatSequence = function (numberSequence) -- 2 + 7 * keypoints characters
		local keypoints = numberSequence.Keypoints
		local sequenceTbl = { WritePrimitive.ShortInt(#keypoints) }
		for i, v in pairs(keypoints) do
			sequenceTbl[#sequenceTbl + 1] = WritePrimitive.ShortBoundedFloat(v.Time)
			sequenceTbl[#sequenceTbl + 1] = WritePrimitive.Float(v.Value)
			sequenceTbl[#sequenceTbl + 1] = WritePrimitive.Float(v.Envelope)
		end
		return table.concat(sequenceTbl)
	end,

	Vector2 = function(vector) -- 10 characters, 5 per float XY
		return WritePrimitive.Float(vector.X) .. WritePrimitive.Float(vector.Y)
	end,

	Vector3 = function(vector) -- 15 characters, 5 per float XYZ
		return table.concat{
			WritePrimitive.Float(vector.X),
			WritePrimitive.Float(vector.Y),
			WritePrimitive.Float(vector.Z)
		}
	end,

	UDim = function(udim) -- Vector2 wrapper
		return WritePrimitive.Vector2(Vector2.new(udim.Scale, udim.Offset))
	end,

	UDim2 = function(udim2) -- 2x UDim == 2x Vector2 == 20 characters, 5 per float
		return WritePrimitive.UDim(udim2.X) .. WritePrimitive.UDim(udim2.Y)
	end,

	CFrame = function(frame) -- 24 characters, 15 for position, 9 for rotation
		-- This may seem like dead code given the new VectorMap handling - I certainly thought it was at first
		-- However, this needs to stay around for backwards compatibility, I've only just realised
		local rx, ry, rz = frame:ToEulerAnglesXYZ()
		return WritePrimitive.Float(frame.X)
			.. WritePrimitive.Float(frame.Y)
			.. WritePrimitive.Float(frame.Z)
			.. WritePrimitive.BoundedFloat(normalize(rx))
			.. WritePrimitive.BoundedFloat(normalize(ry))
			.. WritePrimitive.BoundedFloat(normalize(rz))
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
		return table.concat{
			WritePrimitive.ShortBoundedFloat(color.R),
			WritePrimitive.ShortBoundedFloat(color.G),
			WritePrimitive.ShortBoundedFloat(color.B)
		}
	end,

	ColorSequence = function(colorSequence) -- 2 + 8 * keypoints characters
		local keypoints = colorSequence.Keypoints
		local sequenceTbl = { WritePrimitive.ShortInt(#keypoints) }
		for i, v in ipairs(keypoints) do
			sequenceTbl[#sequenceTbl + 1] = WritePrimitive.ShortBoundedFloat(v.Time)
			sequenceTbl[#sequenceTbl + 1] = WritePrimitive.Color3(v.Value)
		end
		return table.concat(sequenceTbl)
	end,

	String = function(str) -- 4 + length characters
		if VersionConfig.ReplaceNewlines then
			str = str:gsub("&", "&&"):gsub("\n", "&n"):gsub("\r", "&r"):gsub("\t", "&t")
		end
		return WritePrimitive.Int(#str) .. str
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
		return WritePrimitive.String(path)
	end,
}

local WriteEnum = require(script.Parent.WriteEnum)

for k, v in pairs(WriteEnum) do
	WritePrimitive[k] = v
end

setmetatable(
	WritePrimitive,
	{
		__index = function(self, k)
			error(`Serializer Dev Error: Attempt to index WritePrimitive for unsupported primitive "{k}"`)
		end,
	}
)

return WritePrimitive