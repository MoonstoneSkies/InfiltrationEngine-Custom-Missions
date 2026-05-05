local StringConversion = require(script.Parent.StringConversion)

local Bounds = {
	ShortestInt       = function(static) return StringConversion.GetMaxNumber(1, static) end,
	ShortInt          = function(static) return StringConversion.GetMaxNumber(2, static) end,
	Int               = function(static) return StringConversion.GetMaxNumber(4, static) end,
	LongInt           = function(static) return StringConversion.GetMaxNumber(6, static) end,
	SignedInt         = function(static) return math.floor(StringConversion.GetMaxNumber(3) * 0.5) end,
	BoundedFloat      = function(static) return StringConversion.GetMaxNumber(3, static) end,
	ShortBoundedFloat = function(static) return StringConversion.GetMaxNumber(2) end
}

return Bounds